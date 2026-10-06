<?php
// Pedidos de consumibles que ha hecho el instalador: solo consulta.
//
// Una vez enviado, el pedido no se puede modificar desde la app: esto es
// únicamente para que el instalador vea lo que pidió y en qué estado está.
// Cada usuario ve lo suyo; con rol de administrador se ven todos.
//
// GET: api_key, usuario, rol (opcional), desde / hasta (YYYY-MM-DD, opcional),
//      limite (por defecto 50)

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";

$API_KEY = "TEST123";

if (!isset($_GET["api_key"]) || $_GET["api_key"] !== $API_KEY) {
    echo json_encode(["success" => false, "message" => "API key invalida"]);
    exit;
}

$usuario = trim((string)($_GET["usuario"] ?? ""));
$rol = strtolower(trim((string)($_GET["rol"] ?? "")));
$limite = (int)($_GET["limite"] ?? 50);
if ($limite <= 0 || $limite > 200) {
    $limite = 50;
}
$esAdmin = in_array($rol, ["adminclm", "admin", "administrador"], true);

if ($usuario === "" && !$esAdmin) {
    echo json_encode(["success" => false, "message" => "Sesión no identificada"]);
    exit;
}

function pc_fecha(string $v): string
{
    $v = trim(substr($v, 0, 10));
    return preg_match('/^\d{4}-\d{2}-\d{2}$/', $v) ? $v : "";
}

$desde = pc_fecha((string)($_GET["desde"] ?? ""));
$hasta = pc_fecha((string)($_GET["hasta"] ?? ""));

try {
    $pdo = getDBConnection();

    $where = "1=1";
    $params = [];
    if (!$esAdmin) {
        $where .= " AND Usuario = :usuario";
        $params[":usuario"] = $usuario;
    }
    if ($desde !== "") {
        $where .= " AND FechaSolicitud >= :desde";
        $params[":desde"] = $desde . " 00:00:00";
    }
    if ($hasta !== "") {
        $where .= " AND FechaSolicitud <= :hasta";
        $params[":hasta"] = $hasta . " 23:59:59";
    }

    $stmt = $pdo->prepare(
        "SELECT Id, Referencia, FechaSolicitud, Usuario, NombreSolicitante,
                EmailSolicitante, Equipo, Observaciones, NumLineas, TotalSinIVA,
                Estado, EmailComprasEnviado, EmailConfirmacionEnviado
         FROM ClimaInstal_PedidosConsumibles
         WHERE $where
         ORDER BY FechaSolicitud DESC, Id DESC
         LIMIT " . $limite
    );
    $stmt->execute($params);
    $filas = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Las líneas de todos los pedidos en una sola consulta.
    $lineasPorPedido = [];
    if (!empty($filas)) {
        $ids = array_map(fn($r) => (int)$r["Id"], $filas);
        $ph = implode(",", array_fill(0, count($ids), "?"));
        $stmtL = $pdo->prepare(
            "SELECT IdPedido, Linea, Codigo, Descripcion, TextoFormato, UnidadVenta,
                    UnidadesPorFormato, CantidadFormatos, CantidadUnidades,
                    PrecioFormato, ImporteLinea
             FROM ClimaInstal_PedidosConsumibles_Lineas
             WHERE IdPedido IN ($ph)
             ORDER BY IdPedido ASC, Linea ASC"
        );
        $stmtL->execute($ids);
        foreach ($stmtL->fetchAll(PDO::FETCH_ASSOC) as $l) {
            $lineasPorPedido[(int)$l["IdPedido"]][] = [
                "linea" => (int)$l["Linea"],
                "codigo" => (string)$l["Codigo"],
                "descripcion" => (string)$l["Descripcion"],
                "texto_formato" => (string)$l["TextoFormato"],
                "unidad_venta" => (string)$l["UnidadVenta"],
                "cantidad_formatos" => number_format((float)$l["CantidadFormatos"], 2, ".", ""),
                "cantidad_unidades" => number_format((float)$l["CantidadUnidades"], 4, ".", ""),
                "precio_formato" => number_format((float)$l["PrecioFormato"], 2, ".", ""),
                "importe_linea" => number_format((float)$l["ImporteLinea"], 2, ".", "")
            ];
        }
    }

    $pedidos = [];
    foreach ($filas as $r) {
        $id = (int)$r["Id"];
        $pedidos[] = [
            "id" => $id,
            "referencia" => (string)$r["Referencia"],
            "fecha" => (string)$r["FechaSolicitud"],
            "usuario" => (string)$r["Usuario"],
            "nombre" => (string)$r["NombreSolicitante"],
            "email" => (string)$r["EmailSolicitante"],
            "equipo" => (string)$r["Equipo"],
            "observaciones" => (string)($r["Observaciones"] ?? ""),
            "num_lineas" => (int)$r["NumLineas"],
            "total_sin_iva" => number_format((float)$r["TotalSinIVA"], 2, ".", ""),
            "estado" => (string)$r["Estado"],
            "aviso_correo" => ((int)$r["EmailComprasEnviado"] !== 1
                || (int)$r["EmailConfirmacionEnviado"] !== 1),
            "lineas" => $lineasPorPedido[$id] ?? []
        ];
    }

    echo json_encode([
        "success" => true,
        "solo_usuario" => !$esAdmin,
        "pedidos" => $pedidos
    ], JSON_UNESCAPED_UNICODE);
} catch (PDOException $e) {
    if ($e->getCode() === "42S02") {
        echo json_encode([
            "success" => false,
            "message" => "Faltan las tablas de pedidos de consumibles."
        ]);
        exit;
    }
    echo json_encode(["success" => false, "message" => "ERROR: " . $e->getMessage()]);
} catch (Throwable $e) {
    echo json_encode(["success" => false, "message" => "ERROR: " . $e->getMessage()]);
}
