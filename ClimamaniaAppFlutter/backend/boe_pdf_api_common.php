<?php

require_once __DIR__ . "/conformidad_api_common.php";

function boe_find_document_by_token(PDO $pdo, string $submissionToken): ?array
{
    $token = conformidad_normalize_token($submissionToken);
    if ($token === "") {
        return null;
    }

    $stmt = $pdo->prepare(
        "SELECT Documento
         FROM ClimaInstal_Fotografias
         WHERE Clave = 'DOCUBOE'
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

function boe_register_document(PDO $pdo, string $storedPath, string $submissionToken): bool
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
         VALUES (:doc, 'DOCUBOE', :token, NOW())"
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

function boe_store_pdf(string $referencia, string $submissionToken, string $pdfBinary): array
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
    $targetDir = rtrim($imagesRoot, "/") . "/BoesClientes";
    presup_ensure_dir($targetDir);

    $tokenShort = substr($token, 0, 12);
    if ($tokenShort === "") {
        $tokenShort = "TOKEN";
    }
    $fileName = $ref . "-DOCUBOE-" . date("YmdHis") . "-" . $tokenShort . ".pdf";
    $absolutePath = $targetDir . "/" . $fileName;
    if (file_put_contents($absolutePath, $pdfBinary) === false) {
        throw new RuntimeException("No se pudo guardar el PDF del BOE");
    }

    $relativePath = "imagenes/BoesClientes/" . $fileName;
    return [
        "absolute_path" => $absolutePath,
        "relative_path" => $relativePath,
        "pdf_url" => presup_build_public_url($relativePath)
    ];
}

function boe_fetch_revision_rows(PDO $pdo, PDO $psPdo, string $psPrefix, string $referencia): array
{
    $ref = presup_normalize_text($referencia, 64);
    if ($ref === "") {
        throw new InvalidArgumentException("Referencia requerida");
    }

    $stmt = $pdo->prepare(
        "SELECT id_linea, orden_linea, codigo, num_serie
         FROM ClimaInstal_BoeEquiposRevision
         WHERE referencia = :referencia
         ORDER BY orden_linea ASC, id_linea ASC"
    );
    $stmt->execute([":referencia" => $ref]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    if (empty($rows)) {
        throw new RuntimeException("No existe una revisión BOE guardada para esta referencia");
    }

    $stmtMarca = $psPdo->prepare(
        "SELECT p.reference, m.name AS fabricante
         FROM {$psPrefix}product p
         LEFT JOIN {$psPrefix}manufacturer m ON p.id_manufacturer = m.id_manufacturer
         WHERE p.reference = :referencia
         LIMIT 1"
    );

    $equipos = [];
    foreach ($rows as $row) {
        $codigo = conformidad_sanitize_plain_text((string)($row["codigo"] ?? ""));
        if ($codigo === "") {
            continue;
        }
        $stmtMarca->execute([":referencia" => $codigo]);
        $rowMarca = $stmtMarca->fetch(PDO::FETCH_ASSOC);
        $fabricante = conformidad_sanitize_plain_text((string)($rowMarca["fabricante"] ?? ""));

        $equipos[] = [
            "id_linea" => (int)($row["id_linea"] ?? 0),
            "orden_linea" => (int)($row["orden_linea"] ?? 0),
            "codigo" => $codigo,
            "num_serie" => conformidad_sanitize_plain_text((string)($row["num_serie"] ?? "")),
            "fabricante" => $fabricante
        ];
    }

    if (empty($equipos)) {
        throw new RuntimeException("La revisión BOE no contiene equipos válidos");
    }

    return $equipos;
}

function boe_fetch_user_template_sources(PDO $pdo, string $usuario): array
{
    $user = presup_normalize_text($usuario, 100);
    if ($user === "") {
        return [];
    }

    $columns = ["usuario", "EquipoInstaladores", "iniciales", "email", "Nombre"];
    foreach ($columns as $column) {
        $stmt = $pdo->prepare(
            "SELECT usuario, FicheroBOEA, FicheroBOEB
             FROM ClimaInstal_Usuarios
             WHERE LOWER($column) = LOWER(:usuario)
             LIMIT 1"
        );
        try {
            $stmt->execute([":usuario" => $user]);
        } catch (Throwable $e) {
            return [];
        }

        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!is_array($row)) {
            continue;
        }

        return [
            "A" => trim((string)($row["FicheroBOEA"] ?? "")),
            "B" => trim((string)($row["FicheroBOEB"] ?? "")),
            "_matched_usuario" => trim((string)($row["usuario"] ?? "")),
            "_matched_column" => $column
        ];
    }

    return [];
}

function boe_build_pdf(
    array $contexto,
    array $equipos,
    array $firmante,
    string $signatureBinary,
    array $firmaMeta,
    array $templateSources = []
): string {
    $templateA = boe_load_template_image("A", $templateSources);
    $templateB = boe_load_template_image("B", $templateSources);
    $signatureImage = presup_build_pdf_image_from_binary($signatureBinary, "IMBOEFIRMA");
    if ($signatureImage === null) {
        throw new RuntimeException("No se pudo procesar la firma manuscrita del BOE");
    }

    $images = [$templateA, $templateB, $signatureImage];

    $pages = [];
    foreach ($equipos as $equipo) {
        $pages[] = boe_build_equipo_page($templateA, $contexto, $equipo, $firmante, $signatureImage, $firmaMeta, false);
        $pages[] = boe_build_equipo_page($templateB, $contexto, $equipo, $firmante, $signatureImage, $firmaMeta, true);
    }

    return presup_build_pdf_document($pages, $images);
}

function boe_build_equipo_page(
    array $backgroundImage,
    array $contexto,
    array $equipo,
    array $firmante,
    array $signatureImage,
    array $firmaMeta,
    bool $parteB
): string {
    $content = "";
    $content .= presup_pdf_image_cmd((string)$backgroundImage["name"], 0.0, 841.92, 595.32, 841.92);

    if ($parteB) {
        boe_overlay_page_b($content, $contexto, $equipo, $firmante, $signatureImage, $firmaMeta);
    } else {
        boe_overlay_page_a($content, $contexto, $equipo, $firmante, $signatureImage, $firmaMeta);
    }
    return $content;
}

function boe_load_template_image(string $part, array $templateSources = []): array
{
    $normalized = strtoupper(trim($part));
    if ($normalized !== "A" && $normalized !== "B") {
        throw new InvalidArgumentException("Parte BOE inválida");
    }

    $configuredSource = trim((string)($templateSources[$normalized] ?? ""));
    try {
        $binary = boe_load_template_binary_from_source($configuredSource);
    } catch (Throwable $e) {
        $debug = boe_describe_template_source_resolution($configuredSource);
        throw new RuntimeException(
            "No se pudo cargar la plantilla BOE " . $normalized
            . " desde la ruta configurada en ClimaInstal_Usuarios: " . $configuredSource
            . " | " . $debug
            . " | detalle=" . $e->getMessage()
        );
    }
    if ($configuredSource !== "" && (!is_string($binary) || $binary === "")) {
        $debug = boe_describe_template_source_resolution($configuredSource);
        throw new RuntimeException(
            "No se pudo cargar la plantilla BOE " . $normalized
            . " desde la ruta configurada en ClimaInstal_Usuarios: " . $configuredSource
            . " | " . $debug
        );
    }
    if (!is_string($binary) || $binary === "") {
        $path = __DIR__ . "/assets/boe_template/boe_parte_" . strtolower($normalized) . ".png";
        $binary = @file_get_contents($path);
    }
    if (!is_string($binary) || $binary === "") {
        throw new RuntimeException("No se pudo cargar la plantilla del BOE (" . $normalized . ")");
    }

    $image = presup_build_pdf_image_from_binary($binary, "IMBOETPL" . $normalized);
    if ($image === null) {
        throw new RuntimeException("No se pudo procesar la plantilla del BOE (" . $normalized . ")");
    }
    return $image;
}

function boe_load_template_binary_from_source(string $source): string
{
    static $cache = [];

    $normalizedSource = trim($source);
    if ($normalizedSource === "") {
        return "";
    }
    if (isset($cache[$normalizedSource])) {
        return $cache[$normalizedSource];
    }

    $binary = boe_fetch_template_source_binary($normalizedSource);
    if ($binary === "") {
        $cache[$normalizedSource] = "";
        return "";
    }

    $resolvedUrl = boe_normalize_template_source_url($normalizedSource);
    $pathInfo = $resolvedUrl !== "" ? parse_url($resolvedUrl, PHP_URL_PATH) : null;
    $extension = is_string($pathInfo) ? strtolower((string)pathinfo($pathInfo, PATHINFO_EXTENSION)) : "";

    if ($extension === "pdf" || boe_pdf_signature_matches($binary)) {
        $binary = boe_render_first_page_pdf_to_png($binary);
    }

    $cache[$normalizedSource] = $binary;
    return $binary;
}

function boe_fetch_template_source_binary(string $source): string
{
    $value = trim(str_replace("\\", "/", $source));
    if ($value === "") {
        return "";
    }

    // Si BD trae una ruta absoluta local, usarla exactamente tal cual.
    if ($value[0] === '/') {
        if (!is_file($value) || !is_readable($value)) {
            return "";
        }
        $binary = @file_get_contents($value);
        return is_string($binary) ? $binary : "";
    }

    // En cualquier otro caso, la ruta de BD es el origen canónico.
    // Puede venir como dominio sin esquema, URL completa o ruta pública.
    $normalizedUrl = boe_normalize_template_source_url($value);
    if ($normalizedUrl !== "") {
        $binary = boe_download_remote_binary($normalizedUrl);
        if ($binary !== "") {
            return $binary;
        }
    }

    return "";
}

function boe_describe_template_source_resolution(string $source): string
{
    $value = trim(str_replace("\\", "/", $source));
    if ($value === "") {
        return "sin ruta configurada";
    }

    $path = boe_extract_template_source_path($value);
    $normalizedUrl = boe_normalize_template_source_url($value);

    $parts = [];
    if ($value !== "") {
        $parts[] = "source=" . $value;
    }
    if ($value !== "" && $value[0] === '/') {
        $parts[] = "exists=" . (is_file($value) ? "1" : "0");
        $parts[] = "readable=" . (is_readable($value) ? "1" : "0");
    }
    if ($path !== "") {
        $parts[] = "path=" . $path;
    }
    if ($normalizedUrl !== "") {
        $parts[] = "url=" . $normalizedUrl;
    }

    return implode(" | ", $parts);
}

function boe_extract_template_source_path(string $source): string
{
    $value = trim($source);
    if ($value === "") {
        return "";
    }
    if (preg_match('#^https?://#i', $value)) {
        $parsed = parse_url($value, PHP_URL_PATH);
        return is_string($parsed) ? trim($parsed) : "";
    }
    if (strpos($value, "app.clminstal.es/") === 0) {
        return "/" . ltrim(substr($value, strlen("app.clminstal.es/")), "/");
    }
    if (strpos($value, "clminstal.es/") === 0) {
        return "/" . ltrim(substr($value, strlen("clminstal.es/")), "/");
    }
    if ($value[0] === '/') {
        return $value;
    }
    if (strpos($value, "docs/") === 0) {
        return "/" . ltrim($value, "/");
    }
    return "";
}

function boe_normalize_template_source_url(string $source): string
{
    $value = trim($source);
    if ($value === "") {
        return "";
    }
    if (preg_match('#^https?://#i', $value)) {
        return $value;
    }
    if (strpos($value, "app.clminstal.es/") === 0) {
        return "https://" . $value;
    }
    if (strpos($value, "clminstal.es/") === 0) {
        return "https://" . $value;
    }
    if ($value[0] === '/') {
        return "";
    }
    return "";
}

function boe_download_remote_binary(string $url): string
{
    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        if ($ch !== false) {
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_CONNECTTIMEOUT => 15,
                CURLOPT_TIMEOUT => 30,
                CURLOPT_SSL_VERIFYPEER => false,
                CURLOPT_SSL_VERIFYHOST => false,
                CURLOPT_USERAGENT => 'ClimaMania-BOE-Template/1.0'
            ]);
            $body = curl_exec($ch);
            $httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            if (is_string($body) && $body !== "" && $httpCode >= 200 && $httpCode < 400) {
                return $body;
            }
        }
    }

    $context = stream_context_create([
        'http' => [
            'timeout' => 30,
            'follow_location' => 1,
            'user_agent' => 'ClimaMania-BOE-Template/1.0'
        ],
        'ssl' => [
            'verify_peer' => false,
            'verify_peer_name' => false
        ]
    ]);
    $body = @file_get_contents($url, false, $context);
    return is_string($body) ? $body : "";
}

