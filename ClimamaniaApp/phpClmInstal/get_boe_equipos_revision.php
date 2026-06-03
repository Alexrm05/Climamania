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
if ($referencia === "") {
    boe_revision_json_exit(["success" => false, "message" => "Referencia requerida"], 400);
}

try {
    $pdo = getDBConnection();

    $stmtRevision = $pdo->prepare(
        "SELECT id_linea, orden_linea, codigo, num_serie
         FROM ClimaInstal_BoeEquiposRevision
         WHERE referencia = :referencia
         ORDER BY orden_linea ASC, id_linea ASC"
    );
    $stmtRevision->execute([":referencia" => $referencia]);
    $rowsRevision = $stmtRevision->fetchAll(PDO::FETCH_ASSOC);

    $lineas = [];
    if (!empty($rowsRevision)) {
        foreach ($rowsRevision as $row) {
            $lineas[] = [
                "codigo" => boe_revision_normalize_text((string)($row["codigo"] ?? ""), 120),
                "num_serie" => boe_revision_normalize_text((string)($row["num_serie"] ?? ""), 255)
            ];
        }
        boe_revision_json_exit([
            "success" => true,
            "source" => "revision",
            "referencia" => $referencia,
            "lineas" => $lineas
        ]);
    }

    $stmtBase = $pdo->prepare(
        "SELECT codigo, NumSerie
         FROM ClmParcel_NumerosSerie
         WHERE Pedido = :referencia"
    );
    $stmtBase->execute([":referencia" => $referencia]);
    foreach ($stmtBase->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $lineas[] = [
            "codigo" => boe_revision_normalize_text((string)($row["codigo"] ?? ""), 120),
            "num_serie" => boe_revision_normalize_text((string)($row["NumSerie"] ?? ""), 255)
        ];
    }

    boe_revision_json_exit([
        "success" => true,
        "source" => "base",
        "referencia" => $referencia,
        "lineas" => $lineas
    ]);
} catch (Exception $e) {
    boe_revision_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}
