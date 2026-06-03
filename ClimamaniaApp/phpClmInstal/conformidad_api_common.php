<?php

require_once __DIR__ . "/presupuestos_api_common.php";

function conformidad_normalize_token(string $value): string
{
    $clean = trim(str_replace("\0", "", $value));
    $clean = preg_replace('/[^A-Za-z0-9_-]/', '', $clean);
    if (!is_string($clean)) {
        return "";
    }
    return mb_substr($clean, 0, 64, "UTF-8");
}

function conformidad_sanitize_plain_text(string $value): string
{
    $decoded = html_entity_decode($value, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $plain = strip_tags($decoded);
    $plain = preg_replace('/\s+/u', ' ', (string)$plain);
    return trim((string)$plain);
}

function conformidad_fetch_document_context(PDO $pdo, PDO $psPdo, string $psPrefix, string $referencia): array
{
    $ref = presup_normalize_text($referencia, 64);
    if ($ref === "") {
        throw new InvalidArgumentException("Referencia requerida");
    }

    $stmtPedido = $psPdo->prepare(
        "SELECT o.id_order
         FROM {$psPrefix}orders o
         WHERE o.reference = :ref
         LIMIT 1"
    );
    $stmtPedido->execute([":ref" => $ref]);
    $rowPedido = $stmtPedido->fetch(PDO::FETCH_ASSOC);
    $orderId = isset($rowPedido["id_order"]) ? (int)$rowPedido["id_order"] : 0;
    if ($orderId <= 0) {
        throw new RuntimeException("No se encontraron datos del cliente en Prestashop");
    }

    $stmtCliente = $psPdo->prepare(
        "SELECT
            c.firstname AS Nombre,
            c.lastname AS Apellidos,
            a.dni AS DNI,
            a.address1 AS Direccion,
            a.postcode AS CP,
            a.city AS Poblacion,
            s.name AS Provincia
         FROM {$psPrefix}orders o
         INNER JOIN {$psPrefix}customer c ON o.id_customer = c.id_customer
         INNER JOIN {$psPrefix}address a ON o.id_address_invoice = a.id_address
         LEFT JOIN {$psPrefix}state s ON a.id_state = s.id_state
         WHERE o.id_order = :order
         LIMIT 1"
    );
    $stmtCliente->execute([":order" => $orderId]);
    $cliente = $stmtCliente->fetch(PDO::FETCH_ASSOC);
    if (!is_array($cliente)) {
        throw new RuntimeException("No se pudieron resolver los datos del cliente");
    }

    $stmtInst = $pdo->prepare(
        "SELECT direccion
         FROM ClimaInstal_events
         WHERE referencia = :ref
         ORDER BY start ASC
         LIMIT 1"
    );
    $stmtInst->execute([":ref" => $ref]);
    $instalacion = $stmtInst->fetch(PDO::FETCH_ASSOC);
    $direccionInstalacion = conformidad_sanitize_plain_text((string)($instalacion["direccion"] ?? ""));
    if ($direccionInstalacion === "") {
        throw new RuntimeException("No se pudo resolver la dirección de instalación");
    }

    return [
        "referencia" => $ref,
        "cliente_nombre" => conformidad_sanitize_plain_text((string)($cliente["Nombre"] ?? "")),
        "cliente_apellidos" => conformidad_sanitize_plain_text((string)($cliente["Apellidos"] ?? "")),
        "cliente_dni" => conformidad_sanitize_plain_text((string)($cliente["DNI"] ?? "")),
        "cliente_direccion" => conformidad_sanitize_plain_text((string)($cliente["Direccion"] ?? "")),
        "cliente_cp" => conformidad_sanitize_plain_text((string)($cliente["CP"] ?? "")),
        "cliente_poblacion" => conformidad_sanitize_plain_text((string)($cliente["Poblacion"] ?? "")),
        "cliente_provincia" => conformidad_sanitize_plain_text((string)($cliente["Provincia"] ?? "")),
        "direccion_instalacion" => $direccionInstalacion
    ];
}

function conformidad_decode_signature_base64(string $firmaBase64): string
{
    $raw = trim($firmaBase64);
    if ($raw === "") {
        throw new InvalidArgumentException("La firma manuscrita es obligatoria");
    }
    if (preg_match('/^data:image\/[a-zA-Z0-9.+-]+;base64,(.+)$/', $raw, $m)) {
        $raw = $m[1];
    }
    $binary = base64_decode($raw, true);
    if (!is_string($binary) || $binary === "") {
        throw new InvalidArgumentException("La firma manuscrita no es válida");
    }
    return $binary;
}

function conformidad_find_document_by_token(PDO $pdo, string $submissionToken): ?array
{
    $token = conformidad_normalize_token($submissionToken);
    if ($token === "") {
        return null;
    }

    $stmt = $pdo->prepare(
        "SELECT Documento
         FROM ClimaInstal_Fotografias
         WHERE Clave = 'CONFCLI'
           AND TokenEvento = :token
         LIMIT 1"
    );
    try {
        $stmt->execute([":token" => $token]);
    } catch (PDOException $e) {
        if ($e->getCode() === "42S22") {
            throw new RuntimeException("Falta la columna TokenEvento en ClimaInstal_Fotografias. Ejecuta el SQL de la fase 10.");
        }
        throw $e;
    }
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($row) || empty($row["Documento"])) {
        return null;
    }

    $storedPath = trim((string)$row["Documento"]);
    return [
        "pdf" => presup_public_media_path($storedPath),
        "pdf_url" => presup_build_public_url($storedPath),
        "absolute_path" => presup_resolve_absolute_path($storedPath)
    ];
}

