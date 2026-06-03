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
$mensaje = visitas_normalize_text(visitas_request("mensaje"), 5000);

if ($mensaje === "") {
    visitas_json_exit(["success" => false, "message" => "Debes escribir un comentario"], 400);
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

    visitas_insert_muro($pdo, $idVisita, $mensaje, $autor, $rol, "APP_ANDROID");

    visitas_json_exit([
        "success" => true,
        "message" => "Comentario enviado al muro"
    ]);
} catch (Exception $e) {
    visitas_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}