function boe_source_points_to_local_docs(string $source): bool
{
    $path = boe_extract_template_source_path($source);
    if ($path === "") {
        return false;
    }
    $normalized = ltrim(str_replace("\\", "/", trim($path)), "/");
    return strpos($normalized, "docs/") === 0;
}

function boe_pdf_signature_matches(string $binary): bool
{
    return strncmp($binary, "%PDF-", 5) === 0;
}

function boe_render_first_page_pdf_to_png(string $pdfBinary): string
{
    $tmpDir = sys_get_temp_dir() . "/clm_boe_tpl_" . bin2hex(random_bytes(6));
    if (!@mkdir($tmpDir, 0775, true) && !is_dir($tmpDir)) {
        throw new RuntimeException("No se pudo crear el directorio temporal para rasterizar el PDF del BOE");
    }

    $pdfPath = $tmpDir . "/template.pdf";
    $outputPrefix = $tmpDir . "/page";

    try {
        if (@file_put_contents($pdfPath, $pdfBinary) === false) {
            throw new RuntimeException("No se pudo escribir el PDF temporal del BOE");
        }

        $attempts = [];

        $pdftoppm = trim((string)@shell_exec('command -v pdftoppm 2>/dev/null'));
        if ($pdftoppm !== "") {
            $pngPath = $outputPrefix . ".png";
            $cmd = escapeshellarg($pdftoppm) . " -png -singlefile -f 1 -l 1 "
                . escapeshellarg($pdfPath) . " "
                . escapeshellarg($outputPrefix) . " 2>/dev/null";
            @exec($cmd, $output, $code);
            if ($code === 0 && is_file($pngPath)) {
                $pngBinary = @file_get_contents($pngPath);
                if (is_string($pngBinary) && $pngBinary !== "") {
                    return $pngBinary;
                }
            }
            $attempts[] = "pdftoppm:" . $code;
        } else {
            $attempts[] = "pdftoppm:no-disponible";
        }

        $pdftocairo = trim((string)@shell_exec('command -v pdftocairo 2>/dev/null'));
        if ($pdftocairo !== "") {
            $pngPath = $outputPrefix . ".png";
            $cmd = escapeshellarg($pdftocairo) . " -png -singlefile -f 1 -l 1 "
                . escapeshellarg($pdfPath) . " "
                . escapeshellarg($outputPrefix) . " 2>/dev/null";
            @exec($cmd, $output, $code);
            if ($code === 0 && is_file($pngPath)) {
                $pngBinary = @file_get_contents($pngPath);
                if (is_string($pngBinary) && $pngBinary !== "") {
                    return $pngBinary;
                }
            }
            $attempts[] = "pdftocairo:" . $code;
        } else {
            $attempts[] = "pdftocairo:no-disponible";
        }

        $gs = trim((string)@shell_exec('command -v gs 2>/dev/null'));
        if ($gs !== "") {
            $pngPath = $tmpDir . "/page-gs.png";
            $cmd = escapeshellarg($gs)
                . " -q -dSAFER -dBATCH -dNOPAUSE -sDEVICE=pngalpha -r150"
                . " -dFirstPage=1 -dLastPage=1"
                . " -sOutputFile=" . escapeshellarg($pngPath)
                . " " . escapeshellarg($pdfPath) . " 2>/dev/null";
            @exec($cmd, $output, $code);
            if ($code === 0 && is_file($pngPath)) {
                $pngBinary = @file_get_contents($pngPath);
                if (is_string($pngBinary) && $pngBinary !== "") {
                    return $pngBinary;
                }
            }
            $attempts[] = "gs:" . $code;
        } else {
            $attempts[] = "gs:no-disponible";
        }

        if (class_exists('Imagick')) {
            try {
                $imagick = new Imagick();
                $imagick->setResolution(150, 150);
                $imagick->readImage($pdfPath . "[0]");
                $imagick->setImageFormat("png");
                $pngBinary = $imagick->getImagesBlob();
                $imagick->clear();
                $imagick->destroy();
                if (is_string($pngBinary) && $pngBinary !== "") {
                    return $pngBinary;
                }
                $attempts[] = "imagick:blob-vacio";
            } catch (Throwable $e) {
                $attempts[] = "imagick:" . $e->getMessage();
            }
        } else {
            $attempts[] = "imagick:no-disponible";
        }

        throw new RuntimeException("No se pudo rasterizar el PDF del BOE (" . implode(" | ", $attempts) . ")");
    } finally {
        if (is_file($pdfPath)) {
            @unlink($pdfPath);
        }
        foreach (glob($tmpDir . "/page*") ?: [] as $tmpFile) {
            if (is_file($tmpFile)) {
                @unlink($tmpFile);
            }
        }
        if (is_dir($tmpDir)) {
            @rmdir($tmpDir);
        }
    }
}