function conformidad_register_document(PDO $pdo, string $storedPath, string $submissionToken): bool
{
    $token = conformidad_normalize_token($submissionToken);
    if ($token === "") {
        throw new InvalidArgumentException("submission_token requerido");
    }

    $storedDoc = trim(str_replace("\\", "/", $storedPath));
    if ($storedDoc === "") {
        throw new InvalidArgumentException("Ruta del documento requerida");
    }

    $stmt = $pdo->prepare(
        "INSERT INTO ClimaInstal_Fotografias (Documento, Clave, TokenEvento, Fecha)
         VALUES (:doc, 'CONFCLI', :token, NOW())"
    );

    try {
        $stmt->execute([
            ":doc" => $storedDoc,
            ":token" => $token
        ]);
    } catch (PDOException $e) {
        if ($e->getCode() === "42S22") {
            throw new RuntimeException("Falta la columna TokenEvento en ClimaInstal_Fotografias. Ejecuta el SQL de la fase 10.");
        }
        if ($e->getCode() === "23000") {
            return false;
        }
        throw $e;
    }
    return true;
}

function conformidad_store_pdf(string $referencia, string $submissionToken, string $pdfBinary): array
{
    $ref = presup_normalize_text($referencia, 64);
    if ($ref === "") {
        throw new InvalidArgumentException("Referencia requerida");
    }
    $token = conformidad_normalize_token($submissionToken);
    if ($token === "") {
        throw new InvalidArgumentException("submission_token requerido");
    }

    $imagesRoot = presup_resolve_images_root();
    $targetDir = rtrim($imagesRoot, "/") . "/DocConformeCliente";
    presup_ensure_dir($targetDir);

    $tokenShort = substr($token, 0, 12);
    if ($tokenShort === "") {
        $tokenShort = "TOKEN";
    }
    $fileName = $ref . "-DOCCLI-" . date("YmdHis") . "-" . $tokenShort . ".pdf";
    $absolutePath = $targetDir . "/" . $fileName;
    if (file_put_contents($absolutePath, $pdfBinary) === false) {
        throw new RuntimeException("No se pudo guardar el PDF del conforme");
    }

    $relativePath = "imagenes/DocConformeCliente/" . $fileName;
    return [
        "absolute_path" => $absolutePath,
        "relative_path" => $relativePath,
        "pdf_url" => presup_build_public_url($relativePath)
    ];
}

