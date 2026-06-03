<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";
require_once "incidencias_api_common.php";

$API_KEY = "TEST123";
visitas_require_api_key($API_KEY);

$rol = visitas_request("rol");
$usuario = visitas_request("usuario");
$equipoRaw = visitas_request("equipo");

try {
    $pdo = getDBConnection();
    $schema = incidencias_resolve_schema($pdo);
    if (empty($schema) || empty($schema["main_table"])) {
        visitas_json_exit(["success" => true, "pendientes" => 0]);
    }

    $wherePendientes = incidencias_pending_where($schema);
    $sql = "SELECT COUNT(*) AS total\n"
        . "FROM " . incidencias_ident($schema["main_table"]) . "\n"
        . "WHERE " . $wherePendientes;
    $params = [];

    if (!visitas_is_admin_role($rol)) {
        $scope = incidencias_build_scope_clause($pdo, $schema, $equipoRaw, $usuario, $params);
        if ($scope === "") {
            visitas_json_exit(["success" => true, "pendientes" => 0]);
        }
        $sql .= " AND (" . $scope . ")";
    }

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $total = (int)($stmt->fetchColumn() ?? 0);

    visitas_json_exit([
        "success" => true,
        "pendientes" => $total
    ]);
} catch (Exception $e) {
    visitas_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}
