<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/presupuestos_api_common.php";
require_once __DIR__ . "/ubicaciones_eventos_common.php";

$API_KEY = "TEST123";
$PS_PREFIX = isset($PS_DB_PREFIX) && $PS_DB_PREFIX !== "" ? $PS_DB_PREFIX : "ps_";

if (request_value("api_key") !== $API_KEY) {
    json_exit(["success" => false, "message" => "API key invalida"], 401);
}

$referencia = normalize_text(request_value("referencia"), 64);
$numeroPedido = normalize_text(request_value("numero_pedido"), 64);
$nombreCliente = normalize_text(request_value("nombre_cliente"), 255);
$direccionCliente = normalize_text(request_value("direccion_cliente"), 1000);
$telefono = normalize_text(request_value("telefono"), 80);
$emailClienteInput = normalize_email(request_value("email_cliente"));
$usuarioInstalador = normalize_text(request_value("usuario_instalador"), 100);
$equipoInstaladores = normalize_text(request_value("equipo_instaladores"), 100);
$firmaBase64 = trim((string)request_value("firma_base64"));
$lineasJsonRaw = trim((string)request_value("lineas_json"));

if ($numeroPedido === "") {
    $numeroPedido = $referencia;
}

if ($numeroPedido === "") {
    $numeroPedido = "MANUAL-" . date("YmdHis");
}
if ($firmaBase64 === "") {
    json_exit(["success" => false, "message" => "La firma del cliente es obligatoria"], 400);
}
if ($lineasJsonRaw === "") {
    json_exit(["success" => false, "message" => "No hay lineas para guardar"], 400);
}

$lineas = presup_parse_lineas($lineasJsonRaw);
if (empty($lineas)) {
    json_exit(["success" => false, "message" => "No hay lineas validas para guardar"], 400);
}

$pdo = null;
$idPresupuesto = 0;
$firmaRelativePath = "";
$pdfRelativePath = "";
$pdfAbsolutePath = "";
$emailEnvio = "";
$emailPersistencia = "";
$emailClienteForPdf = "";