function conformidad_build_pdf(
    array $contexto,
    string $observaciones,
    array $firmante,
    string $signatureBinary,
    array $locationEvent
): string {
    $signatureImage = presup_build_pdf_image_from_binary($signatureBinary, "IMCONF");
    if ($signatureImage === null) {
        throw new RuntimeException("No se pudo procesar la firma manuscrita");
    }

    $companyStampImage = conformidad_load_company_stamp_image();
    $images = [$signatureImage, $companyStampImage];
    $pages = [];
    $currentPage = "";
    $pageNo = 1;
    conformidad_pdf_start_page($currentPage, $pageNo, null, false);

    $marginLeft = 77.0;
    $contentWidth = 435.0;
    $fullName = trim($contexto["cliente_nombre"] . " " . $contexto["cliente_apellidos"]);
    $cpPoblacion = trim($contexto["cliente_cp"] . " - " . $contexto["cliente_poblacion"], " -");
    $currentPage .= presup_pdf_text_cmd(143.0, 756.0, "CONFORME DE FINALIZACIÓN DE INSTALACIÓN", 14.8, true);

    $boxTop = 712.0;
    $boxHeight = 106.0;
    $boxX = $marginLeft;
    $boxWidth = $contentWidth;
    $dividerX = 327.0;
    $currentPage .= presup_pdf_rect_stroke_cmd($boxX, $boxTop, $boxWidth, $boxHeight);
    $currentPage .= presup_pdf_line_cmd($dividerX, $boxTop, $dividerX, $boxTop - $boxHeight);

    $leftY = $boxTop - 13.0;
    $currentPage .= presup_pdf_text_cmd($boxX + 7.0, $leftY, "Datos del cliente", 9.2, true);
    $leftY -= 13.0;

    $lineRight = $dividerX - 12.0;
    $lineItems = [
        ["Nombre del cliente:", $fullName, 182.0],
        ["DNI/NIF:", (string)$contexto["cliente_dni"], 131.0],
        ["Dirección:", (string)$contexto["cliente_direccion"], 138.0],
        ["CP - Población:", $cpPoblacion, 171.0],
        ["Provincia:", (string)$contexto["cliente_provincia"], 132.0],
        ["Referencia del pedido:", (string)$contexto["referencia"], 188.0]
    ];
    foreach ($lineItems as [$label, $value, $valueX]) {
        $currentPage .= presup_pdf_text_cmd($boxX + 7.0, $leftY, $label, 8.2, true);
        $currentPage .= presup_pdf_line_cmd($valueX, $leftY - 2.0, $lineRight, $leftY - 2.0);
        $wrapped = presup_pdf_wrap_for_width(conformidad_sanitize_plain_text((string)$value), $lineRight - $valueX - 2.0, 8.4);
        if (!empty($wrapped)) {
            $currentPage .= presup_pdf_text_cmd($valueX + 1.0, $leftY, $wrapped[0], 7.9);
        }
        $leftY -= 12.0;
    }

    $rightX = $dividerX + 8.0;
    $rightY = $boxTop - 15.0;
    foreach ([
        "CLIMAMANIA SALES SPAIN S.L.",
        "CIF: B66040577",
        "C/ Electrónica 14",
        "08110 Montcada i Reixac (Barcelona)",
        "Tel.: 933 282 421"
    ] as $idx => $line) {
        $currentPage .= presup_pdf_text_cmd($rightX, $rightY, $line, 8.8, $idx === 0);
        $rightY -= 13.0;
    }

    $y = 578.0;
    $intro = "Manifiesta mediante la firma del presente documento que CLIMAMANIA SALES SPAIN S.L. ha realizado la instalación en el";
    $introLines = presup_pdf_wrap_for_width($intro, $contentWidth, 10.0);
    foreach ($introLines as $line) {
        $currentPage .= conformidad_pdf_black_text_cmd(
            presup_pdf_text_cmd($marginLeft, $y, $line, 9.2, true)
        );
        $y -= 11.0;
    }

    $instalacionPrefix = "domicilio situado en:";
    $currentPage .= conformidad_pdf_black_text_cmd(
        presup_pdf_text_cmd($marginLeft, $y, $instalacionPrefix, 9.2, true)
    );
    $installX = 201.0;
    $currentPage .= presup_pdf_line_cmd($installX, $y - 2.0, $marginLeft + $contentWidth - 2.0, $y - 2.0);
    $direccionLines = presup_pdf_wrap_for_width(
        conformidad_sanitize_plain_text((string)$contexto["direccion_instalacion"]),
        ($marginLeft + $contentWidth - 6.0) - $installX,
        8.0
    );
    if (!empty($direccionLines)) {
        $currentPage .= conformidad_pdf_black_text_cmd(
            presup_pdf_text_cmd($installX + 2.0, $y, $direccionLines[0], 8.0, true)
        );
    }
    $y -= 18.0;

    $currentPage .= conformidad_pdf_black_text_cmd(
        presup_pdf_text_cmd($marginLeft, $y, "La persona firmante declara que:", 9.0, false)
    );
    $y -= 12.0;

    $bulletLines = [
        "La instalación ha sido finalizada conforme al presupuesto o encargo previamente aceptado.",
        "Ha podido revisar la instalación en presencia del personal instalador, comprobando el estado de los equipos y materiales suministrados.",
        "La instalación se encuentra terminada y correctamente ejecutada, no quedando trabajos pendientes por parte de CLIMAMANIA SALES SPAIN S.L., salvo aquellos que, en su caso, queden reflejados expresamente en el apartado de observaciones.",
        "Se encuentra conforme con la ubicación de los equipos instalados, el trazado de las canalizaciones, perforaciones, soportes, canaletas y demás elementos necesarios para la instalación.",
        "Los equipos instalados se encuentran en correcto estado y funcionamiento, o preparados para su puesta en marcha según corresponda al tipo de instalación realizada."
    ];
    foreach ($bulletLines as $bulletLine) {
        $y = conformidad_pdf_draw_bullet_paragraph_black($currentPage, $y, $bulletLine, $marginLeft + 34.0, $contentWidth - 36.0, 8.2, 9.9);
    }
    $y -= 8.0;

    $paragraphs = [
        "La persona firmante declara que ha revisado la instalación en presencia del instalador, no apreciando defectos visibles en el momento de la firma y prestando su conformidad con los trabajos realizados y el resultado final de la instalación.",
        "La firma del presente documento implica la aceptación de la instalación realizada y el reconocimiento de su correcta ejecución, por lo que cualquier reclamación posterior deberá referirse exclusivamente a defectos ocultos o incidencias no apreciables en el momento de la revisión y firma, salvo las que se hagan constar expresamente en el apartado de observaciones. Asimismo, el cliente reconoce que, en caso de existir cantidades pendientes derivadas del presupuesto o pedido asociado, se compromete a su pago en los plazos acordados.",
        "Asimismo, el cliente queda informado de que determinados equipos pueden requerir puesta en marcha, sellado de garantía o intervención del servicio técnico oficial del fabricante."
    ];
    foreach ($paragraphs as $paragraph) {
        $y = conformidad_pdf_draw_paragraph_black($currentPage, $y, $paragraph, $marginLeft, $contentWidth, 8.1, 9.8, true);
        $y -= 6.0;
    }

    $obsLabelY = $y - 2.0;
    $currentPage .= presup_pdf_text_cmd($marginLeft, $obsLabelY, "Observaciones", 10.0, true);
    $obsTop = $obsLabelY - 12.0;
    $obsHeight = 50.0;
    $currentPage .= presup_pdf_rect_stroke_cmd($marginLeft, $obsTop, $contentWidth, $obsHeight);
    $obsValue = conformidad_sanitize_plain_text($observaciones);
    if ($obsValue !== "") {
        $obsLines = presup_pdf_wrap_for_width($obsValue, $contentWidth - 12.0, 8.2);
        foreach (array_slice($obsLines, 0, 3) as $idx => $line) {
            $currentPage .= presup_pdf_text_cmd($marginLeft + 6.0, $obsTop - 13.0 - ($idx * 11.0), $line, 8.0);
        }
    }

    $y = ($obsTop - $obsHeight) - 18.0;
    $signParagraph1 = "Y para que así conste, y en prueba de conformidad, se firma el presente documento mediante firma manuscrita electrónica en";
    $currentPage .= presup_pdf_text_cmd($marginLeft, $y, $signParagraph1, 8.6);
    $y -= 11.0;
    $currentPage .= presup_pdf_text_cmd($marginLeft, $y, "dispositivo digital, quedando registrada la fecha y hora de la firma.", 8.6);
    $y -= 14.0;

    $latitudFirma = conformidad_format_coordinate($locationEvent["latitud"] ?? "");
    $longitudFirma = conformidad_format_coordinate($locationEvent["longitud"] ?? "");
    $localidadFirma = conformidad_sanitize_plain_text((string)($contexto["cliente_poblacion"] ?? ""));
    $lugarFirma = "lat:" . $latitudFirma . ", long:" . $longitudFirma;
    if ($localidadFirma !== "") {
        $lugarFirma .= " (" . $localidadFirma . ")";
    }
    $currentPage .= presup_pdf_text_cmd($marginLeft, $y, "Lugar:", 9.0, true);
    $currentPage .= presup_pdf_line_cmd($marginLeft + 34.0, $y - 2.0, 365.0, $y - 2.0);
    $currentPage .= presup_pdf_text_cmd($marginLeft + 38.0, $y, $lugarFirma, 7.1);
    $y -= 12.0;
    $currentPage .= presup_pdf_text_cmd($marginLeft, $y, "Fecha:", 9.0, true);
    $fechaFirma = conformidad_format_pdf_datetime((string)($locationEvent["fecha_hora"] ?? ""));
    $currentPage .= presup_pdf_line_cmd($marginLeft + 34.0, $y - 2.0, 188.0, $y - 2.0);
    $currentPage .= presup_pdf_text_cmd($marginLeft + 38.0, $y, $fechaFirma, 7.9);

    $panelTop = 160.0;
    $panelHeight = 110.0;
    $panelX = $marginLeft;
    $panelWidth = $contentWidth;
    $panelDivider = 235.0;
    $currentPage .= presup_pdf_rect_stroke_cmd($panelX, $panelTop, $panelWidth, $panelHeight);
    $currentPage .= presup_pdf_line_cmd($panelDivider, $panelTop, $panelDivider, $panelTop - $panelHeight);
    $currentPage .= presup_pdf_text_cmd($panelX + 7.0, $panelTop - 14.0, "POR", 9.8, true);
    $currentPage .= presup_pdf_text_cmd($panelX + 7.0, $panelTop - 30.0, "CLIMAMANIA SALES SPAIN S.L.", 9.2);
    $currentPage .= presup_pdf_image_cmd((string)$companyStampImage["name"], $panelX + 18.0, $panelTop - 50.0, 132.0, 56.0);

    $rightPanelX = $panelDivider + 7.0;
    $currentPage .= presup_pdf_text_cmd($rightPanelX, $panelTop - 14.0, "Firma de conformidad", 9.8, true);
    $currentPage .= presup_pdf_text_cmd($rightPanelX, $panelTop - 30.0, "Firma manuscrita electrónica:", 9.2, true);

    $sigBoxX = $rightPanelX + 2.0;
    $sigBoxTop = $panelTop - 41.0;
    $sigBoxW = 200.0;
    $sigBoxH = 32.0;
    $signatureAspect = max(0.1, ((float)$signatureImage["width"]) / max(1.0, (float)$signatureImage["height"]));
    $signatureDrawH = $sigBoxH + 4.0;
    $signatureDrawW = min($sigBoxW - 54.0, $signatureDrawH * $signatureAspect);
    $currentPage .= presup_pdf_image_cmd(
        (string)$signatureImage["name"],
        $sigBoxX + 120.0,
        $sigBoxTop + 4.0,
        $signatureDrawW,
        $signatureDrawH
    );

    $signerY = $panelTop - 66.0;
    $firmanteTipo = (string)($firmante["tipo"] ?? "");
    $showClienteTitular = $firmanteTipo !== "representante_autorizado";
    $showRepresentante = $firmanteTipo === "representante_autorizado";
    $currentPage .= presup_pdf_text_cmd($rightPanelX, $signerY, "D./Dña.: " . conformidad_pdf_display_line((string)$firmante["nombre_completo"]), 8.2);
    $currentPage .= presup_pdf_text_cmd($rightPanelX, $signerY - 10.0, "DNI/NIF: " . conformidad_pdf_display_line((string)$firmante["dni"]), 8.2);

    $firmanteLabelY = $signerY - 20.0;
    $firmanteLabel = $showRepresentante
        ? "Representante autorizado del cliente"
        : "Cliente / titular del pedido";
    $currentPage .= presup_pdf_text_cmd($rightPanelX, $firmanteLabelY, $firmanteLabel, 8.2);

    if ($showRepresentante) {
        $footerY = 26.0;
        $currentPage .= presup_pdf_text_cmd($marginLeft, $footerY + 16.0, "En caso de firmar en representación del cliente:", 8.5, true);
        $currentPage .= presup_pdf_text_cmd($marginLeft, $footerY + 4.0, "La persona firmante declara que actúa en nombre o con la autorización del cliente indicado en el presente documento, y que", 8.1);
        $currentPage .= presup_pdf_text_cmd($marginLeft, $footerY - 8.0, "firma tras haber revisado la instalación y prestar su conformidad con los trabajos realizados.", 8.1);
    }

    $pages[] = $currentPage;
    return presup_build_pdf_document($pages, $images);
}

