<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";
require_once __DIR__ . "/presupuestos_api_common.php";

$API_KEY = "TEST123";
presup_require_api_key($API_KEY);

$rol = presup_request_value("rol");
$usuario = presup_request_value("usuario");
$equipoRaw = presup_request_value("equipo");
$q = presup_normalize_text(presup_request_value("q"), 120);
$estadoRaw = strtoupper(presup_normalize_text(presup_request_value("estado"), 40));

$page = (int)presup_request_value("page");
if ($page <= 0) {
    $page = 1;
}

$pageSize = (int)presup_request_value("page_size");
if ($pageSize <= 0) {
    $pageSize = 50;
}
if ($pageSize > 50) {
    $pageSize = 50;
}

try {
    $pdo = getDBConnection();
    $isAdmin = presup_is_admin_role($rol);

    $scopeParams = [];
    $scopeClause = presup_build_scope_clause_sql($pdo, $equipoRaw, $usuario, $isAdmin, $scopeParams);

    $where = [$scopeClause];
    $params = $scopeParams;

    if ($estadoRaw !== "" && $estadoRaw !== "TODOS") {
        $where[] = "UPPER(TRIM(Estado)) = :estado_filtro";
        $params[":estado_filtro"] = $estadoRaw;
    }

    if ($q !== "") {
        $where[] = "(CAST(ID_Presupuesto AS CHAR) LIKE :q
                OR NumeroPedido LIKE :q
                OR NombreCliente LIKE :q
                OR Telefono LIKE :q)";
        $params[":q"] = "%" . $q . "%";
    }

    $whereSql = implode(" AND ", $where);

    $sqlCount = "SELECT COUNT(*) AS total
                 FROM ClimaInstal_PresupuestosInstalador
                 WHERE " . $whereSql;
    $stmtCount = $pdo->prepare($sqlCount);
    $stmtCount->execute($params);
    $total = (int)($stmtCount->fetchColumn() ?? 0);

    $offset = ($page - 1) * $pageSize;

    $sqlList = "SELECT
                    ID_Presupuesto,
                    NumeroPedido,
                    NombreCliente,
                    Telefono,
                    EquipoInstaladores,
                    UsuarioInstalador,
                    ImporteConIva,
                    Estado,
                    FechaPresupuesto,
                    MailEnviado,
                    FechaEnvioMail,
                    PdfPresupuesto
                FROM ClimaInstal_PresupuestosInstalador
                WHERE " . $whereSql . "
                ORDER BY FechaPresupuesto DESC, ID_Presupuesto DESC
                LIMIT " . (int)$pageSize . " OFFSET " . (int)$offset;

    $stmtList = $pdo->prepare($sqlList);
    $stmtList->execute($params);
    $rows = $stmtList->fetchAll(PDO::FETCH_ASSOC);

    $sqlEstados = "SELECT DISTINCT TRIM(Estado) AS estado
                   FROM ClimaInstal_PresupuestosInstalador
                   WHERE " . $scopeClause . "
                     AND Estado IS NOT NULL
                     AND TRIM(Estado) <> ''
                   ORDER BY TRIM(Estado) ASC";
    $stmtEstados = $pdo->prepare($sqlEstados);
    $stmtEstados->execute($scopeParams);
    $estados = [];
    foreach ($stmtEstados->fetchAll(PDO::FETCH_ASSOC) as $st) {
        $estado = presup_normalize_text((string)($st["estado"] ?? ""), 40);
        if ($estado !== "") {
            $estados[$estado] = true;
        }
    }

    $presupuestos = [];
    foreach ($rows as $row) {
        $idPresupuestoRow = (int)($row["ID_Presupuesto"] ?? 0);
        $pdf = presup_resolve_media_path((string)($row["PdfPresupuesto"] ?? ""), $idPresupuestoRow, "pdf");
        $presupuestos[] = [
            "id_presupuesto" => $idPresupuestoRow,
            "numero_pedido" => presup_normalize_text((string)($row["NumeroPedido"] ?? ""), 64),
            "nombre_cliente" => presup_normalize_text((string)($row["NombreCliente"] ?? ""), 255),
            "telefono" => presup_normalize_text((string)($row["Telefono"] ?? ""), 80),
            "equipo_instaladores" => presup_normalize_text((string)($row["EquipoInstaladores"] ?? ""), 100),
            "usuario_instalador" => presup_normalize_text((string)($row["UsuarioInstalador"] ?? ""), 100),
            "importe_con_iva" => presup_format_decimal((float)($row["ImporteConIva"] ?? 0), 2),
            "estado" => presup_normalize_text((string)($row["Estado"] ?? ""), 40),
            "fecha_presupuesto" => presup_normalize_text((string)($row["FechaPresupuesto"] ?? ""), 30),
            "mail_enviado" => ((int)($row["MailEnviado"] ?? 0)) === 1,
            "fecha_envio_mail" => presup_normalize_text((string)($row["FechaEnvioMail"] ?? ""), 30),
            "pdf" => $pdf,
            "pdf_url" => presup_build_public_url($pdf)
        ];
    }

    $hasMore = ($offset + count($presupuestos)) < $total;

    presup_json_exit([
        "success" => true,
        "page" => $page,
        "page_size" => $pageSize,
        "total" => $total,
        "has_more" => $hasMore,
        "next_page" => $hasMore ? ($page + 1) : null,
        "estados_disponibles" => array_values(array_keys($estados)),
        "presupuestos" => $presupuestos
    ]);
} catch (Exception $e) {
    presup_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}