function boe_overlay_page_a(
    string &$content,
    array $contexto,
    array $equipo,
    array $firmante,
    array $signatureImage,
    array $firmaMeta
): void {
    $fullName = trim((string)$contexto["cliente_nombre"] . " " . (string)$contexto["cliente_apellidos"]);
    $direccion = trim((string)$contexto["cliente_direccion"]);
    $tableX = 130.0;
    $tableW = 800.0;
    boe_pdf_draw_section_title_overlay($content, $tableX, 466, $tableW, "DATOS DEL COMPRADOR DEL EQUIPO");
    boe_pdf_draw_labeled_row($content, $tableX, 487, $tableW, 24, [
        ["width" => 597, "label" => "Nombre y apellidos/", "value" => $fullName],
        ["width" => 203, "label" => "NIF/DNI", "value" => (string)$contexto["cliente_dni"]]
    ]);
    boe_pdf_draw_labeled_row($content, $tableX, 511, $tableW, 24, [
        ["width" => $tableW, "label" => "Razón social", "value" => $fullName]
    ]);
    boe_pdf_draw_labeled_row($content, $tableX, 535, $tableW, 24, [
        ["width" => $tableW, "label" => "Domicilio", "value" => $direccion]
    ]);
    boe_pdf_draw_labeled_row($content, $tableX, 559, $tableW, 24, [
        ["width" => 141, "label" => "CP", "value" => (string)$contexto["cliente_cp"]],
        ["width" => 371, "label" => "Localidad", "value" => (string)$contexto["cliente_poblacion"]],
        ["width" => 288, "label" => "Provincia", "value" => (string)$contexto["cliente_provincia"]]
    ]);

    boe_pdf_draw_section_title_overlay($content, $tableX, 622, $tableW, "DATOS DEL EQUIPO");
    boe_pdf_draw_labeled_row($content, $tableX, 643, $tableW, 24, [
        ["width" => $tableW, "label" => "Marca", "value" => (string)$equipo["fabricante"]]
    ]);
    boe_pdf_draw_labeled_row($content, $tableX, 667, $tableW, 24, [
        ["width" => $tableW, "label" => "Modelo", "value" => (string)$equipo["codigo"]]
    ]);
    boe_pdf_draw_labeled_row($content, $tableX, 691, $tableW, 24, [
        ["width" => $tableW, "label" => "Número de serie", "value" => (string)$equipo["num_serie"]]
    ]);
    boe_pdf_draw_labeled_row($content, $tableX, 715, $tableW, 24, [
        ["width" => $tableW, "label" => "Cantidad y tipo de gas", "value" => "R-32"]
    ]);

    boe_pdf_signature_date_text($content, $contexto, $firmaMeta, 108, 1312, 300);
    boe_pdf_signature($content, $signatureImage, 658, 1478, 246, 76);
}

