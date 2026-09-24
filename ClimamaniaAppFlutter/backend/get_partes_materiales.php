<?php
// Escandallo: histórico de partes de trabajo y totales de material entre
// dos fechas. Cada usuario ve solo sus partes; el rol adminclm ve todos.
//
// GET: api_key, usuario, rol, desde (YYYY-MM-DD), hasta (YYYY-MM-DD)
// Respuesta:
//   partes  -> uno por pedido: pedido, cliente, fecha, horas, usuario, equipo,
//              num_lineas, total_sin_iva
//   totales -> uno por artículo: descripción, unidad, prevista, real,
//              desviación, nº de partes, importe sin IVA

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";
require_once __DIR__ . "/consumibles_common.php";

$API_KEY = "TEST123";

if (!isset($_GET["api_key"]) || $_GET["api_key"] !== $API_KEY) {
    echo json_encode(["success" => false, "message" => "API key invalida"]);
    exit;
}

// Mismo criterio que el resto de endpoints (get_visitas_pendientes.php).
function pm_es_admin(string $rol): bool
{
    $r = strtolower(trim($rol));
    return $r === "adminclm" || $r === "admin" || $r === "administrador";
}

$usuario = trim((string)($_GET["usuario"] ?? ""));
$rol = trim((string)($_GET["rol"] ?? ""));
$desde = trim((string)($_GET["desde"] ?? ""));
$hasta = trim((string)($_GET["hasta"] ?? ""));
$esAdmin = pm_es_admin($rol);

function pm_fecha(string $v, string $porDefecto): string
{
    return preg_match('/^\d{4}-\d{2}-\d{2}$/', $v) ? $v : $porDefecto;
}

// Por defecto, el mes en curso.
$desde = pm_fecha($desde, date("Y-m-01"));
$hasta = pm_fecha($hasta, date("Y-m-d"));

if (!$esAdmin && $usuario === "") {
    echo json_encode(["success" => false, "message" => "Usuario requerido"]);
    exit;
}

try {
    $pdo = getDBConnection();

    $where = "pm.fecha_creacion >= :desde AND pm.fecha_creacion < DATE_ADD(:hasta, INTERVAL 1 DAY)";
    $params = [":desde" => $desde . " 00:00:00", ":hasta" => $hasta];
    if (!$esAdmin) {
        $where .= " AND pm.usuario = :usuario";
        $params[":usuario"] = $usuario;
    }

    // Un parte por pedido.
    $stmt = $pdo->prepare(
        "SELECT pm.pedido,
                MIN(pm.fecha_creacion) AS fecha_creacion,
                MAX(pm.fecha_edicion) AS fecha_edicion,
                MIN(pm.hora_inicio) AS hora_inicio,
                MAX(pm.hora_final) AS hora_final,
                MAX(pm.usuario) AS usuario,
                MAX(pm.equipo_instaladores) AS equipo,
                COUNT(*) AS num_lineas,
                SUM(pm.cantidad * pm.precio_unitario_sin_iva) AS total_sin_iva,
                MAX(ev.nombrecliente) AS cliente
         FROM ClimaInstal_ParteMateriales pm
         LEFT JOIN ClimaInstal_events ev ON ev.referencia = pm.pedido
         WHERE $where
         GROUP BY pm.pedido
         ORDER BY MIN(pm.fecha_creacion) DESC"
    );
    $stmt->execute($params);

    $partes = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
        $partes[] = [
            "pedido" => (string)$r["pedido"],
            "cliente" => (string)($r["cliente"] ?? ""),
            "fecha_creacion" => (string)$r["fecha_creacion"],
            "fecha_edicion" => (string)$r["fecha_edicion"],
            "hora_inicio" => substr((string)($r["hora_inicio"] ?? ""), 0, 5),
            "hora_final" => substr((string)($r["hora_final"] ?? ""), 0, 5),
            "usuario" => (string)($r["usuario"] ?? ""),
            "equipo" => (string)($r["equipo"] ?? ""),
            "num_lineas" => (int)$r["num_lineas"],
            "total_sin_iva" => number_format((float)$r["total_sin_iva"], 2, ".", "")
        ];
    }

    // Totales por artículo en el rango.
    $stmt = $pdo->prepare(
        "SELECT pm.articulo,
                MAX(pm.descripcion) AS descripcion,
                MAX(pm.unidad) AS unidad,
                SUM(pm.cantidad_prevista) AS prevista,
                SUM(pm.cantidad) AS real_total,
                COUNT(DISTINCT pm.pedido) AS num_partes,
                SUM(pm.cantidad * pm.precio_unitario_sin_iva) AS importe_sin_iva
         FROM ClimaInstal_ParteMateriales pm
         WHERE $where
         GROUP BY pm.articulo
         ORDER BY real_total DESC, pm.articulo ASC"
    );
    $stmt->execute($params);

    $filasTotales = $stmt->fetchAll(PDO::FETCH_ASSOC);
    // El artículo guardado es el IdGotel: se resuelve contra el catálogo
    // para mostrar el código de material que el técnico reconoce.
    $catalogo = clm_consumibles_por_claves($pdo, array_map(
        fn($r) => (string)$r["articulo"],
        $filasTotales
    ));

    $totales = [];
    foreach ($filasTotales as $r) {
        $prev = (float)$r["prevista"];
        $real = (float)$r["real_total"];
        $mat = $catalogo[strtoupper(trim((string)$r["articulo"]))] ?? null;
        $totales[] = [
            "codigo" => $mat !== null ? $mat["codigo"] : (string)$r["articulo"],
            "articulo" => (string)$r["articulo"],
            "descripcion" => (string)($r["descripcion"] ?? ""),
            "unidad" => (string)($r["unidad"] ?? "ud"),
            "cantidad_prevista" => number_format($prev, 2, ".", ""),
            "cantidad" => number_format($real, 2, ".", ""),
            "desviacion" => number_format($real - $prev, 2, ".", ""),
            "num_partes" => (int)$r["num_partes"],
            "importe_sin_iva" => number_format((float)$r["importe_sin_iva"], 2, ".", "")
        ];
    }

    echo json_encode([
        "success" => true,
        "desde" => $desde,
        "hasta" => $hasta,
        "solo_usuario" => !$esAdmin,
        "partes" => $partes,
        "totales" => $totales
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
