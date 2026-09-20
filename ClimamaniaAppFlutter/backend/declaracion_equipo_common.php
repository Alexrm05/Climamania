<?php
// Declaración del cliente sobre equipo desinstalado.
//
// Documento independiente del conforme: se genera cuando, en un pedido con
// líneas DESINTDO / DESINSTDO, el cliente decide conservar total o
// parcialmente el equipo. Formato de contrato: cabecera con logo en cada
// página, partes intervinientes, cláusulas numeradas, firmas y pie paginado.
// Usa los primitivos de dibujo de presupuestos/conformidad (presup_pdf_*).
//
// Clave en ClimaInstal_Fotografias: DECLEQ. Carpeta: imagenes/DocDeclaracionEquipo.

require_once __DIR__ . "/presupuestos_api_common.php";
require_once __DIR__ . "/conformidad_api_common.php";

const DECLEQ_CLAVE = "DECLEQ";
const DECLEQ_SUBDIR = "DocDeclaracionEquipo";
const DECLEQ_TIPO_EVENTO = "FIRMA_DECLARACION_EQUIPO";

// Paleta corporativa (0..1). Naranja y verde del logo, grises para apoyo.
const DECLEQ_RGB_NARANJA = [0.96, 0.51, 0.13];
const DECLEQ_RGB_VERDE = [0.18, 0.61, 0.18];
const DECLEQ_RGB_GRIS_TXT = [0.40, 0.40, 0.40];
const DECLEQ_RGB_GRIS_LINEA = [0.75, 0.75, 0.75];
const DECLEQ_RGB_GRIS_FONDO = [0.94, 0.94, 0.94];

// Geometría de página (A4 vertical, puntos).
const DECLEQ_PAGE_W = 595.0;
const DECLEQ_MARGIN = 62.0;
const DECLEQ_CONTENT_W = 471.0; // 595 - 2*62
const DECLEQ_BODY_TOP = 712.0;  // primera línea de contenido bajo la cabecera
const DECLEQ_BODY_BOTTOM = 60.0; // por encima del pie

/// Elementos que el cliente puede conservar. Las claves coinciden con
/// ComponenteConservado en la app; el orden es el que se imprime.
function declaracion_equipo_elementos(): array
{
    return [
        "equipo_completo" => "Equipo completo",
        "unidad_interior" => "Unidad interior",
        "unidad_exterior" => "Unidad exterior",
        "compresor" => "Compresor",
        "placas" => "Placa/s electrónica/s",
        "motores" => "Motor/es",
        "otros" => "Otros"
    ];
}

/// Valida y normaliza la lista de elementos recibida (claves separadas por
/// coma o array JSON). Devuelve las claves válidas en orden canónico.
function declaracion_equipo_parse_elementos($raw): array
{
    $catalogo = declaracion_equipo_elementos();
    if (is_string($raw)) {
        $decoded = json_decode($raw, true);
        $raw = is_array($decoded) ? $decoded : explode(",", $raw);
    }
    if (!is_array($raw)) {
        return [];
    }
    $seleccion = [];
    foreach ($raw as $item) {
        $clave = strtolower(trim((string)$item));
        if ($clave !== "" && array_key_exists($clave, $catalogo)) {
            $seleccion[$clave] = true;
        }
    }
    return array_values(array_filter(array_keys($catalogo), fn($k) => isset($seleccion[$k])));
}

/// Líneas "Elemento" listas para imprimir; "Otros" lleva el detalle.
function declaracion_equipo_lineas_elementos(array $claves, string $otrosDetalle): array
{
    $catalogo = declaracion_equipo_elementos();
    $lineas = [];
    foreach ($claves as $clave) {
        $etiqueta = $catalogo[$clave] ?? $clave;
        if ($clave === "otros") {
            $detalle = conformidad_sanitize_plain_text($otrosDetalle);
            $etiqueta .= $detalle !== "" ? ": " . $detalle : "";
        }
        $lineas[] = $etiqueta;
    }
    return $lineas;
}