function boe_overlay_page_b(
    string &$content,
    array $contexto,
    array $equipo,
    array $firmante,
    array $signatureImage,
    array $firmaMeta
): void {
    $fullName = trim((string)$contexto["cliente_nombre"] . " " . (string)$contexto["cliente_apellidos"]);
    $direccionInstalacion = trim((string)$contexto["direccion_instalacion"]);
    $tableX = 130.0;
    $tableW = 800.0;
    boe_pdf_draw_section_title_overlay($content, $tableX, 384, $tableW, "DATOS DE LA INSTALACIÓN");
    boe_pdf_draw_labeled_row($content, $tableX, 405, $tableW, 24, [
        ["width" => 613, "label" => "Titular de la Instalación", "value" => $fullName],
        ["width" => 187, "label" => "NIF/DNI", "value" => (string)$contexto["cliente_dni"]]
    ]);
    boe_pdf_draw_labeled_row($content, $tableX, 429, $tableW, 24, [
        ["width" => $tableW, "label" => "Domicilio", "value" => $direccionInstalacion]
    ]);
    boe_pdf_draw_labeled_row($content, $tableX, 453, $tableW, 24, [
        ["width" => 154, "label" => "CP:", "value" => (string)$contexto["cliente_cp"]],
        ["width" => 391, "label" => "Localidad", "value" => (string)$contexto["cliente_poblacion"]],
        ["width" => 255, "label" => "Provincia", "value" => (string)$contexto["cliente_provincia"]]
    ]);

    boe_pdf_draw_section_title_overlay($content, $tableX, 516, $tableW, "DATOS DEL EQUIPO INSTALADO");
    boe_pdf_draw_labeled_row($content, $tableX, 537, $tableW, 24, [
        ["width" => $tableW, "label" => "Marca", "value" => (string)$equipo["fabricante"]]
    ]);
    boe_pdf_draw_labeled_row($content, $tableX, 561, $tableW, 24, [
        ["width" => $tableW, "label" => "Modelo", "value" => (string)$equipo["codigo"]]
    ]);
    boe_pdf_draw_labeled_row($content, $tableX, 585, $tableW, 24, [
        ["width" => $tableW, "label" => "Número de serie", "value" => (string)$equipo["num_serie"]]
    ]);
    boe_pdf_draw_labeled_row($content, $tableX, 609, $tableW, 24, [
        ["width" => $tableW, "label" => "Cantidad y tipo de gas", "value" => "R-32"]
    ]);

    boe_pdf_signature_date_text($content, $contexto, $firmaMeta, 214, 1278, 220);
    boe_pdf_signature($content, $signatureImage, 196, 1360, 214, 54);
}

