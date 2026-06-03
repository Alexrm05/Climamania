<?php

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";
require_once "incidencias_api_common.php";

$API_KEY = "TEST123";
visitas_require_api_key($API_KEY);

$idIncidencia = (int)visitas_request("id_incidencia");
if ($idIncidencia <= 0) {
    $idIncidencia = (int)visitas_request("id_visita");
}
if ($idIncidencia <= 0) {
    visitas_json_exit(["success" => false, "message" => "id_incidencia requerido"], 400);
}

$rol = visitas_request("rol");
$usuario = visitas_request("usuario");
$equipo = visitas_request("equipo");
$autor = visitas_request("autor");
$accion = strtolower(visitas_request("accion"));
$motivo = visitas_normalize_text(visitas_request("motivo"), 5000);
$resumenActuacion = visitas_normalize_text(visitas_request("resumen_actuacion"), 5000);

if ($accion !== "finalizar" && $accion !== "cancelar") {
    visitas_json_exit(["success" => false, "message" => "Accion no valida"], 400);
}
if ($accion === "cancelar" && $motivo === "") {
    visitas_json_exit(["success" => false, "message" => "Debes indicar el motivo de cancelacion"], 400);
}
if ($accion === "finalizar" && $resumenActuacion === "") {
    visitas_json_exit(["success" => false, "message" => "Debes indicar el motivo/resumen de la actuacion"], 400);
}
if ($autor === "") {
    $autor = $usuario !== "" ? $usuario : "Instalador";
}

try {
    $pdo = getDBConnection();
    $schema = incidencias_resolve_schema($pdo);
    $incidencia = incidencias_fetch_by_id($pdo, $schema, $idIncidencia);

    if (!$incidencia) {
        visitas_json_exit(["success" => false, "message" => "Incidencia no encontrada"], 404);
    }

    if (!incidencias_authorize_row($pdo, $schema, $incidencia, $rol, $usuario, $equipo)) {
        visitas_json_exit(["success" => false, "message" => "Sin permiso para esta incidencia"], 403);
    }

    $estadoFinalizada = 3;
    $estadoCancelada = 6;
    $newEstado = $accion === "cancelar" ? $estadoCancelada : $estadoFinalizada;

    $pdo->beginTransaction();

    if (!incidencias_update_estado_resolucion($pdo, $schema, $idIncidencia, $newEstado)) {
        throw new Exception("No se pudo actualizar el estado");
    }

    if ($accion === "cancelar") {
        $mensajeMuro = "Incidencia cancelada. Motivo: " . $motivo;
    } else {
        $mensajeMuro = "Incidencia finalizada. Resumen: " . $resumenActuacion;
    }
    incidencias_insert_muro($pdo, $schema, $idIncidencia, $mensajeMuro, $autor, $rol, "APP_ANDROID");

    $pdo->commit();

    $asunto = $accion === "cancelar"
        ? "Incidencia cancelada #" . $idIncidencia
        : "Incidencia finalizada #" . $idIncidencia;

    $cliente = visitas_normalize_text((string)($incidencia["cliente"] ?? ""), 255);
    $direccion = visitas_normalize_text((string)($incidencia["direccion"] ?? ""), 500);
    $poblacion = visitas_normalize_text((string)($incidencia["poblacion"] ?? ""), 150);
    $accionTexto = $accion === "cancelar" ? "CANCELADA" : "FINALIZADA";
    $usuarioTexto = $usuario !== "" ? $usuario : $autor;

    $body = "Se ha actualizado una incidencia desde la app Android.\n\n"
        . "Incidencia ID: " . $idIncidencia . "\n"
        . "Estado: " . $accionTexto . "\n"
        . "Usuario: " . $usuarioTexto . "\n"
        . "Cliente: " . ($cliente !== "" ? $cliente : "N/D") . "\n"
        . "Direccion: " . trim($direccion . " " . $poblacion) . "\n"
        . "Fecha: " . date("d/m/Y H:i:s") . "\n";

    if ($accion === "cancelar") {
        $body .= "Motivo cancelacion: " . $motivo . "\n";
    } else {
        $body .= "Resumen actuacion: " . $resumenActuacion . "\n";
    }

    $body .= "\nEste es un email automatico. No responder.";

    $destinatarios = visitas_collect_variable_emails($pdo, ["emailGenerico"]);
    $mailOk = visitas_send_mail_plain($destinatarios, $asunto, $body);

    visitas_json_exit([
        "success" => true,
        "message" => $accion === "cancelar"
            ? "Incidencia cancelada correctamente"
            : "Incidencia finalizada correctamente",
        "estado" => $newEstado,
        "mail_enviado" => $mailOk,
        "mail_destinatarios" => $destinatarios
    ]);
} catch (Exception $e) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    visitas_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}