// ---------------------------------------------------------------------------
// Primitivos de dibujo propios (color y formas que no ofrecen los comunes)
// ---------------------------------------------------------------------------

function declaracion_pdf_rgb(array $rgb): string
{
    return presup_pdf_num((float)$rgb[0]) . " " . presup_pdf_num((float)$rgb[1]) . " " . presup_pdf_num((float)$rgb[2]);
}

function declaracion_pdf_fill_rect(float $x, float $topY, float $w, float $h, array $rgb): string
{
    return declaracion_pdf_rgb($rgb) . " rg "
        . presup_pdf_num($x) . " " . presup_pdf_num($topY - $h) . " "
        . presup_pdf_num($w) . " " . presup_pdf_num($h) . " re f\n0 g\n";
}

function declaracion_pdf_line(float $x1, float $y1, float $x2, float $y2, array $rgb, float $width = 0.6): string
{
    return declaracion_pdf_rgb($rgb) . " RG " . presup_pdf_num($width) . " w\n"
        . presup_pdf_line_cmd($x1, $y1, $x2, $y2)
        . "0 G 1 w\n";
}

function declaracion_pdf_rect(float $x, float $topY, float $w, float $h, array $rgb, float $width = 0.6): string
{
    return declaracion_pdf_rgb($rgb) . " RG " . presup_pdf_num($width) . " w\n"
        . presup_pdf_rect_stroke_cmd($x, $topY, $w, $h)
        . "0 G 1 w\n";
}

function declaracion_pdf_text(float $x, float $y, string $text, float $size, bool $bold = false, ?array $rgb = null): string
{
    if ($rgb === null) {
        return "0 g\n" . presup_pdf_text_cmd($x, $y, $text, $size, $bold);
    }
    return conformidad_pdf_colored_text_cmd($x, $y, $text, $size, $bold, $rgb);
}

/// Texto alineado a la derecha dentro de una caja [x, x+boxW], con color.
function declaracion_pdf_text_right(float $x, float $y, float $boxW, string $text, float $size, bool $bold = false, ?array $rgb = null): string
{
    $color = $rgb === null ? "0 g\n" : declaracion_pdf_rgb($rgb) . " rg\n";
    return $color . presup_pdf_text_cmd($x, $y, $text, $size, $bold, "R", $boxW) . "0 g\n";
}

/// Casilla de verificación dibujada (Helvetica no tiene el glifo ☒).
function declaracion_pdf_checkbox(float $x, float $y, bool $checked): string
{
    $s = 7.5;
    $out = declaracion_pdf_rect($x, $y + $s - 1.5, $s, $s, [0.2, 0.2, 0.2], 0.7);
    if ($checked) {
        $out .= declaracion_pdf_line($x + 1.6, $y + 2.2, $x + $s - 1.6, $y + $s - 3.3, DECLEQ_RGB_VERDE, 1.2);
        $out .= declaracion_pdf_line($x + 1.6, $y + $s - 3.3, $x + $s - 1.6, $y + 2.2, DECLEQ_RGB_VERDE, 1.2);
    }
    return $out;
}

/// Párrafo de texto normal con salto de página automático.
function declaracion_pdf_paragraph(
    array &$pages,
    string &$page,
    int &$pageNo,
    float $y,
    string $text,
    ?array $logo,
    float $size = 8.3,
    float $lineH = 10.0,
    bool $bold = false,
    ?array $rgb = null,
    float $indent = 0.0
): float {
    $lines = presup_pdf_wrap_for_width($text, DECLEQ_CONTENT_W - $indent, $size);
    foreach ($lines as $line) {
        $y = declaracion_pdf_ensure_space($pages, $page, $pageNo, $y, $lineH, $logo);
        $page .= declaracion_pdf_text(DECLEQ_MARGIN + $indent, $y, $line, $size, $bold, $rgb);
        $y -= $lineH;
    }
    return $y;
}