function boe_pdf_signature_date_text(
    string &$content,
    array $contexto,
    array $firmaMeta,
    float $placeX,
    float $baselinePx,
    float $widthPx
): void {
    $lugar = conformidad_sanitize_plain_text((string)($contexto["cliente_poblacion"] ?? ""));
    if ($lugar === "") {
        $lugar = conformidad_sanitize_plain_text((string)($contexto["cliente_provincia"] ?? ""));
    }
    $fecha = boe_parse_signature_date((string)($firmaMeta["fecha_hora"] ?? ""));
    $texto = trim($lugar);
    $fechaCompacta = trim($fecha["day"] . "/" . $fecha["month"] . "/" . $fecha["year"], "/");
    if ($texto !== "" && $fechaCompacta !== "") {
        $texto .= ", " . $fechaCompacta;
    } elseif ($texto === "") {
        $texto = $fechaCompacta;
    }
    if ($texto === "") {
        return;
    }
    $content .= boe_pdf_text_black_cmd(
        presup_pdf_text_cmd(boe_tpl_x($placeX), boe_tpl_y($baselinePx), $texto, 8.8, false, "L", boe_tpl_w($widthPx))
    );
}

function boe_parse_signature_date(string $value): array
{
    $ts = strtotime($value);
    if ($ts === false) {
        return ["day" => "", "month" => "", "year" => ""];
    }
    return [
        "day" => date("d", $ts),
        "month" => date("m", $ts),
        "year" => date("Y", $ts)
    ];
}