function conformidad_pdf_draw_identity_block(
    array &$pages,
    string &$currentPage,
    int &$pageNo,
    float $y,
    array $contexto,
    string $fullName,
    string $cpPoblacion,
    ?array $logoImage
): float {
    $leftLines = [
        "D./Dña.: " . conformidad_pdf_display_line($fullName),
        "DNI/NIF: " . conformidad_pdf_display_line((string)$contexto["cliente_dni"]),
        "Dirección: " . conformidad_pdf_display_line((string)$contexto["cliente_direccion"]),
        "CP - Población: " . conformidad_pdf_display_line($cpPoblacion),
        "Provincia: " . conformidad_pdf_display_line((string)$contexto["cliente_provincia"]),
        "Referencia del pedido: " . conformidad_pdf_display_line((string)$contexto["referencia"])
    ];
    $rightLines = [
        "CLIMAMANIA SALES SPAIN S.L.",
        "CIF: B66040577",
        "C/ Electrónica 14",
        "08110 Montcada i Reixac (Barcelona)",
        "Tel.: 933 282 421"
    ];

    $y = conformidad_pdf_ensure_space($pages, $currentPage, $pageNo, $y, 92.0, $logoImage);
    $boxTop = $y;
    $boxHeight = 84.0;
    $currentPage .= presup_pdf_rect_stroke_cmd(50.0, $boxTop, 495.0, $boxHeight);
    $currentPage .= presup_pdf_line_cmd(300.0, $boxTop, 300.0, $boxTop - $boxHeight);
    $currentPage .= presup_pdf_text_cmd(58.0, $boxTop - 10.0, "Datos del cliente", 9.0, true);
    $currentPage .= presup_pdf_text_cmd(308.0, $boxTop - 10.0, "Datos empresa instaladora", 9.0, true);

    $leftY = $boxTop - 22.0;
    foreach ($leftLines as $line) {
        $currentPage .= presup_pdf_text_cmd(58.0, $leftY, $line, 8.6);
        $leftY -= 10.2;
    }

    $rightY = $boxTop - 22.0;
    foreach ($rightLines as $line) {
        $currentPage .= presup_pdf_text_cmd(308.0, $rightY, $line, 8.6, $line === "CLIMAMANIA SALES SPAIN S.L.");
        $rightY -= 10.2;
    }

    return $boxTop - $boxHeight - 8.0;
}

