<?php
// Diagnóstico temporal: qué tablas del escandallo existen y en qué base de
// datos está mirando la app. Solo lectura. BORRAR tras usarlo.
header('Content-Type: application/json; charset=utf-8');
ini_set('display_errors', 0);
error_reporting(0);
require_once __DIR__ . "/conexion.php";

if (($_GET['api_key'] ?? '') !== 'TEST123') {
    echo json_encode(["success" => false, "message" => "API key invalida"]);
    exit;
}

$pdo = getDBConnection();
$tablas = [
    "ClimaInstal_ParteMateriales",
    "ClimaInstal_ParteMateriales_Relacionados",
    "ClimaInstal_ParteJornadas",
    "ClimaSinc_ClimaInstal_Consumibles",
    "ClimaInstal_ControlUbicacionesEventos"
];

$out = ["success" => true];
$out["base_de_datos"] = (string)$pdo->query("SELECT DATABASE()")->fetchColumn();

foreach ($tablas as $t) {
    try {
        $n = $pdo->query("SELECT COUNT(*) FROM `$t`")->fetchColumn();
        $out["tablas"][$t] = "existe · $n filas";
    } catch (PDOException $e) {
        $out["tablas"][$t] = $e->getCode() === "42S02"
            ? "NO EXISTE"
            : "error: " . $e->getMessage();
    }
}

// Columnas de ParteJornadas, por si existe pero con otra estructura.
try {
    $cols = $pdo->query("SHOW COLUMNS FROM ClimaInstal_ParteJornadas")->fetchAll(PDO::FETCH_COLUMN);
    $out["columnas_jornadas"] = $cols;
} catch (PDOException $e) {
    $out["columnas_jornadas"] = "no disponible";
}

// Prueba real de escritura y borrado, para ver el error exacto si lo hay.
try {
    $pdo->prepare(
        "INSERT INTO ClimaInstal_ParteJornadas
            (pedido, fecha, hora_inicio, hora_final, usuario, equipo_instaladores,
             fecha_creacion, fecha_edicion)
         VALUES ('__DIAG__', '2026-01-01', '08:00:00', '09:00:00', '__diag__', 'TEST', NOW(), NOW())"
    )->execute();
    $pdo->prepare("DELETE FROM ClimaInstal_ParteJornadas WHERE pedido = '__DIAG__'")->execute();
    $out["escritura_jornadas"] = "OK (fila insertada y borrada)";
} catch (PDOException $e) {
    $out["escritura_jornadas"] = "FALLA: " . $e->getMessage();
}

echo json_encode($out, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
