<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";

$API_KEY = "TEST123";
$PS_PREFIX = isset($PS_DB_PREFIX) && $PS_DB_PREFIX !== "" ? $PS_DB_PREFIX : "ps_";
$DEFAULT_IVA = "21.0000";

if (!isset($_GET["api_key"]) || trim((string)$_GET["api_key"]) !== $API_KEY) {
    echo json_encode(["success" => false, "message" => "API key invalida"]);
    exit;
}

$query = trim((string)($_GET["q"] ?? ""));
$limitRaw = trim((string)($_GET["limit"] ?? "0"));
$limit = is_numeric($limitRaw) ? (int)$limitRaw : 0;
if ($limit < 0) {
    $limit = 0;
}

try {
    $psPdo = getPSConnection();
    $psPrefix = resolvePsPrefix($psPdo, $PS_PREFIX);
    $shopId = resolveDefaultShopId($psPdo, $psPrefix);
    $langId = resolveDefaultLangId($psPdo, $psPrefix, $shopId);
    $categoryIds = [632];

    $idsOrdered = fetchProductIdsBySearch($psPdo, $psPrefix, $shopId, $categoryIds, $query, $limit);
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

function fetchProductIdsBySearch(PDO $pdo, string $prefix, int $shopId, array $categoryIds, string $query, int $limit): array
{
    if (empty($categoryIds)) {
        return [];
    }

    $like = "%" . $query . "%";
    $categoryPlaceholders = [];
    $params = [
        ":shop_id" => $shopId
    ];
    foreach ($categoryIds as $index => $catId) {
        $key = ":cat_" . $index;
        $categoryPlaceholders[] = $key;
        $params[$key] = (int)$catId;
    }

    $searchWhere = "";
    if ($query !== "") {
        $searchWhere = "AND (
                    LOWER(p.reference) LIKE LOWER(:term)
                    OR EXISTS (
                        SELECT 1
                        FROM " . ident($prefix . "product_lang") . " plx
                        WHERE plx.id_product = p.id_product
                          AND plx.id_shop = :shop_id_name
                          AND LOWER(plx.name) LIKE LOWER(:term_name)
                    )
                  )";
        $params[":term"] = $like;
        $params[":term_name"] = $like;
        $params[":shop_id_name"] = $shopId;
    }

    $sql = "SELECT DISTINCT p.id_product
            FROM " . ident($prefix . "category_product") . " cp
            INNER JOIN " . ident($prefix . "product") . " p
                ON cp.id_product = p.id_product
            INNER JOIN " . ident($prefix . "product_shop") . " ps
                ON p.id_product = ps.id_product
               AND ps.id_shop = :shop_id
            WHERE cp.id_category IN (" . implode(",", $categoryPlaceholders) . ")
              AND ps.active = 1
            " . $searchWhere . "
            ORDER BY p.reference ASC";

    if ($limit > 0) {
        $sql .= " LIMIT " . (int)$limit;
    }

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    $ids = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $id = (int)($row["id_product"] ?? 0);
        if ($id > 0) {
            $ids[] = $id;
        }
    }
    return $ids;
}