function conformidad_pdf_start_page(string &$pageContent, int $pageNo, ?array $logoImage, bool $continuacion): float
{
    $pageContent .= presup_pdf_line_cmd(0.0, 841.0, 595.0, 841.0);
    if ($continuacion) {
        $pageContent .= presup_pdf_text_cmd(455.0, 820.0, "(continuación)", 9.0, false, "R", 95.0);
    }
    return 790.0;
}

function conformidad_pdf_draw_paragraph(
    array &$pages,
    string &$currentPage,
    int &$pageNo,
    float $y,
    string $text,
    float $x,
    float $width,
    float $fontSize,
    float $lineHeight,
    ?array $logoImage,
    bool $bold = false
): float {
    $lines = presup_pdf_wrap_for_width($text, $width, $fontSize);
    if (empty($lines)) {
        return $y;
    }
    foreach ($lines as $line) {
        if ($y < 70.0) {
            $pages[] = $currentPage;
            $currentPage = "";
            $pageNo++;
            $y = conformidad_pdf_start_page($currentPage, $pageNo, $logoImage, true);
        }
        $currentPage .= presup_pdf_text_cmd($x, $y, $line, $fontSize, $bold);
        $y -= $lineHeight;
    }
    return $y - 3.0;
}

function conformidad_pdf_draw_bullet_paragraph(
    array &$pages,
    string &$currentPage,
    int &$pageNo,
    float $y,
    string $text,
    float $x,
    float $width,
    float $fontSize,
    float $lineHeight,
    ?array $logoImage
): float {
    $lines = presup_pdf_wrap_for_width($text, $width, $fontSize);
    if (empty($lines)) {
        return $y;
    }
    foreach ($lines as $idx => $line) {
        if ($y < 70.0) {
            $pages[] = $currentPage;
            $currentPage = "";
            $pageNo++;
            $y = conformidad_pdf_start_page($currentPage, $pageNo, $logoImage, true);
        }
        if ($idx === 0) {
            $currentPage .= presup_pdf_text_cmd($x - 8.0, $y, "-", $fontSize, true);
        }
        $currentPage .= presup_pdf_text_cmd($x, $y, $line, $fontSize);
        $y -= $lineHeight;
    }
    return $y - 1.5;
}

