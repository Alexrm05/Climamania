<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/documentos_mail_common.php";

$API_KEY = "TEST123";
$PS_PREFIX = isset($PS_DB_PREFIX) && $PS_DB_PREFIX !== "" ? $PS_DB_PREFIX : "ps_";

presup_require_api_key($API_KEY);

$referencia = presup_normalize_text(presup_request_value("referencia"), 64);
$submissionToken = conformidad_normalize_token(presup_request_value("submission_token"));
$requiereBoe = filter_var(presup_request_value("requiere_boe"), FILTER_VALIDATE_BOOLEAN);

if ($referencia === "") {
    presup_json_exit(["success" => false, "message" => "Referencia requerida"], 400);
}
if ($submissionToken === "") {
    presup_json_exit(["success" => false, "message" => "submission_token requerido"], 400);
}

try {
    $pdo = getDBConnection();
    $psPdo = getPSConnection();
    $psPrefix = presup_resolve_ps_prefix($psPdo, $PS_PREFIX);

    $emailCliente = presup_resolve_reference_customer_email($psPdo, $psPrefix, $referencia);
    if ($emailCliente === "") {
        presup_json_exit(["success" => false, "message" => "Esta referencia no tiene un email de cliente válido"], 400);
    }

    $destinatariosInternos = documentos_fetch_internal_destinations($pdo);
    $contexto = conformidad_fetch_document_context($pdo, $psPdo, $psPrefix, $referencia);

    $conforme = conformidad_find_document_by_token($pdo, $submissionToken);
    if ($conforme === null || empty($conforme["absolute_path"]) || !is_file((string)$conforme["absolute_path"])) {
        presup_json_exit(["success" => false, "message" => "Falta el documento de conformidad firmado"], 400);
    }

    $attachments = [[
        "path" => (string)$conforme["absolute_path"],
        "name" => basename((string)$conforme["pdf"])
    ]];

    if ($requiereBoe) {
        $boe = boe_find_document_by_token($pdo, $submissionToken);
        if ($boe === null || empty($boe["absolute_path"]) || !is_file((string)$boe["absolute_path"])) {
            presup_json_exit(["success" => false, "message" => "Falta el documento BOE obligatorio para esta instalación"], 400);
        }
        $attachments[] = [
            "path" => (string)$boe["absolute_path"],
            "name" => basename((string)$boe["pdf"])
        ];
    }

    $subject = "Documentación de instalación " . $referencia;
    $body = documentos_build_installation_email_body(
        $referencia,
        trim((string)$contexto["cliente_nombre"] . " " . (string)$contexto["cliente_apellidos"]),
        $requiereBoe
    );

    $mailError = "";
    $mailSent = documentos_send_mail_with_attachments(
        $emailCliente,
        $destinatariosInternos,
        $subject,
        $body,
        $attachments,
        $mailError
    );

    if (!$mailSent) {
        presup_json_exit([
            "success" => false,
            "message" => $mailError !== "" ? $mailError : "No se pudo enviar la documentación por email"
        ], 500);
    }

    presup_json_exit([
        "success" => true,
        "message" => $requiereBoe
            ? "Conforme y BOE enviados por email"
            : "Conforme enviado por email",
        "destinatario_cliente" => $emailCliente,
        "destinatarios_internos" => $destinatariosInternos,
        "requiere_boe" => $requiereBoe
    ]);
} catch (Throwable $e) {
    presup_json_exit([
        "success" => false,
        "message" => $e->getMessage()
    ], 500);
}
