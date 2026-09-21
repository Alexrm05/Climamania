<?php
// Escandallo: parte de trabajo (material consumido) de un pedido.
//
// Respuesta:
//   existe   -> true si el pedido ya tiene parte guardado
//   horas    -> hora_inicio / hora_final (HH:MM)
//   meta     -> usuario, equipo, fecha_creacion, fecha_edicion
//   lineas   -> filas guardadas (ref, descripción, unidad, prevista, real, precio)
//   defecto  -> materiales por defecto para precargar la tabla cuando aún no
//               hay parte: los de ClimaInstal_ParteMateriales_Relacionados
//               cuyo articulo_padre es una de las referencias del pedido (o
//               '*'), con la cantidad prevista multiplicada por las unidades
//               del padre en el pedido.
//   padres   -> referencias del pedido usadas para el cruce
//
// GET: api_key, referencia, padres (opcional: "REF:cant,REF2:cant"; si no
// llega, se leen las líneas del pedido en PrestaShop).

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";

$API_KEY = "TEST123";

if (!isset($_GET["api_key"]) || $_GET["api_key"] !== $API_KEY) {
    echo json_encode(["success" => false, "message" => "API key invalida"]);
    exit;
}

$PS_PREFIX = isset($PS_DB_PREFIX) && $PS_DB_PREFIX !== "" ? $PS_DB_PREFIX : "ps_";

$pedido = trim((string)($_GET["referencia"] ?? ($_GET["pedido"] ?? "")));
if ($pedido === "") {
    echo json_encode(["success" => false, "message" => "Referencia requerida"]);
    exit;
}

/// "INSTAL40:2,DESINSTDO:1" -> ['INSTAL40' => 2.0, 'DESINSTDO' => 1.0]
function pm_parse_padres(string $raw): array
{
    $out = [];
    foreach (explode(",", $raw) as $tok) {
        $tok = trim($tok);
        if ($tok === "") {
            continue;
        }
        [$ref, $cant] = array_pad(explode(":", $tok, 2), 2, "1");
        $ref = strtoupper(trim($ref));
        $n = (float)str_replace(",", ".", trim($cant));
        if ($ref !== "") {
            $out[$ref] = ($out[$ref] ?? 0) + ($n > 0 ? $n : 1);
        }
    }
    return $out;
}

/// Líneas del pedido desde PrestaShop: ['REF' => cantidad]. Vacío si falla.
function pm_padres_desde_prestashop(string $pedido, string $psPrefix): array
{
    try {
        $psPdo = getPSConnection();
        $prefix = function_exists("resolvePsPrefix") ? resolvePsPrefix($psPdo, $psPrefix) : $psPrefix;
        $stmt = $psPdo->prepare(
            "SELECT lin.product_reference, lin.product_quantity
             FROM {$prefix}orders o
             INNER JOIN {$prefix}order_detail lin ON lin.id_order = o.id_order
             WHERE o.reference = :ref"
        );
        $stmt->execute([":ref" => $pedido]);
        $out = [];
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
            $ref = strtoupper(trim((string)$r["product_reference"]));
            if ($ref !== "") {
                $out[$ref] = ($out[$ref] ?? 0) + max(1.0, (float)$r["product_quantity"]);
            }
        }
        return $out;
    } catch (Throwable $e) {
        return [];
    }
}

function pm_time(?string $v): string
{
    return ($v === null || $v === "") ? "" : substr($v, 0, 5);
}

function pm_dec(?string $v, int $d = 2): string
{
    return number_format((float)($v ?? 0), $d, ".", "");
}