function boe_pdf_draw_company_stamp(
    string &$content,
    float $centerXPx,
    float $topPx,
    float $widthPx
): void {
    $lines = [
        ["text" => "CLIMAMANIA SALES SPAIN S.L.", "size" => 7.3, "bold" => true],
        ["text" => "B-66040577", "size" => 6.5, "bold" => true],
        ["text" => "Empresa instaladora / mantenedora habilitada para", "size" => 5.4, "bold" => false],
        ["text" => "Instalaciones termicas en edificios", "size" => 5.4, "bold" => false],
        ["text" => "(Climatizacion, calefaccion y ACS)", "size" => 5.2, "bold" => false],
        ["text" => "Inscripcion RASIC: 105000668", "size" => 5.4, "bold" => false],
    ];

    $leftX = $centerXPx - ($widthPx / 2.0);
    $baseline = $topPx;
    foreach ($lines as $line) {
        $content .= boe_pdf_text_black_cmd(
            presup_pdf_text_cmd(
                boe_tpl_x($leftX),
                boe_tpl_y($baseline),
                (string)$line["text"],
                (float)$line["size"],
                (bool)$line["bold"],
                "C",
                boe_tpl_w($widthPx)
            )
        );
        $baseline += 10.0;
    }
}

function boe_pdf_draw_section_title_overlay(
    string &$content,
    float $xPx,
    float $topPx,
    float $wPx,
    string $title
): void {
    boe_pdf_fill_white($content, $xPx, $topPx, $wPx, 18);
    $content .= boe_pdf_text_black_cmd(
        presup_pdf_text_cmd(boe_tpl_x($xPx + 2), boe_tpl_y($topPx + 12), $title, 8.4, true)
    );
    boe_pdf_line_px($content, $xPx, $topPx + 18, $xPx + $wPx, $topPx + 18);
}

