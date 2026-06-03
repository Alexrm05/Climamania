<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/visitas_api_common.php";

$API_KEY = "TEST123";
visitas_require_api_key($API_KEY);

$rol = visitas_request("rol");
$usuario = visitas_request("usuario");
$equipoRaw = visitas_request("equipo");

try {
    $pdo = getDBConnection();

    $stmt = $pdo->prepare(
        "SELECT
            id_visita,
            cliente,
            direccion,
            poblacion,
            telefono,
            email,
            prioridad,
            equipo_id,
            estado,
            usuario_solicita,
            fecha_solicitud,
            fecha_resolucion
         FROM ClimaInstal_Visitas
         ORDER BY
            CASE WHEN TRIM(CAST(estado AS CHAR)) = '1' THEN 0 ELSE 1 END,
            fecha_resolucion DESC,
            fecha_solicitud DESC,
            id_visita DESC"
    );
    $stmt->execute();

    $visitas = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        if (!visitas_authorize_visita($pdo, $row, $rol, $usuario, $equipoRaw)) {
            continue;
        }

        $prioridadInt = visitas_normalize_prioridad_to_int((string)($row["prioridad"] ?? ""));
        $row["prioridad_label"] = visitas_prioridad_label_from_int($prioridadInt);
        $row["estado_label"] = trim((string)($row["estado"] ?? "")) === "1" ? "Pendiente" : "Realizada";
        $visitas[] = $row;
    }

    visitas_json_exit([
        "success" => true,
        "visitas" => $visitas
    ]);
} catch (Exception $e) {
    visitas_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}