try {
    $pdo = getDBConnection();

    $stmt = $pdo->prepare(
        "SELECT id, articulo, articulo_padre, descripcion, unidad, cantidad_prevista, cantidad,
                hora_inicio, hora_final, precio_unitario_sin_iva,
                usuario, equipo_instaladores, fecha_creacion, fecha_edicion
         FROM ClimaInstal_ParteMateriales
         WHERE pedido = :pedido
         ORDER BY id ASC"
    );
    $stmt->execute([":pedido" => $pedido]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $lineas = [];
    foreach ($rows as $r) {
        $lineas[] = [
            "id" => (int)$r["id"],
            "articulo" => (string)$r["articulo"],
            "articulo_padre" => (string)($r["articulo_padre"] ?? ""),
            "descripcion" => (string)$r["descripcion"],
            "unidad" => (string)$r["unidad"],
            "cantidad_prevista" => pm_dec($r["cantidad_prevista"]),
            "cantidad" => pm_dec($r["cantidad"]),
            "precio_unitario_sin_iva" => pm_dec($r["precio_unitario_sin_iva"], 6)
        ];
    }

    $horas = ["hora_inicio" => "", "hora_final" => ""];
    $meta = ["usuario" => "", "equipo" => "", "fecha_creacion" => "", "fecha_edicion" => ""];
    if (!empty($rows)) {
        $horas = [
            "hora_inicio" => pm_time($rows[0]["hora_inicio"] ?? null),
            "hora_final" => pm_time($rows[0]["hora_final"] ?? null)
        ];
        $meta = [
            "usuario" => (string)($rows[0]["usuario"] ?? ""),
            "equipo" => (string)($rows[0]["equipo_instaladores"] ?? ""),
            "fecha_creacion" => (string)$rows[0]["fecha_creacion"],
            "fecha_edicion" => (string)$rows[0]["fecha_edicion"]
        ];
    }

    // Referencias del pedido (padres): las manda la app o se leen de PrestaShop.
    $padres = pm_parse_padres((string)($_GET["padres"] ?? ""));
    if (empty($padres)) {
        $padres = pm_padres_desde_prestashop($pedido, $PS_PREFIX);
    }

    $defecto = [];
    try {
        $stmtDef = $pdo->query(
            "SELECT articulo_padre, articulo, descripcion, unidad, cantidad_prevista
             FROM ClimaInstal_ParteMateriales_Relacionados
             WHERE activo = 1
             ORDER BY orden ASC, id ASC"
        );
        // Mismo artículo en varios padres del pedido: se suma la previsión.
        $acumulado = [];
        foreach ($stmtDef->fetchAll(PDO::FETCH_ASSOC) as $d) {
            $padre = strtoupper(trim((string)$d["articulo_padre"]));
            $veces = $padre === "*" ? 1.0 : ($padres[$padre] ?? 0.0);
            if ($veces <= 0) {
                continue;
            }
            $art = (string)$d["articulo"];
            if (!isset($acumulado[$art])) {
                $acumulado[$art] = [
                    "articulo" => $art,
                    "articulo_padre" => $padre,
                    "descripcion" => (string)$d["descripcion"],
                    "unidad" => (string)$d["unidad"],
                    "prevista" => 0.0,
                    "cantidad" => "0.00"
                ];
            }
            $acumulado[$art]["prevista"] += (float)$d["cantidad_prevista"] * $veces;
        }
        foreach ($acumulado as $a) {
            $a["cantidad_prevista"] = pm_dec((string)$a["prevista"]);
            unset($a["prevista"]);
            $defecto[] = $a;
        }
    } catch (PDOException $e) {
        if ($e->getCode() !== "42S02") {
            throw $e;
        }
    }

    echo json_encode([
        "success" => true,
        "existe" => !empty($rows),
        "pedido" => $pedido,
        "horas" => $horas,
        "meta" => $meta,
        "padres" => $padres,
        "lineas" => $lineas,
        "defecto" => $defecto
    ], JSON_UNESCAPED_UNICODE);
} catch (PDOException $e) {
    if ($e->getCode() === "42S02") {
        echo json_encode(["success" => false, "message" => "No existe la tabla ClimaInstal_ParteMateriales. Ejecuta el SQL del escandallo."]);
        exit;
    }
    echo json_encode(["success" => false, "message" => "ERROR: " . $e->getMessage()]);
} catch (Throwable $e) {
    echo json_encode(["success" => false, "message" => "ERROR: " . $e->getMessage()]);
}