function conformidad_pdf_draw_paragraph_blue(
    string &$currentPage,
    float $y,
    string $text,
    float $x,
    float $width,
    float $fontSize,
    float $lineHeight,
    array $rgb,
    bool $bold = false
): float {
    $lines = presup_pdf_wrap_for_width($text, $width, $fontSize);
    foreach ($lines as $line) {
        $currentPage .= conformidad_pdf_colored_text_cmd($x, $y, $line, $fontSize, $bold, $rgb);
        $y -= $lineHeight;
    }
    return $y;
}

function conformidad_pdf_draw_paragraph_black(
    string &$currentPage,
    float $y,
    string $text,
    float $x,
    float $width,
    float $fontSize,
    float $lineHeight,
    bool $bold = false
): float {
    $lines = presup_pdf_wrap_for_width($text, $width, $fontSize);
    foreach ($lines as $line) {
        $currentPage .= conformidad_pdf_black_text_cmd(
            presup_pdf_text_cmd($x, $y, $line, $fontSize, $bold)
        );
        $y -= $lineHeight;
    }
    return $y;
}

function conformidad_pdf_draw_bullet_paragraph_blue(
    string &$currentPage,
    float $y,
    string $text,
    float $x,
    float $width,
    float $fontSize,
    float $lineHeight,
    array $rgb
): float {
    $lines = presup_pdf_wrap_for_width($text, $width, $fontSize);
    foreach ($lines as $idx => $line) {
        if ($idx === 0) {
            $currentPage .= conformidad_pdf_colored_text_cmd($x - 18.0, $y, "•", $fontSize + 2.0, true, $rgb);
        }
        $currentPage .= conformidad_pdf_colored_text_cmd($x, $y, $line, $fontSize, true, $rgb);
        $y -= $lineHeight;
    }
    return $y;
}