function fetchProductsAndPricing(PDO $pdo, string $prefix, int $shopId, int $langId, array $ids, array $categoryIds): array
{
    if (empty($ids) || empty($categoryIds)) {
        return [];
    }

    $productIn1 = [];
    $productIn2 = [];
    $categoryIn1 = [];
    $categoryIn2 = [];
    $params = [];
    foreach ($ids as $i => $id) {
        $key1 = ":id1_" . $i;
        $key2 = ":id2_" . $i;
        $productIn1[] = $key1;
        $productIn2[] = $key2;
        $params[$key1] = (int)$id;
        $params[$key2] = (int)$id;
    }
    foreach ($categoryIds as $i => $catId) {
        $key1 = ":cat1_" . $i;
        $key2 = ":cat2_" . $i;
        $categoryIn1[] = $key1;
        $categoryIn2[] = $key2;
        $params[$key1] = (int)$catId;
        $params[$key2] = (int)$catId;
    }
    $params[":shop_id_1"] = $shopId;
    $params[":shop_id_2"] = $shopId;
    $params[":lang_id_1"] = $langId;
    $params[":lang_id_2"] = $langId;
    $params[":comb_lang_id_1"] = $langId;
    $params[":comb_lang_id_2"] = $langId;
    $params[":city_filter_1"] = "%Barcelona%";
    $params[":city_filter_2"] = "%Barcelona%";

    $sql = "SELECT
                p.id_product,
                p.reference AS codigo,
                pl.name AS descripcion,
                (ps.price + IFNULL(comb.impacto, 0)) AS precio_sin_iva,
                1 AS cantidad_minima,
                0.000000 AS reduction,
                'amount' AS reduction_type
            FROM " . ident($prefix . "category_product") . " cp
            INNER JOIN " . ident($prefix . "product") . " p
                ON cp.id_product = p.id_product
            INNER JOIN " . ident($prefix . "product_shop") . " ps
                ON p.id_product = ps.id_product
               AND ps.id_shop = :shop_id_1
            INNER JOIN " . ident($prefix . "product_lang") . " pl
                ON p.id_product = pl.id_product
               AND pl.id_lang = :lang_id_1
            LEFT JOIN (
                SELECT pa.id_product, pa.price AS impacto
                FROM " . ident($prefix . "product_attribute") . " pa
                LEFT JOIN " . ident($prefix . "product_attribute_combination") . " pac
                    ON pa.id_product_attribute = pac.id_product_attribute
                LEFT JOIN " . ident($prefix . "attribute_lang") . " al
                    ON pac.id_attribute = al.id_attribute
                   AND al.id_lang = :comb_lang_id_1
                GROUP BY pa.id_product, pa.id_product_attribute, pa.price
                HAVING GROUP_CONCAT(al.name ORDER BY al.name SEPARATOR ' - ') LIKE :city_filter_1
            ) comb
                ON p.id_product = comb.id_product
            WHERE cp.id_category IN (" . implode(",", $categoryIn1) . ")
              AND p.id_product IN (" . implode(",", $productIn1) . ")
              AND ps.active = 1
              AND NOT EXISTS (
                SELECT 1
                FROM " . ident($prefix . "specific_price") . " sp
                WHERE sp.id_product = p.id_product
                  AND sp.id_group = 0
                  AND sp.id_customer = 0
                  AND sp.from_quantity = 1
              )
            UNION ALL
            SELECT
                p.id_product,
                p.reference AS codigo,
                pl.name AS descripcion,
                (ps.price + IFNULL(comb.impacto, 0)) AS precio_sin_iva,
                sp.from_quantity AS cantidad_minima,
                sp.reduction,
                sp.reduction_type
            FROM " . ident($prefix . "product") . " p
            INNER JOIN " . ident($prefix . "category_product") . " cp
                ON cp.id_product = p.id_product
            INNER JOIN " . ident($prefix . "product_shop") . " ps
                ON p.id_product = ps.id_product
               AND ps.id_shop = :shop_id_2
            INNER JOIN " . ident($prefix . "product_lang") . " pl
                ON p.id_product = pl.id_product
               AND pl.id_lang = :lang_id_2
            LEFT JOIN (
                SELECT pa.id_product, pa.price AS impacto
                FROM " . ident($prefix . "product_attribute") . " pa
                LEFT JOIN " . ident($prefix . "product_attribute_combination") . " pac
                    ON pa.id_product_attribute = pac.id_product_attribute
                LEFT JOIN " . ident($prefix . "attribute_lang") . " al
                    ON pac.id_attribute = al.id_attribute
                   AND al.id_lang = :comb_lang_id_2
                GROUP BY pa.id_product, pa.id_product_attribute, pa.price
                HAVING GROUP_CONCAT(al.name ORDER BY al.name SEPARATOR ' - ') LIKE :city_filter_2
            ) comb
                ON p.id_product = comb.id_product
            INNER JOIN " . ident($prefix . "specific_price") . " sp
                ON p.id_product = sp.id_product
               AND sp.id_group = 0
               AND sp.id_customer = 0
            WHERE cp.id_category IN (" . implode(",", $categoryIn2) . ")
              AND p.id_product IN (" . implode(",", $productIn2) . ")
              AND ps.active = 1
            ORDER BY codigo ASC, cantidad_minima ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $products = [];
    foreach ($rows as $row) {
        $id = (int)($row["id_product"] ?? 0);
        if ($id <= 0) {
            continue;
        }

        $codigo = trim((string)($row["codigo"] ?? ""));
        $descripcion = trim((string)($row["descripcion"] ?? ""));
        $linePrice = formatDecimal(normalizeDecimal($row["precio_sin_iva"] ?? "0"), 6);

        if (!isset($products[$id])) {
            $products[$id] = [
                "id_product" => $id,
                "codigo" => $codigo,
                "descripcion" => $descripcion,
                "precio_base_sin_iva" => $linePrice,
                "tramos" => [],
                "_tramo_keys" => []
            ];
        }

        $rawQty = $row["cantidad_minima"] ?? null;
        if ($rawQty === null || $rawQty === "") {
            continue;
        }

        $qty = normalizeDecimal($rawQty);
        if (compareDecimals($qty, "0") <= 0) {
            $qty = "1";
        }

        $qtyKey = formatDecimal($qty, 1);
        if (isset($products[$id]["_tramo_keys"][$qtyKey])) {
            continue;
        }

        $tramoPrice = $linePrice;

        $reduction = formatDecimal(normalizeDecimal($row["reduction"] ?? "0"), 6);
        if (compareDecimals($reduction, "0") < 0) {
            $reduction = "0.000000";
        }

        $reductionType = strtolower(trim((string)($row["reduction_type"] ?? "")));
        if ($reductionType !== "amount" && $reductionType !== "percentage") {
            $reductionType = "amount";
        }

        $products[$id]["tramos"][] = [
            "cantidad_minima" => formatDecimal($qty, 1),
            "precio_base_sin_iva" => $tramoPrice,
            "reduction" => $reduction,
            "reduction_type" => $reductionType
        ];
        $products[$id]["_tramo_keys"][$qtyKey] = true;

        if (compareDecimals($qty, "1") === 0) {
            $products[$id]["precio_base_sin_iva"] = $tramoPrice;
        }
    }

    foreach ($products as &$item) {
        unset($item["_tramo_keys"]);
    }
    unset($item);

    return $products;
}