function boe_pdf_draw_labeled_row(
    string &$content,
    float $xPx,
    float $topPx,
    float $totalWidthPx,
    float $heightPx,
    array $cells
): void {
    boe_pdf_rect_px($content, $xPx, $topPx, $totalWidthPx, $heightPx);
    $cursor = $xPx;
    foreach ($cells as $idx => $cell) {
        $width = (float)($cell["width"] ?? 0);
        if ($idx > 0) {
            boe_pdf_line_px($content, $cursor, $topPx, $cursor, $topPx + $heightPx);
        }
        $label = conformidad_sanitize_plain_text((string)($cell["label"] ?? ""));
        $value = conformidad_sanitize_plain_text((string)($cell["value"] ?? ""));
        $labelX = $cursor + 6;
        $labelY = $topPx + 15.2;
        $content .= boe_pdf_text_black_cmd(
            presup_pdf_text_cmd(boe_tpl_x($labelX), boe_tpl_y($labelY), $label, 6.3)
        );
        if ($value !== "") {
            $estimatedLabelWidthPts = presup_pdf_estimate_text_width($label, 6.3);
            $estimatedLabelWidthPx = ($estimatedLabelWidthPts * 1131.0) / 595.32;
            $valueX = min(
                $cursor + $width - 28.0,
                $labelX + max(26.0, $estimatedLabelWidthPx + 8.0)
            );
            $valueWidth = max(28.0, ($cursor + $width - 6.0) - $valueX);
            $wrappedValue = presup_pdf_wrap_for_width($value, boe_tpl_w($valueWidth), 7.0);
            if (!empty($wrappedValue)) {
            $content .= boe_pdf_blue_text_cmd(
                presup_pdf_text_cmd(boe_tpl_x($valueX), boe_tpl_y($topPx + 15.8), $wrappedValue[0], 7.8)
            );
        }
        }
        $cursor += $width;
    }
}