try {
    $pdo = getDBConnection();
    $psPdo = getPSConnection();
    $psPrefix = presup_resolve_ps_prefix($psPdo, $PS_PREFIX);

    $referenciaLookup = $referencia !== "" ? $referencia : $numeroPedido;
    $isReferenciaPedido = $referenciaLookup !== "" && !presup_is_manual_reference($referenciaLookup);
    $emailReferencia = "";

    if ($isReferenciaPedido) {
        $fallbackData = fetch_header_fallback_data($pdo, $psPdo, $psPrefix, $referenciaLookup);
        if ($nombreCliente === "" && $fallbackData["nombre_cliente"] !== "") {
            $nombreCliente = $fallbackData["nombre_cliente"];
        }
        if ($direccionCliente === "" && $fallbackData["direccion_cliente"] !== "") {
            $direccionCliente = $fallbackData["direccion_cliente"];
        }
        if ($telefono === "" && $fallbackData["telefono"] !== "") {
            $telefono = $fallbackData["telefono"];
        }
        $emailReferencia = presup_resolve_reference_customer_email($psPdo, $psPrefix, $referenciaLookup);
    }

    if ($isReferenciaPedido) {
        if ($emailReferencia !== "") {
            $emailEnvio = $emailReferencia;
            $emailPersistencia = $emailReferencia;
        } else {
            if ($emailClienteInput === "") {
                json_exit([
                    "success" => false,
                    "message" => "Esta referencia no tiene email. Introduce uno para este envio"
                ], 400);
            }
            $emailEnvio = $emailClienteInput;
            // Temporal: no se persiste en BD.
            $emailPersistencia = "";
        }
    } else {
        if ($emailClienteInput === "") {
            json_exit([
                "success" => false,
                "message" => "Sin referencia debes indicar un email de cliente valido"
            ], 400);
        }
        $emailEnvio = $emailClienteInput;
        $emailPersistencia = $emailClienteInput;
    }

    $emailClienteForPdf = $emailEnvio !== "" ? $emailEnvio : $emailPersistencia;
    if ($emailClienteForPdf === "") {
        $emailClienteForPdf = $emailClienteInput;
    }

    if ($nombreCliente === "") {
        $nombreCliente = "Cliente";
    }

    $totals = presup_calculate_totals($lineas);

    $pdo->beginTransaction();

    $stmt = $pdo->prepare(
        "INSERT INTO ClimaInstal_PresupuestosInstalador
            (NumeroPedido, NombreCliente, DireccionCliente, Telefono, EmailCliente,
             FotoFirma, PdfPresupuesto, FechaPresupuesto, FechaAceptacion,
             EquipoInstaladores, UsuarioInstalador,
             ImporteSinIva, ImporteIva, ImporteConIva,
             Estado, Origen, MailEnviado, date_add, date_upd)
         VALUES
            (:NumeroPedido, :NombreCliente, :DireccionCliente, :Telefono, :EmailCliente,
             '', '', NOW(), NOW(),
             :EquipoInstaladores, :UsuarioInstalador,
             :ImporteSinIva, :ImporteIva, :ImporteConIva,
             'ACEPTADO', 'APP_ANDROID', 0, NOW(), NOW())"
    );
    $stmt->execute([
        ":NumeroPedido" => $numeroPedido,
        ":NombreCliente" => $nombreCliente,
        ":DireccionCliente" => $direccionCliente,
        ":Telefono" => $telefono,
        ":EmailCliente" => $emailPersistencia,
        ":EquipoInstaladores" => $equipoInstaladores,
        ":UsuarioInstalador" => $usuarioInstalador,
        ":ImporteSinIva" => format_decimal($totals["sin_iva"], 2),
        ":ImporteIva" => format_decimal($totals["iva"], 2),
        ":ImporteConIva" => format_decimal($totals["con_iva"], 2)
    ]);

    $idPresupuesto = (int)$pdo->lastInsertId();
    if ($idPresupuesto <= 0) {
        throw new RuntimeException("No se pudo obtener el ID del presupuesto");
    }

    $firmaData = presup_save_signature_image_from_base64($firmaBase64, $idPresupuesto);
    $firmaRelativePath = $firmaData["relative_path"];

    $pdfData = presup_save_budget_pdf(
        $idPresupuesto,
        $numeroPedido,
        $nombreCliente,
        $direccionCliente,
        $telefono,
        $emailClienteForPdf,
        $usuarioInstalador,
        $equipoInstaladores,
        $lineas,
        $totals,
        $firmaRelativePath,
        [
            "fecha_hora" => date("d-m-Y H:i:s"),
            "latitud" => trim((string)request_value("latitud")),
            "longitud" => trim((string)request_value("longitud")),
        ]
    );
    $pdfRelativePath = $pdfData["relative_path"];
    $pdfAbsolutePath = $pdfData["absolute_path"];

    $insertLinea = $pdo->prepare(
        "INSERT INTO ClimaInstal_PresupuestosInstalador_Lineas
            (ID_Presupuesto, OrdenLinea, Cantidad, Articulo, Descripcion,
             PrecioUnitarioSinIva, PrecioTotalLinea, IvaPct, PrecioTotalLineaConIva,
             IvaFallback, date_add, date_upd)
         VALUES
            (:ID_Presupuesto, :OrdenLinea, :Cantidad, :Articulo, :Descripcion,
             :PrecioUnitarioSinIva, :PrecioTotalLinea, :IvaPct, :PrecioTotalLineaConIva,
             :IvaFallback, NOW(), NOW())"
    );

    $order = 1;
    foreach ($lineas as $linea) {
        $insertLinea->execute([
            ":ID_Presupuesto" => $idPresupuesto,
            ":OrdenLinea" => $order,
            ":Cantidad" => format_decimal($linea["cantidad"], 2),
            ":Articulo" => $linea["articulo"],
            ":Descripcion" => $linea["descripcion"],
            ":PrecioUnitarioSinIva" => format_decimal($linea["precio_unitario_sin_iva"], 6),
            ":PrecioTotalLinea" => format_decimal($linea["precio_total_linea"], 2),
            ":IvaPct" => format_decimal($linea["iva_pct"], 3),
            ":PrecioTotalLineaConIva" => format_decimal($linea["precio_total_linea_con_iva"], 2),
            ":IvaFallback" => $linea["iva_fallback"] ? 1 : 0
        ]);
        $order++;
    }

    $updateHeader = $pdo->prepare(
        "UPDATE ClimaInstal_PresupuestosInstalador
         SET FotoFirma = :FotoFirma,
             PdfPresupuesto = :PdfPresupuesto,
             date_upd = NOW()
         WHERE ID_Presupuesto = :ID_Presupuesto
         LIMIT 1"
    );
    $updateHeader->execute([
        ":FotoFirma" => $firmaRelativePath,
        ":PdfPresupuesto" => $pdfRelativePath,
        ":ID_Presupuesto" => $idPresupuesto
    ]);

    clm_eventos_insert_location_event($pdo, [
        "referencia" => $referencia,
        "id_presupuesto" => $idPresupuesto,
        "numero_pedido" => $numeroPedido,
        "tipo_evento" => "FIRMA_ADICIONALES",
        "latitud" => request_value("latitud"),
        "longitud" => request_value("longitud"),
        "usuario" => $usuarioInstalador,
        "origen" => "APP_ANDROID"
    ]);

    $pdo->commit();

    $destinatariosBcc = presup_fetch_bcc_destinations($pdo);
    $asunto = "Nota de Cargo Adicionales Instalacion " . $numeroPedido;
    $body = presup_build_email_body(
        $idPresupuesto,
        $numeroPedido,
        $nombreCliente,
        $direccionCliente,
        $totals,
        $lineas
    );

    $mailSent = false;
    $mailError = "";
    $pdfPublicUrl = presup_build_public_url($pdfRelativePath);
    $mailSent = presup_send_mail_with_attachment(
        $emailEnvio,
        $destinatariosBcc,
        $asunto,
        $body,
        $pdfAbsolutePath,
        basename($pdfAbsolutePath),
        $pdfPublicUrl,
        $mailError
    );
    if (!$mailSent && $mailError === "") {
        $mailError = "No se pudo enviar el correo";
    }
    $mailErrorDb = ($mailSent && $mailError === "")
        ? null
        : normalize_text($mailError, 500);

    try {
        $mailUpdate = $pdo->prepare(
            "UPDATE ClimaInstal_PresupuestosInstalador
             SET MailEnviado = :MailEnviado,
                 FechaEnvioMail = NOW(),
                 MailError = :MailError,
                 date_upd = NOW()
             WHERE ID_Presupuesto = :ID_Presupuesto
             LIMIT 1"
        );
        $mailUpdate->execute([
            ":MailEnviado" => $mailSent ? 1 : 0,
            ":MailError" => $mailErrorDb,
            ":ID_Presupuesto" => $idPresupuesto
        ]);
    } catch (Exception $ignored) {
        // No bloquear la respuesta si el update de estado de email falla.
    }

    $message = "Presupuesto guardado correctamente";
    if ($mailSent && $mailError === "") {
        $message = "Presupuesto guardado y enviado correctamente";
    } elseif ($mailSent) {
        $message = "Presupuesto guardado y enviado con avisos: " . $mailError;
    } elseif ($mailError !== "") {
        $message = "Presupuesto guardado: " . $mailError;
    }

    json_exit([
        "success" => true,
        "message" => $message,
        "id_presupuesto" => $idPresupuesto,
        "firma" => $firmaRelativePath,
        "pdf" => $pdfRelativePath,
        "mail_enviado" => $mailSent,
        "mail_error" => $mailErrorDb ?? ""
    ]);
} catch (Exception $e) {
    if ($pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}

function request_value(string $key): string
{
    if (isset($_POST[$key])) {
        return trim((string)$_POST[$key]);
    }
    if (isset($_GET[$key])) {
        return trim((string)$_GET[$key]);
    }
    return "";
}

function json_exit(array $payload, int $status = 200): void
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

function normalize_text(string $value, int $maxLen = 1000): string
{
    $clean = trim(str_replace("\0", "", $value));
    if ($maxLen > 0 && mb_strlen($clean, "UTF-8") > $maxLen) {
        $clean = mb_substr($clean, 0, $maxLen, "UTF-8");
    }
    return $clean;
}

function normalize_email(string $value): string
{
    $clean = trim($value);
    return filter_var($clean, FILTER_VALIDATE_EMAIL) ? $clean : "";
}

function parse_decimal($raw, float $default = 0.0): float
{
    $value = trim((string)$raw);
    if ($value === "") {
        return $default;
    }
    $value = str_replace(",", ".", $value);
    if (!is_numeric($value)) {
        return $default;
    }
    return (float)$value;
}

function format_decimal(float $value, int $scale): string
{
    return number_format($value, $scale, ".", "");
}

function parse_lineas_presupuesto(string $jsonRaw): array
{
    $decoded = json_decode($jsonRaw, true);
    if (!is_array($decoded)) {
        return [];
    }

    $lineas = [];
    foreach ($decoded as $row) {
        if (!is_array($row)) {
            continue;
        }

        $cantidad = parse_decimal($row["cantidad"] ?? "0", 0.0);
        if ($cantidad <= 0.0) {
            continue;
        }

        $articulo = normalize_text((string)($row["articulo"] ?? ($row["codigo"] ?? "")), 120);
        if ($articulo === "") {
            $articulo = "SIN-CODIGO";
        }

        $descripcion = normalize_text((string)($row["descripcion"] ?? ""), 4000);
        if ($descripcion === "") {
            $descripcion = "Sin descripcion";
        }

        $precioUnitarioSinIva = parse_decimal(
            $row["precio_unitario_sin_iva"] ?? ($row["precio_unitario"] ?? "0"),
            0.0
        );
        if ($precioUnitarioSinIva < 0.0) {
            $precioUnitarioSinIva = 0.0;
        }

        $precioTotalLinea = parse_decimal(
            $row["precio_total_linea_sin_iva"] ?? ($row["precio_total_sin_iva"] ?? "0"),
            0.0
        );
        if ($precioTotalLinea <= 0.0) {
            $precioTotalLinea = $cantidad * $precioUnitarioSinIva;
        }

        $ivaPct = parse_decimal($row["iva_pct"] ?? "21", 21.0);
        if ($ivaPct < 0.0) {
            $ivaPct = 0.0;
        }

        $precioTotalLineaConIva = parse_decimal(
            $row["precio_total_linea_con_iva"] ?? ($row["precio_total_con_iva"] ?? "0"),
            0.0
        );
        if ($precioTotalLineaConIva <= 0.0) {
            $precioTotalLineaConIva = $precioTotalLinea * (1.0 + ($ivaPct / 100.0));
        }

        $ivaFallback = filter_var($row["iva_fallback"] ?? false, FILTER_VALIDATE_BOOLEAN);

        $lineas[] = [
            "cantidad" => round($cantidad, 2),
            "articulo" => $articulo,
            "descripcion" => $descripcion,
            "precio_unitario_sin_iva" => round($precioUnitarioSinIva, 6),
            "precio_total_linea" => round($precioTotalLinea, 2),
            "iva_pct" => round($ivaPct, 3),
            "precio_total_linea_con_iva" => round($precioTotalLineaConIva, 2),
            "iva_fallback" => $ivaFallback
        ];
    }

    return $lineas;
}

function calculate_totals(array $lineas): array
{
    $sinIva = 0.0;
    $conIva = 0.0;
    foreach ($lineas as $linea) {
        $sinIva += (float)$linea["precio_total_linea"];
        $conIva += (float)$linea["precio_total_linea_con_iva"];
    }
    $sinIva = round($sinIva, 2);
    $conIva = round($conIva, 2);
    $iva = round($conIva - $sinIva, 2);

    return [
        "sin_iva" => $sinIva,
        "iva" => $iva,
        "con_iva" => $conIva
    ];
}

function resolve_images_root(): string
{
    $candidates = [];

    $envDir = getenv("CLM_IMAGES_DIR");
    if (is_string($envDir) && trim($envDir) !== "") {
        $candidates[] = trim($envDir);
    }

    $dirName = strtolower((string)basename(__DIR__));
    if ($dirName === "api") {
        $candidates[] = __DIR__ . "/../imagenes";
        $candidates[] = __DIR__ . "/imagenes";
    } else {
        $candidates[] = __DIR__ . "/imagenes";
        $candidates[] = __DIR__ . "/../imagenes";
    }
    $candidates[] = __DIR__ . "/../../imagenes";

    foreach ($candidates as $candidate) {
        $candidate = rtrim(str_replace("\\", "/", (string)$candidate), "/");
        if ($candidate === "") {
            continue;
        }
        if (is_dir($candidate)) {
            $real = realpath($candidate);
            return rtrim($real !== false ? $real : $candidate, "/");
        }
    }

    foreach ($candidates as $candidate) {
        $candidate = rtrim(str_replace("\\", "/", (string)$candidate), "/");
        if ($candidate === "") {
            continue;
        }
        $parent = dirname($candidate);
        if (is_dir($parent)) {
            return $candidate;
        }
    }

    return rtrim(str_replace("\\", "/", (string)(__DIR__ . "/imagenes")), "/");
}

function ensure_dir(string $dir): void
{
    if (is_dir($dir)) {
        return;
    }
    if (!mkdir($dir, 0775, true) && !is_dir($dir)) {
        throw new RuntimeException("No se pudo crear el directorio: " . $dir);
    }
}

function save_signature_image(string $firmaBase64, int $idPresupuesto): array
{
    $raw = $firmaBase64;
    if (strpos($raw, "base64,") !== false) {
        $parts = explode("base64,", $raw, 2);
        $raw = $parts[1];
    }
    $raw = str_replace(" ", "+", $raw);
    $raw = preg_replace('/\s+/', '', (string)$raw);

    $binary = base64_decode($raw, true);
    if ($binary === false || $binary === "") {
        throw new RuntimeException("La firma recibida no es valida");
    }

    $mime = "image/png";
    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $detected = $finfo->buffer($binary);
    if (is_string($detected) && $detected !== "") {
        $mime = strtolower($detected);
    }

    $ext = "png";
    $map = [
        "image/png" => "png",
        "image/jpeg" => "jpg",
        "image/jpg" => "jpg",
        "image/webp" => "webp"
    ];
    if (isset($map[$mime])) {
        $ext = $map[$mime];
    }

    $fileName = "Pedido-" . $idPresupuesto . "-" . date("YmdHis") . "." . $ext;
    $baseDir = resolve_images_root() . "/firmasConforme";
    ensure_dir($baseDir);

    $absolutePath = $baseDir . "/" . $fileName;
    if (file_put_contents($absolutePath, $binary) === false) {
        throw new RuntimeException("No se pudo guardar la firma del cliente");
    }

    return [
        "absolute_path" => $absolutePath,
        "relative_path" => "imagenes/firmasConforme/" . $fileName
    ];
}

function save_budget_pdf(
    int $idPresupuesto,
    string $numeroPedido,
    string $nombreCliente,
    string $direccionCliente,
    string $telefono,
    string $emailCliente,
    string $usuarioInstalador,
    string $equipoInstaladores,
    array $lineas,
    array $totals,
    string $firmaRelativePath
): array {
    $pdfLines = [];
    $pdfLines[] = pdf_line("ClimaMania Instal - Presupuesto de adicionales", 14, true);
    $pdfLines[] = pdf_line("Presupuesto ID: " . $idPresupuesto, 10, true);
    $pdfLines[] = pdf_line("Pedido: " . $numeroPedido);
    $pdfLines[] = pdf_line("Fecha: " . date("d/m/Y H:i"));
    $pdfLines[] = pdf_line("Instalador: " . ($usuarioInstalador !== "" ? $usuarioInstalador : "N/D"));
    $pdfLines[] = pdf_line("Equipo: " . ($equipoInstaladores !== "" ? $equipoInstaladores : "N/D"));
    $pdfLines[] = pdf_line("Cliente: " . $nombreCliente);
    $pdfLines[] = pdf_line("Direccion: " . $direccionCliente, 10, false, 95);
    $pdfLines[] = pdf_line("Telefono: " . ($telefono !== "" ? $telefono : "N/D"));
    $pdfLines[] = pdf_line("Email cliente: " . ($emailCliente !== "" ? $emailCliente : "N/D"));
    $pdfLines[] = pdf_line("");
    $pdfLines[] = pdf_line("Lineas", 11, true);

    $idx = 1;
    foreach ($lineas as $linea) {
        $lineaTitulo = $idx . ". " . format_decimal((float)$linea["cantidad"], 2)
            . " x " . $linea["articulo"]
            . " - " . $linea["descripcion"];
        $pdfLines[] = pdf_line($lineaTitulo, 10, false, 95);
        $pdfLines[] = pdf_line(
            "   Unit sin IVA: " . format_eur((float)$linea["precio_unitario_sin_iva"])
            . " | IVA: " . format_decimal((float)$linea["iva_pct"], 2) . "%"
            . " | Total linea: " . format_eur((float)$linea["precio_total_linea_con_iva"])
        );
        $idx++;
    }

    $pdfLines[] = pdf_line("");
    $pdfLines[] = pdf_line("Total sin IVA: " . format_eur((float)$totals["sin_iva"]), 11, true);
    $pdfLines[] = pdf_line("IVA: " . format_eur((float)$totals["iva"]), 11, true);
    $pdfLines[] = pdf_line("Total con IVA: " . format_eur((float)$totals["con_iva"]), 12, true);
    $pdfLines[] = pdf_line("");
    $pdfLines[] = pdf_line("Firma cliente: " . $firmaRelativePath, 9, false, 95);

    $pdfBinary = build_simple_pdf($pdfLines);
    $pdfFileName = "Pedido-" . $idPresupuesto . "-" . date("YmdHis") . ".pdf";
    $pdfDir = resolve_images_root() . "/presupuestosAdicionales";
    ensure_dir($pdfDir);

    $pdfAbsolutePath = $pdfDir . "/" . $pdfFileName;
    if (file_put_contents($pdfAbsolutePath, $pdfBinary) === false) {
        throw new RuntimeException("No se pudo generar el PDF del presupuesto");
    }

    return [
        "absolute_path" => $pdfAbsolutePath,
        "relative_path" => "imagenes/presupuestosAdicionales/" . $pdfFileName
    ];
}

function pdf_line(string $text, int $size = 10, bool $bold = false, int $wrap = 90): array
{
    return [
        "text" => $text,
        "size" => $size,
        "bold" => $bold,
        "wrap" => $wrap
    ];
}

function build_simple_pdf(array $rows): string
{
    $pageWidth = 595;
    $pageHeight = 842;
    $left = 42;
    $startY = 802;
    $lineHeight = 14;
    $bottom = 48;

    $pages = [];
    $currentContent = "";
    $y = $startY;

    foreach ($rows as $row) {
        $text = (string)($row["text"] ?? "");
        $size = (int)($row["size"] ?? 10);
        $bold = (bool)($row["bold"] ?? false);
        $wrap = (int)($row["wrap"] ?? 90);
        if ($wrap <= 0) {
            $wrap = 90;
        }

        $wrapped = wrap_text($text, $wrap);
        if (empty($wrapped)) {
            $wrapped = [""];
        }

        foreach ($wrapped as $chunk) {
            if ($y < $bottom) {
                $pages[] = $currentContent;
                $currentContent = "";
                $y = $startY;
            }

            $font = $bold ? "F2" : "F1";
            $escaped = pdf_escape_text($chunk);
            $currentContent .= "BT /" . $font . " " . $size . " Tf 1 0 0 1 "
                . $left . " " . $y . " Tm (" . $escaped . ") Tj ET\n";
            $y -= $lineHeight;
        }
    }

    $pages[] = $currentContent;
    $pageCount = count($pages);

    $objects = [];
    $objects[1] = "<< /Type /Catalog /Pages 2 0 R >>";

    $kids = [];
    for ($i = 0; $i < $pageCount; $i++) {
        $pageObj = 3 + ($i * 2);
        $kids[] = $pageObj . " 0 R";
    }
    $objects[2] = "<< /Type /Pages /Count " . $pageCount . " /Kids [" . implode(" ", $kids) . "] >>";

    $font1Obj = 3 + ($pageCount * 2);
    $font2Obj = $font1Obj + 1;

    for ($i = 0; $i < $pageCount; $i++) {
        $pageObj = 3 + ($i * 2);
        $contentObj = $pageObj + 1;
        $stream = $pages[$i];

        $objects[$pageObj] = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 "
            . $pageWidth . " " . $pageHeight . "] "
            . "/Resources << /Font << /F1 " . $font1Obj . " 0 R /F2 " . $font2Obj . " 0 R >> >> "
            . "/Contents " . $contentObj . " 0 R >>";

        $objects[$contentObj] = "<< /Length " . strlen($stream) . " >>\nstream\n"
            . $stream . "endstream";
    }

    $objects[$font1Obj] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>";
    $objects[$font2Obj] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>";

    $maxObj = $font2Obj;
    $pdf = "%PDF-1.4\n";
    $offsets = [];
    $offsets[0] = 0;

    for ($i = 1; $i <= $maxObj; $i++) {
        $offsets[$i] = strlen($pdf);
        $pdf .= $i . " 0 obj\n" . $objects[$i] . "\nendobj\n";
    }

    $xrefOffset = strlen($pdf);
    $pdf .= "xref\n0 " . ($maxObj + 1) . "\n";
    $pdf .= "0000000000 65535 f \n";
    for ($i = 1; $i <= $maxObj; $i++) {
        $pdf .= sprintf("%010d 00000 n \n", $offsets[$i]);
    }
    $pdf .= "trailer\n<< /Size " . ($maxObj + 1) . " /Root 1 0 R >>\n";
    $pdf .= "startxref\n" . $xrefOffset . "\n%%EOF";

    return $pdf;
}

function wrap_text(string $text, int $maxChars): array
{
    $text = trim($text);
    if ($text === "") {
        return [""];
    }

    $words = preg_split('/\s+/', $text);
    $lines = [];
    $current = "";

    foreach ($words as $word) {
        if ($current === "") {
            if (mb_strlen($word, "UTF-8") <= $maxChars) {
                $current = $word;
            } else {
                $chunks = split_multibyte_word($word, $maxChars);
                foreach ($chunks as $chunk) {
                    if ($chunk !== "") {
                        $lines[] = $chunk;
                    }
                }
                $current = "";
            }
            continue;
        }

        $candidate = $current . " " . $word;
        if (mb_strlen($candidate, "UTF-8") <= $maxChars) {
            $current = $candidate;
            continue;
        }

        $lines[] = $current;
        if (mb_strlen($word, "UTF-8") <= $maxChars) {
            $current = $word;
        } else {
            $chunks = split_multibyte_word($word, $maxChars);
            foreach ($chunks as $chunk) {
                if ($chunk !== "") {
                    $lines[] = $chunk;
                }
            }
            $current = "";
        }
    }

    if ($current !== "") {
        $lines[] = $current;
    }

    return $lines;
}

function pdf_escape_text(string $text): string
{
    $converted = iconv("UTF-8", "windows-1252//TRANSLIT//IGNORE", $text);
    if ($converted === false) {
        $converted = $text;
    }
    $converted = str_replace("\\", "\\\\", $converted);
    $converted = str_replace("(", "\\(", $converted);
    $converted = str_replace(")", "\\)", $converted);
    return $converted;
}

function split_multibyte_word(string $word, int $chunkLength): array
{
    $chunks = [];
    $len = mb_strlen($word, "UTF-8");
    if ($chunkLength <= 0) {
        $chunkLength = 1;
    }
    for ($i = 0; $i < $len; $i += $chunkLength) {
        $chunks[] = mb_substr($word, $i, $chunkLength, "UTF-8");
    }
    return $chunks;
}

function format_eur(float $amount): string
{
    return number_format($amount, 2, ",", ".") . " EUR";
}

function fetch_bcc_destinations(PDO $pdo): array
{
    $stmt = $pdo->query(
        "SELECT nombreVariable, valorVariable
         FROM variables_generales
         WHERE nombreVariable IN ('emailFacturacion', 'emailCompras')"
    );

    $emails = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $email = normalize_email((string)($row["valorVariable"] ?? ""));
        if ($email !== "") {
            $emails[$email] = true;
        }
    }
    return array_keys($emails);
}