function fetchIvaRates(PDO $pdo, string $prefix, int $shopId, array $ids): array
{
    if (empty($ids)) {
        return [];
    }

    $in = [];
    $params = [];
    foreach ($ids as $i => $id) {
        $key = ":id_" . $i;
        $in[] = $key;
        $params[$key] = (int)$id;
    }
    $params[":shop_id"] = $shopId;

    $sql = "SELECT
                ps.id_product,
                MAX(t.rate) AS iva_pct
            FROM " . ident($prefix . "product_shop") . " ps
            LEFT JOIN " . ident($prefix . "tax_rule") . " tr
                ON tr.id_tax_rules_group = ps.id_tax_rules_group
            LEFT JOIN " . ident($prefix . "tax") . " t
                ON t.id_tax = tr.id_tax
               AND t.active = 1
            WHERE ps.id_shop = :shop_id
              AND ps.id_product IN (" . implode(",", $in) . ")
            GROUP BY ps.id_product";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    $ivaMap = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $id = (int)($row["id_product"] ?? 0);
        if ($id <= 0) {
            continue;
        }
        $raw = $row["iva_pct"] ?? null;
        if ($raw === null || $raw === "") {
            $ivaMap[$id] = null;
            continue;
        }
        $ivaMap[$id] = formatDecimal(normalizeDecimal($raw), 4);
    }

    return $ivaMap;
}

function ensureBaseTramo(array &$item): void
{
    if (!isset($item["tramos"]) || !is_array($item["tramos"])) {
        $item["tramos"] = [];
    }

    $hasQtyOne = false;
    foreach ($item["tramos"] as $tramo) {
        $qty = normalizeDecimal((string)($tramo["cantidad_minima"] ?? "0"));
        if (compareDecimals($qty, "1") === 0) {
            $hasQtyOne = true;
            break;
        }
    }

    if ($hasQtyOne) {
        return;
    }

    $item["tramos"][] = [
        "cantidad_minima" => "1.0",
        "precio_base_sin_iva" => formatDecimal((string)($item["precio_base_sin_iva"] ?? "0"), 6),
        "reduction" => "0.000000",
        "reduction_type" => "amount"
    ];
}

