<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/incidencias_api_common.php";

$API_KEY = "TEST123";
visitas_require_api_key($API_KEY);

$rol = visitas_request("rol");
$usuario = visitas_request("usuario");
$equipoRaw = visitas_request("equipo");

try {
    $pdo = getDBConnection();
    $schema = incidencias_resolve_schema($pdo);
    if (empty($schema) || empty($schema["main_table"]) || empty($schema["id_col"])) {
        visitas_json_exit(["success" => true, "incidencias" => []]);
    }

    $sql = "SELECT
            " . incidencias_build_main_select($schema) . "
        FROM " . incidencias_ident($schema["main_table"]);

    $fechaSolicitudCol = $schema["fecha_solicitud_col"] ?? null;
    $estadoCol = $schema["estado_col"] ?? null;
    $sql .= " ORDER BY ";
    if ($estadoCol) {
        $sql .= "CASE WHEN TRIM(CAST(" . incidencias_ident($estadoCol) . " AS CHAR)) = '1' THEN 0 ELSE 1 END, ";
    }
    if ($fechaSolicitudCol) {
        $sql .= incidencias_ident($fechaSolicitudCol) . " DESC, ";
    }
    $sql .= incidencias_ident($schema["id_col"]) . " DESC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute();

    $incidencias = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        if (!incidencias_authorize_row($pdo, $schema, $row, $rol, $usuario, $equipoRaw)) {
            continue;
        }
        $row["prioridad_label"] = incidencias_prioridad_label($row["prioridad"] ?? "");
        $row["estado_label"] = trim((string)($row["estado"] ?? "")) === "1" ? "Pendiente" : "Realizada";
        $incidencias[] = $row;
    }

    visitas_json_exit([
        "success" => true,
        "incidencias" => $incidencias
    ]);
} catch (Exception $e) {
    visitas_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}