function boe_pdf_value(
    string &$content,
    float $xPx,
    float $yPx,
    string $value,
    float $fontSize,
    bool $bold = false,
    float $widthPx = 0.0,
    string $align = "L"
): void {
    $text = boe_pdf_display_line($value);
    if ($text === "") {
        return;
    }
    $cmd = presup_pdf_text_cmd(
        boe_tpl_x($xPx),
        boe_tpl_y($yPx),
        $text,
        $fontSize,
        $bold,
        $align,
        $widthPx > 0 ? boe_tpl_w($widthPx) : 0.0
    );
    $content .= boe_pdf_blue_text_cmd($cmd);
}

function boe_pdf_signature(
    string &$content,
    array $signatureImage,
    float $xPx,
    float $topPx,
    float $wPx,
    float $hPx
): void {
    $content .= presup_pdf_image_cmd(
        (string)$signatureImage["name"],
        boe_tpl_x($xPx),
        boe_tpl_top($topPx),
        boe_tpl_w($wPx),
        boe_tpl_h($hPx)
    );
}

function boe_tpl_x(float $px): float
{
    return ($px * 595.32) / 1131.0;
}

function boe_tpl_y(float $py): float
{
    return 841.92 - (($py * 841.92) / 1600.0);
}

function boe_tpl_top(float $topPx): float
{
    return 841.92 - (($topPx * 841.92) / 1600.0);
}

function boe_tpl_w(float $px): float
{
    return ($px * 595.32) / 1131.0;
}

function boe_tpl_h(float $px): float
{
    return ($px * 841.92) / 1600.0;
}

function boe_pdf_blue_text_cmd(string $textCmd): string
{
    return "0.20 0.33 0.78 rg\n" . $textCmd . "0 g\n";
}

function boe_pdf_text_black_cmd(string $textCmd): string
{
    return "0 g\n" . $textCmd;
}

function boe_pdf_fill_white(
    string &$content,
    float $xPx,
    float $topPx,
    float $wPx,
    float $hPx
): void {
    $x = boe_tpl_x($xPx);
    $yBottom = boe_tpl_y($topPx + $hPx);
    $w = boe_tpl_w($wPx);
    $h = boe_tpl_h($hPx);
    $content .= "1 g 1 G "
        . presup_pdf_num($x) . " " . presup_pdf_num($yBottom) . " "
        . presup_pdf_num($w) . " " . presup_pdf_num($h) . " re f\n"
        . "0 g 0 G\n";
}

function boe_pdf_rect_px(string &$content, float $xPx, float $topPx, float $wPx, float $hPx): void
{
    $content .= presup_pdf_rect_stroke_cmd(boe_tpl_x($xPx), boe_tpl_top($topPx), boe_tpl_w($wPx), boe_tpl_h($hPx));
}

function boe_pdf_line_px(string &$content, float $x1Px, float $y1Px, float $x2Px, float $y2Px): string
{
    return $content .= presup_pdf_line_cmd(boe_tpl_x($x1Px), boe_tpl_y($y1Px), boe_tpl_x($x2Px), boe_tpl_y($y2Px));
}

function boe_pdf_display_line(string $value): string
{
    $clean = conformidad_sanitize_plain_text($value);
    return $clean !== "" ? $clean : "";
}