function conformidad_pdf_draw_bullet_paragraph_black(
    string &$currentPage,
    float $y,
    string $text,
    float $x,
    float $width,
    float $fontSize,
    float $lineHeight
): float {
    $lines = presup_pdf_wrap_for_width($text, $width, $fontSize);
    foreach ($lines as $idx => $line) {
        if ($idx === 0) {
            $currentPage .= conformidad_pdf_black_text_cmd(
                presup_pdf_text_cmd($x - 18.0, $y, "•", $fontSize + 2.0, true)
            );
        }
        $currentPage .= conformidad_pdf_black_text_cmd(
            presup_pdf_text_cmd($x, $y, $line, $fontSize, true)
        );
        $y -= $lineHeight;
    }
    return $y;
}

function conformidad_pdf_black_text_cmd(string $textCmd): string
{
    return "0 g\n" . $textCmd;
}

function conformidad_pdf_colored_text_cmd(
    float $x,
    float $y,
    string $text,
    float $size,
    bool $bold,
    array $rgb
): string {
    $cmd = presup_pdf_text_cmd($x, $y, $text, $size, $bold);
    return presup_pdf_num((float)$rgb[0]) . " " . presup_pdf_num((float)$rgb[1]) . " " . presup_pdf_num((float)$rgb[2]) . " rg\n"
        . $cmd
        . "0 g\n";
}

