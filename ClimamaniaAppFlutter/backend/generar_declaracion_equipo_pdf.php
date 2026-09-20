<?php
// Genera y registra la "Declaración del cliente sobre equipo desinstalado".
//
// Se llama desde la app cuando, en un pedido con equipo desinstalado, el
// instalador marca que el cliente NO permite retirar el equipo completo.
// Mismo flujo que generar_conforme_cliente_pdf.php: idempotente por
// submission_token, con evento de ubicación y PDF registrado en
// ClimaInstal_Fotografias (clave DECLEQ).

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once __DIR__ . "/presupuestos_api_common.php";
require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/conformidad_api_common.php";
require_once __DIR__ . "/declaracion_equipo_common.php";
require_once __DIR__ . "/ubicaciones_eventos_common.php";

$API_KEY = "TEST123";
$PS_PREFIX = isset($PS_DB_PREFIX) && $PS_DB_PREFIX !== "" ? $PS_DB_PREFIX : "ps_";

presup_require_api_key($API_KEY);

$referencia = presup_normalize_text(presup_request_value("referencia"), 64);
$submissionToken = conformidad_normalize_token(presup_request_value("submission_token"));
$firmaBase64 = trim((string)presup_request_value("firma_base64_png"));
$usuario = presup_normalize_text(presup_request_value("usuario"), 100);
$elementos = declaracion_equipo_parse_elementos(presup_request_value("elementos"));
$otrosDetalle = presup_normalize_text(presup_request_value("otros_detalle"), 500);
// Si vienen vacíos se usan los del titular del pedido.
$firmanteNombre = presup_normalize_text(presup_request_value("firmante_nombre"), 300);
$firmanteDni = presup_normalize_text(presup_request_value("firmante_dni"), 40);

if ($referencia === "") {
    presup_json_exit(["success" => false, "message" => "Referencia requerida"], 400);
}
if ($submissionToken === "") {
    presup_json_exit(["success" => false, "message" => "submission_token requerido"], 400);
}
if (empty($elementos)) {
    presup_json_exit(["success" => false, "message" => "Indica qué elementos conserva el cliente"], 400);
}
if (in_array("otros", $elementos, true) && $otrosDetalle === "") {
    presup_json_exit(["success" => false, "message" => "Especifica qué otros elementos conserva el cliente"], 400);
}

try {
    $signatureBinary = conformidad_decode_signature_base64($firmaBase64);
} catch (Throwable $e) {
    presup_json_exit(["success" => false, "message" => $e->getMessage()], 400);
}

$pdo = null;
$pdfData = null;
$absolutePathToCleanup = "";

try {
    $pdo = getDBConnection();
    $psPdo = getPSConnection();
    $psPrefix = presup_resolve_ps_prefix($psPdo, $PS_PREFIX);

    $pdo->beginTransaction();

    $existingDocument = conformidad_find_document_by_token($pdo, $submissionToken, DECLEQ_CLAVE);
    if ($existingDocument !== null) {
        $existingEvent = clm_eventos_find_location_event_by_token($pdo, DECLEQ_TIPO_EVENTO, $submissionToken);
        $pdo->commit();
        presup_json_exit([
            "success" => true,
            "message" => "Declaración ya generada",
            "pdf" => $existingDocument["pdf"],
            "pdf_url" => $existingDocument["pdf_url"],
            "tipo_evento" => DECLEQ_TIPO_EVENTO,
            "fecha_hora_firma" => is_array($existingEvent) ? ($existingEvent["fecha_hora"] ?? "") : "",
            "latitud" => is_array($existingEvent) ? ($existingEvent["latitud"] ?? "") : "",
            "longitud" => is_array($existingEvent) ? ($existingEvent["longitud"] ?? "") : "",
            "submission_token" => $submissionToken
        ]);
    }

    $contexto = conformidad_fetch_document_context($pdo, $psPdo, $psPrefix, $referencia);

    if ($firmanteNombre === "") {
        $firmanteNombre = trim($contexto["cliente_nombre"] . " " . $contexto["cliente_apellidos"]);
    }
    if ($firmanteDni === "") {
        $firmanteDni = (string)$contexto["cliente_dni"];
    }

    $existingEvent = clm_eventos_find_location_event_by_token($pdo, DECLEQ_TIPO_EVENTO, $submissionToken);
    if ($existingEvent === null) {
        clm_eventos_insert_location_event($pdo, [
            "referencia" => $referencia,
            "numero_pedido" => $referencia,
            "tipo_evento" => DECLEQ_TIPO_EVENTO,
            "token_evento" => $submissionToken,
            "latitud" => presup_request_value("latitud"),
            "longitud" => presup_request_value("longitud"),
            "usuario" => $usuario,
            "origen" => "APP"
        ]);
        $existingEvent = clm_eventos_find_location_event_by_token($pdo, DECLEQ_TIPO_EVENTO, $submissionToken);
    }
    if (!is_array($existingEvent)) {
        throw new RuntimeException("No se pudo registrar la trazabilidad de la firma de la declaración");
    }

    $pdfBinary = declaracion_equipo_build_pdf(
        $contexto,
        $elementos,
        $otrosDetalle,
        ["nombre_completo" => $firmanteNombre, "dni" => $firmanteDni],
        $signatureBinary,
        $existingEvent
    );

    $pdfData = conformidad_store_pdf($referencia, $submissionToken, $pdfBinary, DECLEQ_SUBDIR, DECLEQ_CLAVE);
    $absolutePathToCleanup = $pdfData["absolute_path"];

    $inserted = conformidad_register_document($pdo, $pdfData["absolute_path"], $submissionToken, DECLEQ_CLAVE);
    if (!$inserted) {
        // Reintento concurrente: ya hay documento para este token, usar ese.
        if ($absolutePathToCleanup !== "" && is_file($absolutePathToCleanup)) {
            @unlink($absolutePathToCleanup);
        }
        $existingDocument = conformidad_find_document_by_token($pdo, $submissionToken, DECLEQ_CLAVE);
        if ($existingDocument === null) {
            throw new RuntimeException("No se pudo resolver la declaración tras un reintento");
        }
        $pdfData = [
            "relative_path" => $existingDocument["pdf"],
            "pdf_url" => $existingDocument["pdf_url"],
            "absolute_path" => $existingDocument["absolute_path"]
        ];
        $absolutePathToCleanup = "";
    }

    $pdo->commit();

    presup_json_exit([
        "success" => true,
        "message" => "Declaración generada",
        "pdf" => $pdfData["relative_path"],
        "pdf_url" => $pdfData["pdf_url"],
        "tipo_evento" => DECLEQ_TIPO_EVENTO,
        "fecha_hora_firma" => $existingEvent["fecha_hora"] ?? "",
        "latitud" => $existingEvent["latitud"] ?? "",
        "longitud" => $existingEvent["longitud"] ?? "",
        "elementos" => $elementos,
        "submission_token" => $submissionToken
    ]);
} catch (Throwable $e) {
    if ($pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    if ($absolutePathToCleanup !== "" && is_file($absolutePathToCleanup)) {
        @unlink($absolutePathToCleanup);
    }
    presup_json_exit(["success" => false, "message" => $e->getMessage()], 200);
}