/// Título de cláusula: ordinal en naranja + rótulo, con filete fino debajo.
function declaracion_pdf_clausula(
    array &$pages,
    string &$page,
    int &$pageNo,
    float $y,
    string $ordinal,
    string $rotulo,
    ?array $logo
): float {
    // Reservar espacio para el título y al menos dos líneas de cuerpo.
    $y = declaracion_pdf_ensure_space($pages, $page, $pageNo, $y, 36.0, $logo);
    $page .= declaracion_pdf_text(DECLEQ_MARGIN, $y, $ordinal . ".", 9.2, true, DECLEQ_RGB_NARANJA);
    $page .= declaracion_pdf_text(DECLEQ_MARGIN + 52.0, $y, mb_strtoupper($rotulo, "UTF-8"), 9.2, true);
    $page .= declaracion_pdf_line(DECLEQ_MARGIN, $y - 4.0, DECLEQ_MARGIN + DECLEQ_CONTENT_W, $y - 4.0, DECLEQ_RGB_GRIS_LINEA, 0.4);
    return $y - 12.0;
}

// ---------------------------------------------------------------------------
// Página: cabecera con logo, filete corporativo y (al final) pie paginado
// ---------------------------------------------------------------------------

/// Sello de empresa sin la franja de texto del escaneo original. Si no
/// existiera la copia limpia, cae al sello que usa el conforme.
function declaracion_load_stamp_image(): array
{
    $path = __DIR__ . "/assets/conforme_template/company_stamp_clean.png";
    $binary = @file_get_contents($path);
    if (is_string($binary) && $binary !== "") {
        $image = presup_build_pdf_image_from_binary($binary, "IMDECLSTAMP");
        if ($image !== null) {
            return $image;
        }
    }
    return conformidad_load_company_stamp_image();
}

function declaracion_load_logo_image(): ?array
{
    // Copia local aplanada sobre blanco: no depende de la red del servidor.
    $path = __DIR__ . "/assets/conforme_template/climamania_logo.png";
    $binary = @file_get_contents($path);
    if (is_string($binary) && $binary !== "") {
        $image = presup_build_pdf_image_from_binary($binary, "IMDECLLOGO");
        if ($image !== null) {
            return $image;
        }
    }
    // Si faltara el asset, el logo oficial que usan los presupuestos.
    return presup_load_pdf_logo_image();
}

function declaracion_pdf_start_page(string &$page, int $pageNo, ?array $logo, bool $continuacion): float
{
    $left = DECLEQ_MARGIN;
    $right = DECLEQ_MARGIN + DECLEQ_CONTENT_W;

    // Logo, ajustado a una caja sin deformar.
    if ($logo !== null) {
        $boxW = 168.0;
        $boxH = 40.0;
        $boxTop = 800.0;
        $scale = min($boxW / max(1.0, (float)$logo["width"]), $boxH / max(1.0, (float)$logo["height"]));
        $drawW = (float)$logo["width"] * $scale;
        $drawH = (float)$logo["height"] * $scale;
        $page .= presup_pdf_image_cmd((string)$logo["name"], $left, $boxTop - (($boxH - $drawH) / 2.0), $drawW, $drawH);
    } else {
        $page .= declaracion_pdf_text($left, 778.0, "ClimaMania", 20.0, true, DECLEQ_RGB_NARANJA);
    }

    // Datos de la empresa, alineados a la derecha.
    $boxW = 300.0;
    $ry = 796.0;
    $page .= declaracion_pdf_text_right($right - $boxW, $ry, $boxW, "CLIMAMANIA SALES SPAIN S.L.", 8.6, true);
    foreach ([
        "CIF B66040577",
        "C/ Electrónica 14, P.I. La Ferreria · 08110 Montcada i Reixac (Barcelona)",
        "Tel. 933 282 421 · www.climamania.com"
    ] as $line) {
        $ry -= 10.0;
        $page .= declaracion_pdf_text_right($right - $boxW, $ry, $boxW, $line, 7.0, false, DECLEQ_RGB_GRIS_TXT);
    }
    // Filete corporativo bajo la cabecera.
    $page .= declaracion_pdf_fill_rect($left, 754.0, DECLEQ_CONTENT_W, 2.2, DECLEQ_RGB_NARANJA);
    $page .= declaracion_pdf_fill_rect($left, 751.0, DECLEQ_CONTENT_W, 0.6, DECLEQ_RGB_VERDE);

    if ($continuacion) {
        $page .= conformidad_pdf_colored_text_cmd($left, 738.0, "DECLARACIÓN DEL CLIENTE SOBRE EQUIPO DESINSTALADO (continuación)", 8.0, true, DECLEQ_RGB_GRIS_TXT);
        return 716.0;
    }
    return DECLEQ_BODY_TOP;
}

