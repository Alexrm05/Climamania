<?php
// Escandallo: parte de trabajo (material consumido) de un pedido.
//
// Respuesta:
//   existe   -> true si el pedido ya tiene parte guardado
//   horas    -> hora_inicio / hora_final (HH:MM)
//   meta     -> usuario, equipo, fecha_creacion, fecha_edicion
//   lineas   -> filas guardadas (ref, descripción, unidad, prevista, real, precio)
//   defecto  -> materiales por defecto (ClimaInstal_ParteMateriales_Relacionados)
//               para precargar la tabla cuando aún no hay parte

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

$pedido = trim((string)($_GET["referencia"] ?? ($_GET["pedido"] ?? "")));
if ($pedido === "") {
    echo json_encode(["success" => false, "message" => "Referencia requerida"]);
    exit;
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
        "SELECT id, articulo, descripcion, unidad, cantidad_prevista, cantidad,
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

    $defecto = [];
    try {
        $stmtDef = $pdo->query(
            "SELECT articulo, descripcion, unidad, cantidad_prevista
             FROM ClimaInstal_ParteMateriales_Relacionados
             WHERE activo = 1
             ORDER BY orden ASC, id ASC"
        );
        foreach ($stmtDef->fetchAll(PDO::FETCH_ASSOC) as $d) {
            $defecto[] = [
                "articulo" => (string)$d["articulo"],
                "descripcion" => (string)$d["descripcion"],
                "unidad" => (string)$d["unidad"],
                "cantidad_prevista" => pm_dec($d["cantidad_prevista"]),
                "cantidad" => "0.00"
            ];
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
