<?php

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";
require_once "visitas_api_common.php";

$API_KEY = "TEST123";
visitas_require_api_key($API_KEY);

$idVisita = (int)visitas_request("id_visita");
if ($idVisita <= 0) {
    visitas_json_exit(["success" => false, "message" => "id_visita requerido"], 400);
}

$rol = visitas_request("rol");
$usuario = visitas_request("usuario");
$equipo = visitas_request("equipo");
$autor = visitas_request("autor");
$accion = strtolower(visitas_request("accion"));
$motivo = visitas_normalize_text(visitas_request("motivo"), 5000);

if ($accion !== "finalizar" && $accion !== "cancelar") {
    visitas_json_exit(["success" => false, "message" => "Accion no valida"], 400);
}

if ($accion === "cancelar" && $motivo === "") {
    visitas_json_exit(["success" => false, "message" => "Debes indicar el motivo de cancelacion"], 400);
}

if ($autor === "") {
    $autor = $usuario;
}
if ($autor === "") {
    $autor = "Instalador";
}

try {
    $pdo = getDBConnection();
    $visita = visitas_get_visita($pdo, $idVisita);
    if (!$visita) {
        visitas_json_exit(["success" => false, "message" => "Visita no encontrada"], 404);
    }

    if (!visitas_authorize_visita($pdo, $visita, $rol, $usuario, $equipo)) {
        visitas_json_exit(["success" => false, "message" => "Sin permiso para esta visita"], 403);
    }

    $estadoFinalizada = 7;
    $estadoCancelada = 6;
    $newEstado = $accion === "cancelar" ? $estadoCancelada : $estadoFinalizada;

    $pdo->beginTransaction();

    $stmt = $pdo->prepare(
        "UPDATE ClimaInstal_Visitas
         SET estado = :estado,
             fecha_resolucion = NOW()
         WHERE id_visita = :id
         LIMIT 1"
    );
    $stmt->execute([
        ":estado" => $newEstado,
        ":id" => $idVisita
    ]);

    if ($accion === "cancelar") {
        $mensajeMuro = "Visita cancelada. Motivo: " . $motivo;
    } else {
        $mensajeMuro = "Visita finalizada.";
    }
    visitas_insert_muro($pdo, $idVisita, $mensajeMuro, $autor, $rol, "APP_ANDROID");

    $pdo->commit();

    $asunto = $accion === "cancelar"
        ? "Visita cancelada #" . $idVisita
        : "Visita finalizada #" . $idVisita;

    $cliente = visitas_normalize_text((string)($visita["cliente"] ?? ""), 255);
    $direccion = visitas_normalize_text((string)($visita["direccion"] ?? ""), 500);
    $poblacion = visitas_normalize_text((string)($visita["poblacion"] ?? ""), 150);
    $accionTexto = $accion === "cancelar" ? "CANCELADA" : "FINALIZADA";
    $usuarioTexto = $usuario !== "" ? $usuario : $autor;

    $body = "Se ha actualizado una visita desde la app Android.\n\n"
        . "Visita ID: " . $idVisita . "\n"
        . "Estado: " . $accionTexto . "\n"
        . "Usuario: " . $usuarioTexto . "\n"
        . "Cliente: " . ($cliente !== "" ? $cliente : "N/D") . "\n"
        . "Direccion: " . trim($direccion . " " . $poblacion) . "\n"
        . "Fecha: " . date("d/m/Y H:i:s") . "\n";

    if ($accion === "cancelar") {
        $body .= "Motivo cancelacion: " . $motivo . "\n";
    }

    $body .= "\nEste es un email automatico. No responder.";

    $destinatarios = visitas_collect_variable_emails($pdo, ["emailGenerico"]);
    $mailOk = visitas_send_mail_plain($destinatarios, $asunto, $body);

    visitas_json_exit([
        "success" => true,
        "message" => $accion === "cancelar"
            ? "Visita cancelada correctamente"
            : "Visita finalizada correctamente",
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
