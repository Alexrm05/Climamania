<?php
// Tarifa de consumibles para el instalador (menú "Tarifa de consumibles").
//
// Solo lectura de ClimaSinc_ClimaInstal_Consumibles, que mantienen ClimaGEST
// y ClimaSINC: la app no escribe nunca en ella. Los precios cambian, así que
// esto se consulta cada vez que se abre la tarifa y no se guarda en la app.
//
// GET: api_key

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/pedidos_consumibles_common.php";

$API_KEY = "TEST123";

if (!isset($_GET["api_key"]) || $_GET["api_key"] !== $API_KEY) {
    echo json_encode(["success" => false, "message" => "API key invalida"]);
    exit;
}

try {
    $pdo = getDBConnection();
    $stmt = $pdo->query(
        "SELECT Id, IdGotel, Codigo, Nombre, Descripcion, TextoFormato, UnidadVenta,
                PVFormato, PVUnidad, Formato, Factor, FotoUrl, FechaPrecios
         FROM " . CLM_CONSUMIBLES_TABLA . "
         WHERE ListarTarifa = 1 AND PVFormato IS NOT NULL AND PVFormato > 0
         ORDER BY Codigo"
    );

    $articulos = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
        $articulos[] = clm_consumible_tarifa_salida($r);
    }

    echo json_encode([
        "success" => true,
        "articulos" => $articulos,
        "nota" => "Precios sin IVA. Los artículos con formato (rollo, tira, caja…)"
            . " se venden por formato completo."
    ], JSON_UNESCAPED_UNICODE);
} catch (PDOException $e) {
    if ($e->getCode() === "42S02") {
        echo json_encode([
            "success" => false,
            "message" => "No existe la tabla " . CLM_CONSUMIBLES_TABLA . "."
        ]);
        exit;
    }
    echo json_encode(["success" => false, "message" => "ERROR: " . $e->getMessage()]);
} catch (Throwable $e) {
    echo json_encode(["success" => false, "message" => "ERROR: " . $e->getMessage()]);
}
