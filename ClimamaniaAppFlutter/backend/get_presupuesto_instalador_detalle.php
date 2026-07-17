<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";
require_once __DIR__ . "/presupuestos_api_common.php";

$API_KEY = "TEST123";
presup_require_api_key($API_KEY);

$idPresupuesto = (int)presup_request_value("id_presupuesto");
if ($idPresupuesto <= 0) {
    presup_json_exit(["success" => false, "message" => "id_presupuesto requerido"], 400);
}

$rol = presup_request_value("rol");
$usuario = presup_request_value("usuario");
$equipoRaw = presup_request_value("equipo");

try {
    $pdo = getDBConnection();
    $isAdmin = presup_is_admin_role($rol);

    $stmt = $pdo->prepare(
        "SELECT
            ID_Presupuesto,
            NumeroPedido,
            NombreCliente,
            DireccionCliente,
            Telefono,
            EmailCliente,
            FotoFirma,
            PdfPresupuesto,
            FechaPresupuesto,
            FechaAceptacion,
            EquipoInstaladores,
            UsuarioInstalador,
            ImporteSinIva,
            ImporteIva,
            ImporteConIva,
            Estado,
            Origen,
            FechaEnvioMail,
            MailEnviado,
            MailError,
            date_add,
            date_upd
         FROM ClimaInstal_PresupuestosInstalador
         WHERE ID_Presupuesto = :id
         LIMIT 1"
    );
    $stmt->execute([":id" => $idPresupuesto]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        presup_json_exit(["success" => false, "message" => "Presupuesto no encontrado"], 404);
    }

    $equipoResolved = presup_resolve_equipo_raw($pdo, $equipoRaw, $usuario);
    $scopeTokens = presup_split_tokens($equipoResolved);
    $usuarioNorm = strtolower(trim($usuario));

    $visible = presup_row_visible_for_scope(
        (string)($row["EquipoInstaladores"] ?? ""),
        (string)($row["UsuarioInstalador"] ?? ""),
        $isAdmin,
        $scopeTokens,
        $usuarioNorm
    );

    if (!$visible) {
        presup_json_exit(["success" => false, "message" => "Sin permiso para este presupuesto"], 403);
    }

    $canEdit = presup_can_edit($isAdmin, (string)($row["UsuarioInstalador"] ?? ""), $usuario);

    $stmtLineas = $pdo->prepare(
        "SELECT
            ID_Linea,
            ID_Presupuesto,
            OrdenLinea,
            Cantidad,
            Articulo,
            Descripcion,
            PrecioUnitarioSinIva,
            PrecioTotalLinea,
            IvaPct,
            PrecioTotalLineaConIva,
            IvaFallback,
            date_add,
            date_upd
         FROM ClimaInstal_PresupuestosInstalador_Lineas
         WHERE ID_Presupuesto = :id
         ORDER BY OrdenLinea ASC, ID_Linea ASC"
    );
    $stmtLineas->execute([":id" => $idPresupuesto]);

    $lineas = [];
    foreach ($stmtLineas->fetchAll(PDO::FETCH_ASSOC) as $ln) {
        $lineas[] = [
            "id_linea" => (int)($ln["ID_Linea"] ?? 0),
            "id_presupuesto" => (int)($ln["ID_Presupuesto"] ?? 0),
            "orden_linea" => (int)($ln["OrdenLinea"] ?? 0),
            "cantidad" => presup_format_decimal((float)($ln["Cantidad"] ?? 0), 2),
            "articulo" => presup_normalize_text((string)($ln["Articulo"] ?? ""), 120),
            "descripcion" => presup_normalize_text((string)($ln["Descripcion"] ?? ""), 4000),
            "precio_unitario_sin_iva" => presup_format_decimal((float)($ln["PrecioUnitarioSinIva"] ?? 0), 6),
            "precio_total_linea" => presup_format_decimal((float)($ln["PrecioTotalLinea"] ?? 0), 2),
            "iva_pct" => presup_format_decimal((float)($ln["IvaPct"] ?? 0), 3),
            "precio_total_linea_con_iva" => presup_format_decimal((float)($ln["PrecioTotalLineaConIva"] ?? 0), 2),
            "iva_fallback" => ((int)($ln["IvaFallback"] ?? 0)) === 1,
            "date_add" => presup_normalize_text((string)($ln["date_add"] ?? ""), 30),
            "date_upd" => presup_normalize_text((string)($ln["date_upd"] ?? ""), 30)
        ];
    }

    $firma = presup_resolve_media_path((string)($row["FotoFirma"] ?? ""), $idPresupuesto, "firma");
    $pdf = presup_resolve_media_path((string)($row["PdfPresupuesto"] ?? ""), $idPresupuesto, "pdf");

    $presupuesto = [
        "id_presupuesto" => (int)($row["ID_Presupuesto"] ?? 0),
        "numero_pedido" => presup_normalize_text((string)($row["NumeroPedido"] ?? ""), 64),
        "nombre_cliente" => presup_normalize_text((string)($row["NombreCliente"] ?? ""), 255),
        "direccion_cliente" => presup_normalize_text((string)($row["DireccionCliente"] ?? ""), 1000),
        "telefono" => presup_normalize_text((string)($row["Telefono"] ?? ""), 80),
        "email_cliente" => presup_normalize_text((string)($row["EmailCliente"] ?? ""), 255),
        "foto_firma" => $firma,
        "foto_firma_url" => presup_build_public_url($firma),
        "pdf" => $pdf,
        "pdf_url" => presup_build_public_url($pdf),
        "fecha_presupuesto" => presup_normalize_text((string)($row["FechaPresupuesto"] ?? ""), 30),
        "fecha_aceptacion" => presup_normalize_text((string)($row["FechaAceptacion"] ?? ""), 30),
        "equipo_instaladores" => presup_normalize_text((string)($row["EquipoInstaladores"] ?? ""), 100),
        "usuario_instalador" => presup_normalize_text((string)($row["UsuarioInstalador"] ?? ""), 100),
        "importe_sin_iva" => presup_format_decimal((float)($row["ImporteSinIva"] ?? 0), 2),
        "importe_iva" => presup_format_decimal((float)($row["ImporteIva"] ?? 0), 2),
        "importe_con_iva" => presup_format_decimal((float)($row["ImporteConIva"] ?? 0), 2),
        "estado" => presup_normalize_text((string)($row["Estado"] ?? ""), 40),
        "origen" => presup_normalize_text((string)($row["Origen"] ?? ""), 40),
        "fecha_envio_mail" => presup_normalize_text((string)($row["FechaEnvioMail"] ?? ""), 30),
        "mail_enviado" => ((int)($row["MailEnviado"] ?? 0)) === 1,
        "mail_error" => presup_normalize_text((string)($row["MailError"] ?? ""), 500),
        "date_add" => presup_normalize_text((string)($row["date_add"] ?? ""), 30),
        "date_upd" => presup_normalize_text((string)($row["date_upd"] ?? ""), 30)
    ];

    presup_json_exit([
        "success" => true,
        "presupuesto" => $presupuesto,
        "lineas" => $lineas,
        "can_edit" => $canEdit
    ]);
} catch (Exception $e) {
    presup_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}
