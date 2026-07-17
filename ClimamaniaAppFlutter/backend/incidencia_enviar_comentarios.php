<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
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
$mensaje = visitas_normalize_text(visitas_request("mensaje"), 5000);

if ($mensaje === "") {
    visitas_json_exit(["success" => false, "message" => "Debes escribir un comentario"], 400);
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

    $ok = incidencias_insert_muro($pdo, $schema, $idIncidencia, $mensaje, $autor, $rol, "APP_ANDROID");
    if (!$ok) {
        visitas_json_exit(["success" => false, "message" => "No se pudo guardar en el muro"], 500);
    }

    visitas_json_exit(["success" => true, "message" => "Comentario enviado al muro"]);
} catch (Exception $e) {
    visitas_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}