function build_email_body(
    int $idPresupuesto,
    string $numeroPedido,
    string $nombreCliente,
    string $direccionCliente,
    array $totals
): string {
    return "Adjuntamos el presupuesto de adicionales generado por el instalador.\n\n"
        . "ID Presupuesto: " . $idPresupuesto . "\n"
        . "Pedido: " . $numeroPedido . "\n"
        . "Cliente: " . $nombreCliente . "\n"
        . "Direccion: " . $direccionCliente . "\n"
        . "Total sin IVA: " . format_eur((float)$totals["sin_iva"]) . "\n"
        . "IVA: " . format_eur((float)$totals["iva"]) . "\n"
        . "Total con IVA: " . format_eur((float)$totals["con_iva"]) . "\n\n"
        . "Este es un correo automatico. No responder.";
}

function send_mail_with_attachment(
    string $to,
    array $bcc,
    string $subject,
    string $body,
    string $attachmentPath,
    string $attachmentName
): bool {
    if (!filter_var($to, FILTER_VALIDATE_EMAIL)) {
        return false;
    }
    if (!is_file($attachmentPath)) {
        return false;
    }

    $boundary = "=_Part_" . md5(uniqid((string)mt_rand(), true));
    $headers = [];
    $headers[] = "From: ClimaMania Instalaciones <climamania@climamania.com>";
    $headers[] = "Reply-To: climamania@climamania.com";
    if (!empty($bcc)) {
        $bccClean = [];
        foreach ($bcc as $email) {
            $clean = normalize_email((string)$email);
            if ($clean !== "") {
                $bccClean[$clean] = true;
            }
        }
        if (!empty($bccClean)) {
            $headers[] = "Bcc: " . implode(",", array_keys($bccClean));
        }
    }
    $headers[] = "MIME-Version: 1.0";
    $headers[] = "Content-Type: multipart/mixed; boundary=\"" . $boundary . "\"";

    $attachmentData = file_get_contents($attachmentPath);
    if ($attachmentData === false) {
        return false;
    }
    $attachmentB64 = chunk_split(base64_encode($attachmentData));

    $message = "";
    $message .= "--" . $boundary . "\r\n";
    $message .= "Content-Type: text/plain; charset=UTF-8\r\n";
    $message .= "Content-Transfer-Encoding: 8bit\r\n\r\n";
    $message .= $body . "\r\n\r\n";

    $message .= "--" . $boundary . "\r\n";
    $message .= "Content-Type: application/pdf; name=\"" . $attachmentName . "\"\r\n";
    $message .= "Content-Transfer-Encoding: base64\r\n";
    $message .= "Content-Disposition: attachment; filename=\"" . $attachmentName . "\"\r\n\r\n";
    $message .= $attachmentB64 . "\r\n";
    $message .= "--" . $boundary . "--\r\n";

    return mail($to, $subject, $message, implode("\r\n", $headers));
}

