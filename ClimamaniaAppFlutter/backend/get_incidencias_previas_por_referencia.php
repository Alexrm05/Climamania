<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/incidencias_api_common.php";

$API_KEY = "TEST123";
visitas_require_api_key($API_KEY);

$referencia = trim((string)visitas_request("referencia"));
if ($referencia === "") {
    visitas_json_exit(["success" => false, "message" => "referencia requerida"], 400);
}

$rol = visitas_request("rol");
$usuario = visitas_request("usuario");
$equipoRaw = visitas_request("equipo");

try {
    $pdo = getDBConnection();
    $schema = incidencias_resolve_schema($pdo);
    $mainTable = $schema["main_table"] ?? "";
    $idCol = $schema["id_col"] ?? "";
    $referenciaCol = $schema["referencia_col"] ?? "";

    if ($mainTable === "" || $idCol === "" || $referenciaCol === "") {
        visitas_json_exit(["success" => true, "incidencias" => []]);
    }

    $sql = "SELECT
            " . incidencias_build_main_select($schema) . "
        FROM " . incidencias_ident($mainTable) . "
        WHERE TRIM(CAST(" . incidencias_ident($referenciaCol) . " AS CHAR)) = :referencia";

    $fechaSolicitudCol = $schema["fecha_solicitud_col"] ?? null;
    $sql .= " ORDER BY ";
    if ($fechaSolicitudCol) {
        $sql .= incidencias_ident($fechaSolicitudCol) . " DESC, ";
    }
    $sql .= incidencias_ident($idCol) . " DESC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([":referencia" => $referencia]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $incidencias = [];
    foreach ($rows as $row) {
        if (!incidencias_authorize_row($pdo, $schema, $row, $rol, $usuario, $equipoRaw)) {
            continue;
        }
        $row["prioridad_label"] = incidencias_prioridad_label($row["prioridad"] ?? "");
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