function declaracion_pdf_ensure_space(array &$pages, string &$page, int &$pageNo, float $y, float $needed, ?array $logo): float
{
    if ($y - $needed >= DECLEQ_BODY_BOTTOM) {
        return $y;
    }
    $pages[] = $page;
    $page = "";
    $pageNo++;
    return declaracion_pdf_start_page($page, $pageNo, $logo, true);
}

/// Pie de página con numeración "i de N": se añade cuando ya se conocen
/// todas las páginas.
function declaracion_pdf_apply_footers(array $pages, string $referencia, string $fechaFirma): array
{
    $total = count($pages);
    $left = DECLEQ_MARGIN;
    $right = DECLEQ_MARGIN + DECLEQ_CONTENT_W;
    foreach ($pages as $i => $page) {
        $n = $i + 1;
        $page .= declaracion_pdf_line($left, 52.0, $right, 52.0, DECLEQ_RGB_GRIS_LINEA, 0.5);
        $page .= conformidad_pdf_colored_text_cmd(
            $left, 42.0,
            "Declaración del cliente sobre equipo desinstalado · Pedido " . $referencia
            . " · Firmado electrónicamente el " . $fechaFirma,
            6.8, false, DECLEQ_RGB_GRIS_TXT
        );
        $page .= "0 g\n" . presup_pdf_text_cmd($right - 80.0, 42.0, "Página " . $n . " de " . $total, 6.8, false, "R", 80.0);
        $page .= conformidad_pdf_colored_text_cmd(
            $left, 33.0,
            "Documento generado por la aplicación de instaladores de ClimaMania. La firma manuscrita electrónica queda registrada con fecha, hora y posición GPS.",
            6.2, false, DECLEQ_RGB_GRIS_TXT
        );
        $pages[$i] = $page;
    }
    return $pages;
}

// ---------------------------------------------------------------------------
// Documento
// ---------------------------------------------------------------------------

