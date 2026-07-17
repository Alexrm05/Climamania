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
    // Compatibilidad por si llega el mismo nombre que visitas.
    $idIncidencia = (int)visitas_request("id_visita");
}
if ($idIncidencia <= 0) {
    visitas_json_exit(["success" => false, "message" => "id_incidencia requerido"], 400);
}

$rol = visitas_request("rol");
$usuario = visitas_request("usuario");
$equipoRaw = visitas_request("equipo");
$referenciaFromClient = visitas_request("referencia");

try {
    $pdo = getDBConnection();
    $schema = incidencias_resolve_schema($pdo);
    if (empty($schema) || empty($schema["main_table"])) {
        visitas_json_exit(["success" => false, "message" => "Tabla de incidencias no disponible"], 404);
    }

    $incidencia = incidencias_fetch_by_id($pdo, $schema, $idIncidencia);
    if (!$incidencia) {
        visitas_json_exit(["success" => false, "message" => "Incidencia no encontrada"], 404);
    }

    if (!incidencias_authorize_row($pdo, $schema, $incidencia, $rol, $usuario, $equipoRaw)) {
        visitas_json_exit(["success" => false, "message" => "Sin permiso para esta incidencia"], 403);
    }

    $muro = incidencias_fetch_muro($pdo, $schema, $idIncidencia);
    $ficherosIncidencia = incidencias_fetch_ficheros($pdo, $schema, $idIncidencia);

    $referencia = trim((string)($incidencia["referencia"] ?? ""));
    if ($referencia === "") {
        $referencia = trim($referenciaFromClient);
    }

    $fotosInstalacion = incidencias_fetch_instalacion_fotos($pdo, $referencia, $idIncidencia);

    $ficheros = array_merge($ficherosIncidencia, $fotosInstalacion);

    $incidencia["prioridad_label"] = incidencias_prioridad_label($incidencia["prioridad"] ?? "");

    visitas_json_exit([
        "success" => true,
        "incidencia" => $incidencia,
        "muro" => $muro,
        "ficheros" => $ficheros
    ]);
} catch (Exception $e) {
    visitas_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}