function conformidad_pdf_blue_graphics_cmd(string $cmd): string
{
    return "0.20 0.33 0.78 RG\n0.20 0.33 0.78 rg\n"
        . $cmd
        . "0 G\n0 g\n";
}

function conformidad_pdf_draw_company_stamp(
    string &$currentPage,
    float $x,
    float $topY,
    float $width,
    float $height
): void {
    $currentPage .= conformidad_pdf_blue_graphics_cmd(
        presup_pdf_rect_stroke_cmd($x, $topY, $width, $height)
    );

    $centerX = $x + ($width / 2.0);
    $currentPage .= conformidad_pdf_colored_text_cmd($centerX - 52.0, $topY - 14.0, "CLIMAMANIA", 10.0, true, [0.20, 0.33, 0.78]);
    $currentPage .= conformidad_pdf_colored_text_cmd($centerX - 46.0, $topY - 27.0, "SALES SPAIN S.L.", 8.8, true, [0.20, 0.33, 0.78]);
    $currentPage .= conformidad_pdf_colored_text_cmd($centerX - 23.0, $topY - 40.0, "B-66040577", 8.0, true, [0.20, 0.33, 0.78]);

    $signatureLines = [
        [$x + 16.0, $topY - 12.0, $x + 94.0, $topY - 30.0],
        [$x + 52.0, $topY - 8.0, $x + 64.0, $topY - 40.0],
        [$x + 38.0, $topY - 18.0, $x + 110.0, $topY - 14.0],
    ];
    foreach ($signatureLines as [$x1, $y1, $x2, $y2]) {
        $currentPage .= conformidad_pdf_blue_graphics_cmd(
            presup_pdf_line_cmd($x1, $y1, $x2, $y2)
        );
    }
}

function conformidad_pdf_ensure_space(
    array &$pages,
    string &$currentPage,
    int &$pageNo,
    float $y,
    float $requiredHeight,
    ?array $logoImage
): float {
    if ($y - $requiredHeight >= 38.0) {
        return $y;
    }
    $pages[] = $currentPage;
    $currentPage = "";
    $pageNo++;
    return conformidad_pdf_start_page($currentPage, $pageNo, $logoImage, true);
}

function conformidad_pdf_display_line(string $value): string
{
    $clean = conformidad_sanitize_plain_text($value);
    return $clean !== "" ? $clean : "__________________________________";
}

function conformidad_load_company_stamp_image(): array
{
    $path = __DIR__ . "/assets/conforme_template/company_stamp.png";
    $binary = @file_get_contents($path);
    if (!is_string($binary) || $binary === "") {
        throw new RuntimeException("No se pudo cargar el sello de empresa del conforme");
    }
    $image = presup_build_pdf_image_from_binary($binary, "IMCONFSTAMP");
    if ($image === null) {
        throw new RuntimeException("No se pudo procesar el sello de empresa del conforme");
    }
    return $image;
}

function conformidad_format_coordinate($value): string
{
    $number = (float)$value;
    return number_format($number, 7, ".", "");
}

function conformidad_format_footer_datetime(string $value): string
{
    $ts = strtotime($value);
    if ($ts === false) {
        return $value;
    }
    return date("d-m-Y H:i:s", $ts);
}

function conformidad_format_pdf_datetime(string $value): string
{
    $ts = strtotime($value);
    if ($ts === false) {
        return $value;
    }
    return date("d/m/Y H:i:s", $ts);
}