function fetch_header_fallback_data(PDO $pdo, PDO $psPdo, string $psPrefix, string $referencia): array
{
    $result = [
        "nombre_cliente" => "",
        "direccion_cliente" => "",
        "telefono" => "",
        "email_cliente" => ""
    ];

    $result["email_cliente"] = presup_resolve_reference_customer_email($psPdo, $psPrefix, $referencia);

    try {
        $stmt = $pdo->prepare(
            "SELECT nombrecliente, direccion
             FROM ClimaInstal_events
             WHERE referencia = :ref
             ORDER BY start ASC
             LIMIT 1"
        );
        $stmt->execute([":ref" => $referencia]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($row) {
            $result["nombre_cliente"] = normalize_text((string)($row["nombrecliente"] ?? ""), 255);
            $result["direccion_cliente"] = normalize_text((string)($row["direccion"] ?? ""), 1000);
        }
    } catch (Exception $ignored) {
        // Sin datos en eventos: usar fallback de Prestashop.
    }

    try {
        $sql = "SELECT
                    ad.phone AS telefono,
                    ad.phone_mobile AS telefono_movil,
                    ad.firstname AS nombre,
                    ad.lastname AS apellidos,
                    ad.address1 AS dir1,
                    ad.address2 AS dir2,
                    ad.postcode AS cp,
                    ad.city AS ciudad
                FROM " . $psPrefix . "orders o
                LEFT JOIN " . $psPrefix . "address ad
                    ON o.id_address_delivery = ad.id_address
                WHERE o.reference = :ref
                ORDER BY o.id_order DESC
                LIMIT 1";
        $stmt = $psPdo->prepare($sql);
        $stmt->execute([":ref" => $referencia]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($row) {
            $telefono = normalize_text((string)($row["telefono"] ?? ""), 80);
            if ($telefono === "") {
                $telefono = normalize_text((string)($row["telefono_movil"] ?? ""), 80);
            }
            if ($telefono !== "") {
                $result["telefono"] = $telefono;
            }

            if ($result["nombre_cliente"] === "") {
                $nombre = trim(
                    normalize_text((string)($row["nombre"] ?? ""), 120)
                    . " "
                    . normalize_text((string)($row["apellidos"] ?? ""), 120)
                );
                $result["nombre_cliente"] = normalize_text($nombre, 255);
            }

            if ($result["direccion_cliente"] === "") {
                $direccion = trim(
                    normalize_text((string)($row["dir1"] ?? ""), 255) . " "
                    . normalize_text((string)($row["dir2"] ?? ""), 255)
                );
                $cp = normalize_text((string)($row["cp"] ?? ""), 30);
                $ciudad = normalize_text((string)($row["ciudad"] ?? ""), 120);
                $cola = trim($cp . " " . $ciudad);
                $full = trim($direccion . ($cola !== "" ? ", " . $cola : ""));
                $result["direccion_cliente"] = normalize_text($full, 1000);
            }
        }
    } catch (Exception $ignored) {
        // Sin datos de Prestashop: devolver lo encontrado en eventos.
    }

    return $result;
}

function resolve_ps_prefix(PDO $pdo, string $preferred): string
{
    $preferred = trim($preferred);
    if ($preferred !== "" && table_exists($pdo, $preferred . "orders")) {
        return $preferred;
    }

    $fallbacks = ["ps_", ""];
    foreach ($fallbacks as $prefix) {
        if ($prefix === $preferred) {
            continue;
        }
        if (table_exists($pdo, $prefix . "orders")) {
            return $prefix;
        }
    }

    return $preferred;
}

function table_exists(PDO $pdo, string $table): bool
{
    $stmt = $pdo->prepare("SHOW TABLES LIKE ?");
    $stmt->execute([$table]);
    return $stmt->fetchColumn() !== false;
}
