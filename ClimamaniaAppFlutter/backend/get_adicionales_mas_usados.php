<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";

$API_KEY = "TEST123";
if (!isset($_GET["api_key"]) || trim((string)$_GET["api_key"]) !== $API_KEY) {
    echo json_encode(["success" => false, "message" => "API key invalida"]);
    exit;
}

// Carga las funciones del catálogo (sin ejecutar su endpoint).
define('ADICIONALES_CATALOGO_LIB', true);
require_once __DIR__ . "/get_adicionales_catalogo.php";

$PS_PREFIX = isset($PS_DB_PREFIX) && $PS_DB_PREFIX !== "" ? $PS_DB_PREFIX : "ps_";
$DEFAULT_IVA = "21.0000";

try {
    // 1) Los artículos más usados (por frecuencia en líneas de presupuesto).
    $pdo = getDBConnection();
    $stmt = $pdo->query(
        "SELECT Articulo, COUNT(*) AS n
         FROM ClimaInstal_PresupuestosInstalador_Lineas
         WHERE TRIM(COALESCE(Articulo, '')) <> ''
         GROUP BY Articulo
         ORDER BY n DESC, MAX(date_add) DESC
         LIMIT 5"
    );
    $codigos = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $c = trim((string)($row["Articulo"] ?? ""));
        if ($c !== "") {
            $codigos[] = $c;
        }
    }
    if (empty($codigos)) {
        echo json_encode(["success" => true, "productos" => []], JSON_UNESCAPED_UNICODE);
        exit;
    }

    // 2) Resuelve cada código a un producto del catálogo (PrestaShop).
    $psPdo = getPSConnection();
    $psPrefix = resolvePsPrefix($psPdo, $PS_PREFIX);
    $shopId = resolveDefaultShopId($psPdo, $psPrefix);
    $langId = resolveDefaultLangId($psPdo, $psPrefix, $shopId);
    $categoryIds = [632];

    $idsOrdered = [];
    foreach ($codigos as $codigo) {
        $found = fetchProductIdsBySearch($psPdo, $psPrefix, $shopId, $categoryIds, $codigo, 1);
        foreach ($found as $id) {
            if (!in_array($id, $idsOrdered, true)) {
                $idsOrdered[] = $id;
            }
            break; // solo el primer producto por código
        }
    }
    if (empty($idsOrdered)) {
        echo json_encode(["success" => true, "productos" => []], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $productsMap = fetchProductsAndPricing($psPdo, $psPrefix, $shopId, $langId, $idsOrdered, $categoryIds);
    $ivaMap = fetchIvaRates($psPdo, $psPrefix, $shopId, $idsOrdered);

    $productos = [];
    foreach ($idsOrdered as $idProduct) {
        if (!isset($productsMap[$idProduct])) {
            continue;
        }
        $item = $productsMap[$idProduct];
        $ivaResolved = array_key_exists($idProduct, $ivaMap) && $ivaMap[$idProduct] !== null;
        $ivaPct = $ivaResolved ? (string)$ivaMap[$idProduct] : $DEFAULT_IVA;
        $item["iva_pct"] = formatDecimal($ivaPct, 4);
        $item["iva_fallback"] = !$ivaResolved;
        ensureBaseTramo($item);
        usort($item["tramos"], function (array $a, array $b): int {
            return compareDecimals($a["cantidad_minima"], $b["cantidad_minima"]);
        });
        $productos[] = $item;
    }

    echo json_encode([
        "success" => true,
        "productos" => $productos
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ]);
}
