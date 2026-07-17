<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/visitas_api_common.php";

$API_KEY = "TEST123";
visitas_require_api_key($API_KEY);

$telefonoRaw = visitas_normalize_text(visitas_request("telefono"), 120);
$telefonosRaw = trim((string)visitas_request("telefonos"));
$direccionInstalacion = visitas_normalize_text(visitas_request("direccion_instalacion"), 500);
$telefonosNormalizados = [];
if ($telefonosRaw !== "") {
    foreach (preg_split('/[\s,;|]+/', $telefonosRaw) as $token) {
        $token = visitas_normalize_phone((string)$token);
        if ($token !== "") {
            $telefonosNormalizados[$token] = true;
        }
    }
}
$telefonoNormalizado = visitas_normalize_phone($telefonoRaw);
if ($telefonoNormalizado !== "") {
    $telefonosNormalizados[$telefonoNormalizado] = true;
}
$telefonosNormalizados = array_keys($telefonosNormalizados);

if (empty($telefonosNormalizados)) {
    visitas_json_exit([
        "success" => true,
        "telefono_normalizado" => "",
        "telefonos_normalizados" => [],
        "visitas" => [],
        "total" => 0
    ]);
}

try {
    $pdo = getDBConnection();

    $stmt = $pdo->prepare(
        "SELECT
            id_visita,
            cliente,
            direccion,
            poblacion,
            telefono,
            prioridad,
            equipo_id,
            estado,
            usuario_solicita,
            fecha_solicitud,
            fecha_resolucion
         FROM ClimaInstal_Visitas
         WHERE COALESCE(telefono, '') <> ''
           AND TRIM(CAST(COALESCE(estado, '') AS CHAR)) <> '1'
         ORDER BY fecha_resolucion DESC, fecha_solicitud DESC, id_visita DESC"
    );
    $stmt->execute();

    $visitas = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        if (!visitas_match_phone($telefonosNormalizados, (string)($row["telefono"] ?? ""))) {
            continue;
        }
        $prioridadInt = visitas_normalize_prioridad_to_int((string)($row["prioridad"] ?? ""));
        $row["prioridad_label"] = visitas_prioridad_label_from_int($prioridadInt);
        $visitas[] = $row;
    }

    visitas_json_exit([
        "success" => true,
        "telefono_normalizado" => $telefonoNormalizado,
        "telefonos_normalizados" => $telefonosNormalizados,
        "visitas" => $visitas,
        "total" => count($visitas)
    ]);
} catch (Exception $e) {
    visitas_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}

function visitas_normalize_phone(string $value): string
{
    return preg_replace('/\D+/', '', trim($value)) ?? '';
}

function visitas_match_phone(array $telefonosNormalizados, string $telefonoVisita): bool
{
    if (empty($telefonosNormalizados)) {
        return false;
    }
    $telefonoVisitaNorm = visitas_normalize_phone($telefonoVisita);
    if ($telefonoVisitaNorm === '') {
        return false;
    }
    return in_array($telefonoVisitaNorm, $telefonosNormalizados, true);
}