function declaracion_equipo_build_pdf(
    array $contexto,
    array $elementosClaves,
    string $otrosDetalle,
    array $firmante,
    string $signatureBinary,
    array $locationEvent
): string {
    $signatureImage = presup_build_pdf_image_from_binary($signatureBinary, "IMDECL");
    if ($signatureImage === null) {
        throw new RuntimeException("No se pudo procesar la firma manuscrita");
    }
    $stamp = declaracion_load_stamp_image();
    $logo = declaracion_load_logo_image();
    $images = [$signatureImage, $stamp];
    if ($logo !== null) {
        $images[] = $logo;
    }

    $left = DECLEQ_MARGIN;
    $width = DECLEQ_CONTENT_W;
    $right = $left + $width;

    $referencia = conformidad_sanitize_plain_text((string)$contexto["referencia"]);
    $fullName = conformidad_sanitize_plain_text(trim($contexto["cliente_nombre"] . " " . $contexto["cliente_apellidos"]));
    $dni = conformidad_sanitize_plain_text((string)$contexto["cliente_dni"]);
    $direccion = conformidad_sanitize_plain_text((string)$contexto["cliente_direccion"]);
    $cpPoblacion = conformidad_sanitize_plain_text(trim($contexto["cliente_cp"] . " " . $contexto["cliente_poblacion"]));
    $provincia = conformidad_sanitize_plain_text((string)$contexto["cliente_provincia"]);
    $poblacion = conformidad_sanitize_plain_text((string)($contexto["cliente_poblacion"] ?? ""));
    $fechaFirma = conformidad_format_pdf_datetime((string)($locationEvent["fecha_hora"] ?? ""));
    $lat = conformidad_format_coordinate($locationEvent["latitud"] ?? "");
    $lng = conformidad_format_coordinate($locationEvent["longitud"] ?? "");

    $pages = [];
    $page = "";
    $pageNo = 1;
    $y = declaracion_pdf_start_page($page, $pageNo, $logo, false);

    // ---- Título y referencia del documento --------------------------------
    $page .= "0 g\n" . presup_pdf_text_cmd($left, $y, "DECLARACIÓN DEL CLIENTE SOBRE EQUIPO DESINSTALADO", 14.0, true, "C", $width);
    $y -= 15.0;
    $page .= conformidad_pdf_colored_text_cmd($left, $y, "Servicio de desmontaje de equipo de climatización", 8.6, false, DECLEQ_RGB_GRIS_TXT);
    $page .= "0 g\n" . presup_pdf_text_cmd($left, $y, "Nº doc. DECLEQ-" . $referencia . "   ·   " . $fechaFirma, 8.0, false, "R", $width);
    $y -= 18.0;

    // ---- Partes intervinientes --------------------------------------------
    $page .= declaracion_pdf_text($left, $y, "INTERVIENEN", 9.6, true, DECLEQ_RGB_NARANJA);
    $y -= 12.0;

    $boxTop = $y;
    $boxH = 80.0;
    $colW = $width / 2.0;
    $page .= declaracion_pdf_fill_rect($left, $boxTop, $width, 15.0, DECLEQ_RGB_GRIS_FONDO);
    $page .= declaracion_pdf_rect($left, $boxTop, $width, $boxH, DECLEQ_RGB_GRIS_LINEA);
    $page .= declaracion_pdf_line($left + $colW, $boxTop, $left + $colW, $boxTop - $boxH, DECLEQ_RGB_GRIS_LINEA);
    $page .= declaracion_pdf_text($left + 8.0, $boxTop - 10.5, "EL CLIENTE", 8.4, true);
    $page .= declaracion_pdf_text($left + $colW + 8.0, $boxTop - 10.5, "LA EMPRESA", 8.4, true);

    $cy = $boxTop - 28.0;
    foreach ([
        ["Nombre", $fullName],
        ["DNI/NIF", $dni],
        ["Dirección", $direccion],
        ["Población", trim($cpPoblacion . ($provincia !== "" ? " (" . $provincia . ")" : ""))],
        ["Pedido", $referencia]
    ] as [$label, $value]) {
        $page .= conformidad_pdf_colored_text_cmd($left + 8.0, $cy, $label . ":", 7.6, true, DECLEQ_RGB_GRIS_TXT);
        $wrapped = presup_pdf_wrap_for_width($value, $colW - 70.0, 8.0);
        $page .= declaracion_pdf_text($left + 58.0, $cy, $wrapped[0] ?? "", 8.0);
        $cy -= 11.0;
    }
    $ey = $boxTop - 28.0;
    foreach ([
        ["CLIMAMANIA SALES SPAIN S.L.", true],
        ["CIF: B66040577", false],
        ["C/ Electrónica 14, P.I. La Ferreria", false],
        ["08110 Montcada i Reixac (Barcelona)", false],
        ["Tel.: 933 282 421", false]
    ] as [$line, $bold]) {
        $page .= declaracion_pdf_text($left + $colW + 8.0, $ey, $line, 8.0, $bold);
        $ey -= 11.0;
    }
    $y = $boxTop - $boxH - 12.0;

    // ---- Exposición y cláusulas -------------------------------------------
    $page .= declaracion_pdf_text($left, $y, "EXPONE Y DECLARA", 9.6, true, DECLEQ_RGB_NARANJA);
    $y -= 12.0;
    $y = declaracion_pdf_paragraph($pages, $page, $pageNo, $y,
        "El cliente arriba identificado manifiesta expresamente que, por decisión propia, ha solicitado que CLIMAMANIA SALES SPAIN S.L. no retire total o parcialmente el equipo de climatización objeto del servicio de desmontaje, y a tal efecto suscribe las siguientes cláusulas:",
        $logo);
    $y -= 6.0;

    // PRIMERA: elementos conservados (solo los seleccionados), con casillas.
    $y = declaracion_pdf_clausula($pages, $page, $pageNo, $y, "PRIMERA", "Elementos que conserva el cliente", $logo);
    $y = declaracion_pdf_paragraph($pages, $page, $pageNo, $y,
        "El cliente solicita conservar bajo su exclusiva responsabilidad los siguientes elementos del equipo desinstalado:",
        $logo);
    $y -= 3.0;
    $lineas = declaracion_equipo_lineas_elementos($elementosClaves, $otrosDetalle);
    $rowH = 11.5;
    $tableH = count($lineas) * $rowH + 8.0;
    $y = declaracion_pdf_ensure_space($pages, $page, $pageNo, $y, $tableH + 4.0, $logo);
    $page .= declaracion_pdf_fill_rect($left + 12.0, $y, $width - 24.0, $tableH, [0.985, 0.985, 0.985]);
    $page .= declaracion_pdf_rect($left + 12.0, $y, $width - 24.0, $tableH, DECLEQ_RGB_GRIS_LINEA);
    $ry = $y - 11.5;
    foreach ($lineas as $linea) {
        $page .= declaracion_pdf_checkbox($left + 22.0, $ry - 1.5, true);
        $wrapped = presup_pdf_wrap_for_width($linea, $width - 70.0, 8.6);
        $page .= declaracion_pdf_text($left + 36.0, $ry, $wrapped[0] ?? $linea, 8.6, true);
        $ry -= $rowH;
    }
    $y -= $tableH + 10.0;

    $clausulas = [
        ["SEGUNDA", "Información sobre el servicio contratado",
            "El cliente declara haber sido informado de que el servicio contratado contempla la retirada del equipo completo para su posterior gestión y reciclaje, y que la conservación total o parcial del mismo se realiza por petición expresa del propio cliente."],
        ["TERCERA", "Gases fluorados y personal habilitado",
            "Asimismo, el cliente queda expresamente informado de que los equipos de climatización pueden contener gases fluorados y otros elementos sujetos a requisitos específicos de manipulación, recuperación y gestión, y que cualquier intervención sobre el circuito frigorífico deberá ser realizada por personal debidamente certificado/habilitado conforme a la normativa vigente."],
        ["CUARTA", "Compromiso del cliente",
            "El cliente se compromete a no manipular, desmontar, cortar, abrir o intervenir el circuito frigorífico por sus propios medios ni permitir que lo haga personal que no disponga de la correspondiente certificación/habilitación."],
        ["QUINTA", "Exención de responsabilidad",
            "CLIMAMANIA SALES SPAIN S.L. no se responsabilizará de las manipulaciones, desmontajes, reutilizaciones o gestión posterior que puedan realizarse sobre los componentes que, por petición expresa del cliente, permanezcan en su poder."],
        ["SEXTA", "Conformidad y entrega",
            "Con su firma, el cliente confirma que la decisión de conservar los elementos anteriormente indicados ha sido adoptada expresamente por él y que dichos elementos han quedado efectivamente en su poder en el domicilio indicado."]
    ];
    foreach ($clausulas as [$ordinal, $rotulo, $texto]) {
        $y = declaracion_pdf_clausula($pages, $page, $pageNo, $y, $ordinal, $rotulo, $logo);
        $y = declaracion_pdf_paragraph($pages, $page, $pageNo, $y, $texto, $logo);
        $y -= 4.0;
    }

    // ---- Lugar, fecha y firmas (bloque indivisible) ------------------------
    $y = declaracion_pdf_ensure_space($pages, $page, $pageNo, $y, 138.0, $logo);
    $y -= 2.0;
    $lugar = $poblacion !== "" ? $poblacion : "el domicilio indicado";
    $page .= declaracion_pdf_text($left, $y, "Y en prueba de conformidad, firma la presente declaración en " . $lugar . ", a " . $fechaFirma . ".", 8.6);
    $y -= 11.0;
    $page .= conformidad_pdf_colored_text_cmd($left, $y, "Posición GPS registrada en el momento de la firma: lat. " . $lat . ", long. " . $lng, 7.2, false, DECLEQ_RGB_GRIS_TXT);
    $y -= 13.0;

    $panelTop = $y;
    $panelH = 100.0;
    $page .= declaracion_pdf_rect($left, $panelTop, $width, $panelH, DECLEQ_RGB_GRIS_LINEA);
    $page .= declaracion_pdf_line($left + $colW, $panelTop, $left + $colW, $panelTop - $panelH, DECLEQ_RGB_GRIS_LINEA);
    $page .= declaracion_pdf_fill_rect($left, $panelTop, $width, 15.0, DECLEQ_RGB_GRIS_FONDO);
    $page .= declaracion_pdf_text($left + 8.0, $panelTop - 10.5, "POR CLIMAMANIA SALES SPAIN S.L.", 8.4, true);
    $page .= declaracion_pdf_text($left + $colW + 8.0, $panelTop - 10.5, "EL CLIENTE", 8.4, true);

    // Sello de empresa centrado en su columna, con su proporción real.
    $stampH = 56.0;
    $stampW = $stampH * max(0.1, ((float)$stamp["width"]) / max(1.0, (float)$stamp["height"]));
    $page .= presup_pdf_image_cmd((string)$stamp["name"], $left + ($colW - $stampW) / 2.0, $panelTop - 22.0, $stampW, $stampH);

    // Firma manuscrita del cliente sobre una línea, y datos debajo.
    $sigColX = $left + $colW + 8.0;
    $sigLineY = $panelTop - 62.0;
    $sigMaxH = 36.0;
    $aspect = max(0.1, ((float)$signatureImage["width"]) / max(1.0, (float)$signatureImage["height"]));
    $sigH = $sigMaxH;
    $sigW = min($colW - 40.0, $sigH * $aspect);
    if ($sigW < 60.0) {
        $sigW = 60.0;
        $sigH = $sigW / $aspect;
    }
    $page .= presup_pdf_image_cmd((string)$signatureImage["name"], $sigColX + 12.0, $sigLineY + $sigH + 2.0, $sigW, $sigH);
    $page .= declaracion_pdf_line($sigColX, $sigLineY, $left + $width - 8.0, $sigLineY, [0.3, 0.3, 0.3], 0.6);
    $page .= conformidad_pdf_colored_text_cmd($sigColX, $sigLineY - 9.0, "Firma manuscrita electrónica", 6.6, false, DECLEQ_RGB_GRIS_TXT);
    $page .= declaracion_pdf_text($sigColX, $sigLineY - 24.0, "Nombre: " . conformidad_pdf_display_line((string)$firmante["nombre_completo"]), 8.0);
    $page .= declaracion_pdf_text($sigColX, $sigLineY - 36.0, "DNI/NIF: " . conformidad_pdf_display_line((string)$firmante["dni"]), 8.0);

    $pages[] = $page;
    $pages = declaracion_pdf_apply_footers($pages, $referencia, $fechaFirma);
    return presup_build_pdf_document($pages, $images);
}