function normalizeDecimal($value): string
{
    $raw = trim((string)$value);
    if ($raw === "") {
        return "0";
    }
    $raw = str_replace(",", ".", $raw);
    if (!is_numeric($raw)) {
        return "0";
    }
    return (string)$raw;
}

function formatDecimal($value, int $scale): string
{
    $number = (float)normalizeDecimal($value);
    return number_format($number, $scale, ".", "");
}

function compareDecimals($a, $b): int
{
    $af = (float)normalizeDecimal($a);
    $bf = (float)normalizeDecimal($b);
    if ($af < $bf) {
        return -1;
    }
    if ($af > $bf) {
        return 1;
    }
    return 0;
}

function fetchCategoryIdsInclusive(PDO $pdo, string $prefix, int $rootCategoryId): array
{
    $rootCategoryId = (int)$rootCategoryId;
    if ($rootCategoryId <= 0) {
        return [];
    }

    try {
        if (!tableExists($pdo, $prefix . "category")) {
            return [$rootCategoryId];
        }

        $sql = "SELECT c2.id_category
                FROM " . ident($prefix . "category") . " c1
                INNER JOIN " . ident($prefix . "category") . " c2
                    ON c2.nleft >= c1.nleft
                   AND c2.nright <= c1.nright
                WHERE c1.id_category = :root";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([":root" => $rootCategoryId]);

        $ids = [];
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
            $id = (int)($row["id_category"] ?? 0);
            if ($id > 0) {
                $ids[] = $id;
            }
        }

        if (empty($ids)) {
            return [$rootCategoryId];
        }
        return array_values(array_unique($ids));
    } catch (Exception $e) {
        return [$rootCategoryId];
    }
}

function resolveDefaultShopId(PDO $pdo, string $prefix): int
{
    try {
        if (!tableExists($pdo, $prefix . "shop")) {
            return 1;
        }
        $sql = "SELECT id_shop
                FROM " . ident($prefix . "shop") . "
                ORDER BY id_shop ASC
                LIMIT 1";
        $stmt = $pdo->query($sql);
        $value = (int)$stmt->fetchColumn();
        return $value > 0 ? $value : 1;
    } catch (Exception $e) {
        return 1;
    }
}

function resolveDefaultLangId(PDO $pdo, string $prefix, int $shopId): int
{
    try {
        if (tableExists($pdo, $prefix . "configuration")) {
            $sql = "SELECT value
                    FROM " . ident($prefix . "configuration") . "
                    WHERE name = 'PS_LANG_DEFAULT'
                      AND (
                            id_shop IS NULL
                            OR id_shop = 0
                            OR id_shop = :shop_id
                          )
                    ORDER BY (id_shop = :shop_priority) DESC, id_configuration DESC
                    LIMIT 1";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([
                ":shop_id" => $shopId,
                ":shop_priority" => $shopId
            ]);
            $value = (int)$stmt->fetchColumn();
            if ($value > 0) {
                return $value;
            }
        }
    } catch (Exception $e) {
        // Fall through to language table lookup
    }

    try {
        if (tableExists($pdo, $prefix . "lang")) {
            $sql = "SELECT id_lang
                    FROM " . ident($prefix . "lang") . "
                    WHERE active = 1
                    ORDER BY id_lang ASC
                    LIMIT 1";
            $stmt = $pdo->query($sql);
            $value = (int)$stmt->fetchColumn();
            if ($value > 0) {
                return $value;
            }
        }
    } catch (Exception $e) {
        // Ignore and return fallback
    }

    return 1;
}

function resolvePsPrefix(PDO $pdo, string $preferred): string
{
    $preferred = trim($preferred);
    if ($preferred !== "" && tableExists($pdo, $preferred . "orders")) {
        return $preferred;
    }

    $fallbacks = ["ps_", ""];
    foreach ($fallbacks as $prefix) {
        if ($prefix === $preferred) {
            continue;
        }
        if (tableExists($pdo, $prefix . "orders")) {
            return $prefix;
        }
    }

    return $preferred;
}

function tableExists(PDO $pdo, string $table): bool
{
    $stmt = $pdo->prepare("SHOW TABLES LIKE ?");
    $stmt->execute([$table]);
    return $stmt->fetchColumn() !== false;
}

function ident(string $name): string
{
    return "`" . str_replace("`", "``", $name) . "`";
}
