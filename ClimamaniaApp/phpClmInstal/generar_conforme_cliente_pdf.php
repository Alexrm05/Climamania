<?php

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);
ob_start();

require_once __DIR__ . "/presupuestos_api_common.php";
presup_register_fatal_json_handler("No se pudo generar el PDF de conformidad", 200);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/conformidad_api_common.php";
require_once __DIR__ . "/ubicaciones_eventos_common.php";

$API_KEY = "TEST123";
$PS_PREFIX = isset($PS_DB_PREFIX) && $PS_DB_PREFIX !== "" ? $PS_DB_PREFIX : "ps_";

presup_require_api_key($API_KEY);

$referencia = presup_normalize_text(presup_request_value("referencia"), 64);
$submissionToken = conformidad_normalize_token(presup_request_value("submission_token"));
$tipoFirmante = presup_normalize_text(presup_request_value("tipo_firmante"), 40);
$firmaBase64 = trim((string)presup_request_value("firma_base64_png"));
$observaciones = presup_normalize_text(presup_request_value("observaciones_conformidad"), 4000);
$requiereBoe = filter_var(presup_request_value("requiere_boe"), FILTER_VALIDATE_BOOLEAN);
$revisionBoeGuardada = filter_var(presup_request_value("revision_boe_guardada"), FILTER_VALIDATE_BOOLEAN);
$usuario = presup_normalize_text(presup_request_value("usuario"), 100);

if ($referencia === "") {
    presup_json_exit(["success" => false, "message" => "Referencia requerida"], 400);
}
if ($submissionToken === "") {
    presup_json_exit(["success" => false, "message" => "submission_token requerido"], 400);
}
if ($tipoFirmante !== "cliente_titular" && $tipoFirmante !== "representante_autorizado") {
    presup_json_exit(["success" => false, "message" => "Tipo de firmante inválido"], 400);
}

$firmanteNombre = presup_normalize_text(presup_request_value("firmante_nombre"), 120);
$firmanteApellidos = presup_normalize_text(presup_request_value("firmante_apellidos"), 180);
$firmanteDni = presup_normalize_text(presup_request_value("firmante_dni"), 40);

if ($tipoFirmante === "representante_autorizado") {
    if ($firmanteNombre === "" || $firmanteApellidos === "" || $firmanteDni === "") {
        presup_json_exit([
            "success" => false,
            "message" => "Debes completar nombre, apellidos y DNI del representante"
        ], 400);
    }
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

    $existingDocument = conformidad_find_document_by_token($pdo, $submissionToken);
    if ($existingDocument !== null) {
        $existingEvent = clm_eventos_find_location_event_by_token(
            $pdo,
            "FIRMA_CONFORMIDAD_CLIENTE",
            $submissionToken
        );
        $pdo->commit();
        presup_json_exit([
            "success" => true,
            "message" => "PDF de conformidad ya generado",
            "pdf" => $existingDocument["pdf"],
            "pdf_url" => $existingDocument["pdf_url"],
            "tipo_evento" => "FIRMA_CONFORMIDAD_CLIENTE",
            "fecha_hora_firma" => is_array($existingEvent) ? ($existingEvent["fecha_hora"] ?? "") : "",
            "latitud" => is_array($existingEvent) ? ($existingEvent["latitud"] ?? "") : "",
            "longitud" => is_array($existingEvent) ? ($existingEvent["longitud"] ?? "") : "",
            "submission_token" => $submissionToken
        ]);
    }

    $contexto = conformidad_fetch_document_context($pdo, $psPdo, $psPrefix, $referencia);

    if ($tipoFirmante === "cliente_titular") {
        $firmanteNombre = $contexto["cliente_nombre"];
        $firmanteApellidos = $contexto["cliente_apellidos"];
        $firmanteDni = $contexto["cliente_dni"];
    }

    $existingEvent = clm_eventos_find_location_event_by_token(
        $pdo,
        "FIRMA_CONFORMIDAD_CLIENTE",
        $submissionToken
    );
    if ($existingEvent === null) {
        clm_eventos_insert_location_event($pdo, [
            "referencia" => $referencia,
            "numero_pedido" => $referencia,
            "tipo_evento" => "FIRMA_CONFORMIDAD_CLIENTE",
            "token_evento" => $submissionToken,
            "latitud" => presup_request_value("latitud"),
            "longitud" => presup_request_value("longitud"),
            "usuario" => $usuario,
            "origen" => "APP_ANDROID"
        ]);
        $existingEvent = clm_eventos_find_location_event_by_token(
            $pdo,
            "FIRMA_CONFORMIDAD_CLIENTE",
            $submissionToken
        );
    }

    if (!is_array($existingEvent)) {
        throw new RuntimeException("No se pudo registrar la trazabilidad de la firma del conforme");
    }

    $pdfBinary = conformidad_build_pdf(
        $contexto,
        $observaciones,
        [
            "tipo" => $tipoFirmante,
            "nombre_completo" => trim($firmanteNombre . " " . $firmanteApellidos),
            "dni" => $firmanteDni
        ],
        $signatureBinary,
        $existingEvent
    );

    $pdfData = conformidad_store_pdf($referencia, $submissionToken, $pdfBinary);
    $absolutePathToCleanup = $pdfData["absolute_path"];

    $insertedDocument = conformidad_register_document($pdo, $pdfData["absolute_path"], $submissionToken);
    if (!$insertedDocument) {
        if ($absolutePathToCleanup !== "" && is_file($absolutePathToCleanup)) {
            @unlink($absolutePathToCleanup);
        }
        $existingDocument = conformidad_find_document_by_token($pdo, $submissionToken);
        if ($existingDocument === null) {
            throw new RuntimeException("No se pudo resolver el documento de conformidad tras un reintento");
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
        "message" => "PDF de conformidad generado",
        "pdf" => $pdfData["relative_path"],
        "pdf_url" => $pdfData["pdf_url"],
        "tipo_evento" => "FIRMA_CONFORMIDAD_CLIENTE",
        "fecha_hora_firma" => $existingEvent["fecha_hora"] ?? "",
        "latitud" => $existingEvent["latitud"] ?? "",
        "longitud" => $existingEvent["longitud"] ?? "",
        "requires_boe" => $requiereBoe,
        "revision_boe_guardada" => $revisionBoeGuardada,
        "submission_token" => $submissionToken
    ]);
} catch (Throwable $e) {
    if ($pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    if ($absolutePathToCleanup !== "" && is_file($absolutePathToCleanup)) {
        @unlink($absolutePathToCleanup);
    }
    presup_json_exit([
        "success" => false,
        "message" => $e->getMessage()
    ], 200);
}
