<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/boe_revision_common.php";

$API_KEY = "TEST123";
boe_revision_require_api_key($API_KEY);

$referencia = boe_revision_normalize_text(boe_revision_request_value("referencia"), 64);
$usuario = boe_revision_normalize_text(boe_revision_request_value("usuario"), 100);
$lineasJsonRaw = trim((string)boe_revision_request_value("lineas_json"));

if ($referencia === "") {
    boe_revision_json_exit(["success" => false, "message" => "Referencia requerida"], 400);
}
if ($lineasJsonRaw === "") {
    boe_revision_json_exit(["success" => false, "message" => "No hay lineas para guardar"], 400);
}

$lineas = boe_revision_parse_lineas($lineasJsonRaw);
if (empty($lineas)) {
    boe_revision_json_exit(["success" => false, "message" => "Debe existir al menos un equipo con código"], 400);
}

try {
    $pdo = getDBConnection();
    $pdo->beginTransaction();

    $delete = $pdo->prepare(
        "DELETE FROM ClimaInstal_BoeEquiposRevision
         WHERE referencia = :referencia"
    );
    $delete->execute([":referencia" => $referencia]);

    $insert = $pdo->prepare(
        "INSERT INTO ClimaInstal_BoeEquiposRevision
            (referencia, orden_linea, codigo, num_serie, usuario_instalador, date_add, date_upd)
         VALUES
            (:referencia, :orden_linea, :codigo, :num_serie, :usuario_instalador, NOW(), NOW())"
    );

    foreach ($lineas as $linea) {
        $insert->execute([
            ":referencia" => $referencia,
            ":orden_linea" => (int)$linea["orden_linea"],
            ":codigo" => $linea["codigo"],
            ":num_serie" => $linea["num_serie"] !== "" ? $linea["num_serie"] : null,
            ":usuario_instalador" => $usuario !== "" ? $usuario : null
        ]);
    }

    $pdo->commit();

    boe_revision_json_exit([
        "success" => true,
        "message" => "Revisión BOE guardada",
        "referencia" => $referencia,
        "lineas_guardadas" => count($lineas)
    ]);
} catch (Exception $e) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    boe_revision_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}
