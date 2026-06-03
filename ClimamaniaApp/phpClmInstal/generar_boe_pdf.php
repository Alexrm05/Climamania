<?php

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);
ob_start();

require_once __DIR__ . "/presupuestos_api_common.php";
presup_register_fatal_json_handler("No se pudo generar el PDF BOE", 200);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/boe_pdf_api_common.php";
require_once __DIR__ . "/ubicaciones_eventos_common.php";

$API_KEY = "TEST123";
$PS_PREFIX = isset($PS_DB_PREFIX) && $PS_DB_PREFIX !== "" ? $PS_DB_PREFIX : "ps_";

presup_require_api_key($API_KEY);

$referencia = presup_normalize_text(presup_request_value("referencia"), 64);
$submissionToken = conformidad_normalize_token(presup_request_value("submission_token"));
$tipoFirmante = presup_normalize_text(presup_request_value("tipo_firmante"), 40);
$firmaBase64 = trim((string)presup_request_value("firma_base64_png"));
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

    $existingDocument = boe_find_document_by_token($pdo, $submissionToken);
    if ($existingDocument !== null) {
        $pdo->commit();
        presup_json_exit([
            "success" => true,
            "message" => "PDF BOE ya generado",
            "pdf" => $existingDocument["pdf"],
            "pdf_url" => $existingDocument["pdf_url"],
            "submission_token" => $submissionToken
        ]);
    }

    $contexto = conformidad_fetch_document_context($pdo, $psPdo, $psPrefix, $referencia);
    $equipos = boe_fetch_revision_rows($pdo, $psPdo, $psPrefix, $referencia);
    $templateSources = boe_fetch_user_template_sources($pdo, $usuario);
    $firmaEvento = clm_eventos_find_location_event_by_token($pdo, "FIRMA_CONFORMIDAD_CLIENTE", $submissionToken);
    if (!is_array($firmaEvento)) {
        throw new RuntimeException("No se pudo localizar la fecha de firma del conforme para generar el BOE");
    }

    if ($tipoFirmante === "cliente_titular") {
        $firmanteNombre = $contexto["cliente_nombre"];
        $firmanteApellidos = $contexto["cliente_apellidos"];
        $firmanteDni = $contexto["cliente_dni"];
    }

    $pdfBinary = boe_build_pdf(
        $contexto,
        $equipos,
        [
            "tipo" => $tipoFirmante,
            "nombre_completo" => trim($firmanteNombre . " " . $firmanteApellidos),
            "dni" => $firmanteDni
        ],
        $signatureBinary,
        [
            "fecha_hora" => (string)($firmaEvento["fecha_hora"] ?? "")
        ],
        $templateSources
    );

    $pdfData = boe_store_pdf($referencia, $submissionToken, $pdfBinary);
    $absolutePathToCleanup = $pdfData["absolute_path"];

    $insertedDocument = boe_register_document($pdo, $pdfData["absolute_path"], $submissionToken);
    if (!$insertedDocument) {
        if ($absolutePathToCleanup !== "" && is_file($absolutePathToCleanup)) {
            @unlink($absolutePathToCleanup);
        }
        $existingDocument = boe_find_document_by_token($pdo, $submissionToken);
        if ($existingDocument === null) {
            throw new RuntimeException("No se pudo resolver el documento BOE tras un reintento");
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
        "message" => "PDF BOE generado",
        "pdf" => $pdfData["relative_path"],
        "pdf_url" => $pdfData["pdf_url"],
        "equipos" => count($equipos),
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
