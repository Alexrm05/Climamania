<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
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
$prioridadRaw = visitas_request("prioridad");
$prioridadNew = visitas_normalize_prioridad_to_int($prioridadRaw);

if ($prioridadNew <= 0) {
    visitas_json_exit(["success" => false, "message" => "Prioridad no valida"], 400);
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

    $prioridadOld = visitas_normalize_prioridad_to_int((string)($visita["prioridad"] ?? ""));
    if ($prioridadOld <= 0) {
        $prioridadOld = 1;
    }

    if ($prioridadOld !== $prioridadNew) {
        $stmt = $pdo->prepare(
            "UPDATE ClimaInstal_Visitas
             SET prioridad = :prioridad
             WHERE id_visita = :id
             LIMIT 1"
        );
        $stmt->execute([
            ":prioridad" => $prioridadNew,
            ":id" => $idVisita
        ]);

        $mensaje = "Prioridad actualizada de "
            . visitas_prioridad_label_from_int($prioridadOld)
            . " a "
            . visitas_prioridad_label_from_int($prioridadNew)
            . ".";
        visitas_insert_muro($pdo, $idVisita, $mensaje, $autor, $rol, "APP_ANDROID");
    }

    visitas_json_exit([
        "success" => true,
        "message" => "Prioridad actualizada",
        "prioridad" => $prioridadNew,
        "prioridad_label" => visitas_prioridad_label_from_int($prioridadNew)
    ]);
} catch (Exception $e) {
    visitas_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}
