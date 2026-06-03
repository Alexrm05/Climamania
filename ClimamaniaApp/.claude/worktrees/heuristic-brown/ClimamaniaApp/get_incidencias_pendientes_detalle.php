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
    if (empty($schema) || empty($schema["main_table"]) || empty($schema["id_col"])) {
        visitas_json_exit(["success" => true, "incidencias" => []]);
    }

    $wherePendientes = incidencias_pending_where($schema);
    $prioridadOrderExpr = incidencias_prioridad_order_expr($schema);
    $fechaSolicitudCol = $schema["fecha_solicitud_col"] ?? null;

    $sql = "SELECT\n            " . incidencias_build_main_select($schema) . ",\n"
        . "            " . $prioridadOrderExpr . " AS prioridad_orden\n"
        . "        FROM " . incidencias_ident($schema["main_table"]) . "\n"
        . "        WHERE " . $wherePendientes;

    $params = [];
    if (!visitas_is_admin_role($rol)) {
        $scope = incidencias_build_scope_clause($pdo, $schema, $equipoRaw, $usuario, $params);
        if ($scope === "") {
            visitas_json_exit(["success" => true, "incidencias" => []]);
        }
        $sql .= " AND (" . $scope . ")";
    }

    $sql .= " ORDER BY prioridad_orden ASC";
    if ($fechaSolicitudCol) {
        $sql .= ", " . incidencias_ident($fechaSolicitudCol) . " ASC";
    }
    $sql .= ", " . incidencias_ident($schema["id_col"]) . " ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $incidencias = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($incidencias as &$inc) {
        $inc["prioridad_label"] = incidencias_prioridad_label($inc["prioridad"] ?? "");
        unset($inc["prioridad_orden"]);
    }
    unset($inc);

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
