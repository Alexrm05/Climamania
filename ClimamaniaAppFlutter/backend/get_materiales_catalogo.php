<?php
// Escandallo: buscador de materiales (botón "+" de Material consumido).
//
// Lee de ClimaSinc_ClimaInstal_Consumibles, sincronizada desde PrestaShop:
// ya no consulta la tienda, así que funciona aunque PrestaShop no responda.
//
// GET: api_key, q (referencia o descripción; vacío = más usados),
//      mas_usados=1 para pedirlos explícitamente, limit (por defecto 50).
//
// Devuelve materiales con "articulo" = IdGotel (lo que se guarda en el parte)
// y "codigo" = referencia legible para el técnico.

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/consumibles_common.php";

$API_KEY = "TEST123";

if (!isset($_GET["api_key"]) || $_GET["api_key"] !== $API_KEY) {
    echo json_encode(["success" => false, "message" => "API key invalida"]);
    exit;
}

$q = trim((string)($_GET["q"] ?? ""));
$masUsados = ($_GET["mas_usados"] ?? "") === "1" || $q === "";
$limit = (int)($_GET["limit"] ?? 50);
if ($limit <= 0 || $limit > 200) {
    $limit = 50;
}

try {
    $pdo = getDBConnection();

    if ($masUsados) {
        // Los que más veces se han consumido en partes ya guardados. Si aún
        // no hay partes, se muestran los primeros del catálogo por código.
        $stmt = $pdo->prepare(
            "SELECT c.IdGotel, c.Codigo, c.Nombre, c.Descripcion, c.UnidadEscandallo, c.Factor
             FROM ClimaInstal_ParteMateriales pm
             INNER JOIN " . CLM_CONSUMIBLES_TABLA . " c ON c.IdGotel = pm.articulo
             WHERE pm.cantidad > 0
             GROUP BY c.IdGotel, c.Codigo, c.Nombre, c.Descripcion, c.UnidadEscandallo, c.Factor
             ORDER BY COUNT(*) DESC, MAX(pm.fecha_edicion) DESC
             LIMIT :lim"
        );
        $stmt->bindValue(":lim", $limit > 12 ? 12 : $limit, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        if (empty($rows)) {
            $stmt = $pdo->prepare(
                "SELECT IdGotel, Codigo, Nombre, Descripcion, UnidadEscandallo, Factor
                 FROM " . CLM_CONSUMIBLES_TABLA . "
                 ORDER BY Codigo ASC
                 LIMIT :lim"
            );
            $stmt->bindValue(":lim", $limit > 12 ? 12 : $limit, PDO::PARAM_INT);
            $stmt->execute();
            $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        }
    } else {
        // Búsqueda por referencia o por descripción. El LIKE con la
        // colación de la tabla ya ignora mayúsculas y acentos.
        $like = "%" . str_replace(["%", "_"], ["\\%", "\\_"], $q) . "%";
        $stmt = $pdo->prepare(
            "SELECT IdGotel, Codigo, Nombre, Descripcion, UnidadEscandallo, Factor
             FROM " . CLM_CONSUMIBLES_TABLA . "
             WHERE Codigo LIKE :t OR Nombre LIKE :t2 OR Descripcion LIKE :t3
             ORDER BY (Codigo LIKE :t4) DESC, Codigo ASC
             LIMIT :lim"
        );
        foreach ([":t", ":t2", ":t3", ":t4"] as $k) {
            $stmt->bindValue($k, $like);
        }
        $stmt->bindValue(":lim", $limit, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    $materiales = [];
    foreach ($rows as $r) {
        $mat = clm_consumible_salida($r);
        if ($mat["articulo"] !== "") {
            $materiales[] = $mat;
        }
    }

    echo json_encode([
        "success" => true,
        "mas_usados" => $masUsados,
        "materiales" => $materiales
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
