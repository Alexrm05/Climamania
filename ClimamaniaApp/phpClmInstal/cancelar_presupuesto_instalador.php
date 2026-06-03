<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";
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
            PdfPresupuesto,
            FechaPresupuesto,
            EquipoInstaladores,
            UsuarioInstalador,
            ImporteConIva,
            Estado
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
    if (!$canEdit) {
        presup_json_exit(["success" => false, "message" => "Sin permiso de edición"], 403);
    }

    $estadoActual = strtoupper(presup_normalize_text((string)($row["Estado"] ?? ""), 40));
    if ($estadoActual === "CANCELADO") {
        presup_json_exit(["success" => false, "message" => "El presupuesto ya está cancelado"], 400);
    }

    $update = $pdo->prepare(
        "UPDATE ClimaInstal_PresupuestosInstalador
         SET Estado = 'CANCELADO',
             date_upd = NOW()
         WHERE ID_Presupuesto = :id
         LIMIT 1"
    );
    $update->execute([":id" => $idPresupuesto]);

    $numeroPedido = presup_normalize_text((string)($row["NumeroPedido"] ?? ""), 64);
    $nombreCliente = presup_normalize_text((string)($row["NombreCliente"] ?? ""), 255);
    $direccionCliente = presup_normalize_text((string)($row["DireccionCliente"] ?? ""), 1000);
    $telefono = presup_normalize_text((string)($row["Telefono"] ?? ""), 80);
    $equipoInstaladores = presup_normalize_text((string)($row["EquipoInstaladores"] ?? ""), 100);
    $usuarioInstalador = presup_normalize_text((string)($row["UsuarioInstalador"] ?? ""), 100);
    $importeConIva = presup_format_decimal((float)($row["ImporteConIva"] ?? 0), 2);
    $fechaPresupuesto = presup_normalize_text((string)($row["FechaPresupuesto"] ?? ""), 30);

    $destinatariosInternos = presup_fetch_bcc_destinations($pdo);
    $pdfRelativePath = presup_resolve_media_path((string)($row["PdfPresupuesto"] ?? ""), $idPresupuesto, "pdf");
    $pdfAbsolutePath = presup_resolve_absolute_path($pdfRelativePath);
    $pdfPublicUrl = presup_build_public_url($pdfRelativePath);
    $pdfAttachmentName = $pdfAbsolutePath !== "" ? basename($pdfAbsolutePath) : ("Pedido-" . $idPresupuesto . ".pdf");

    $subject = "Presupuesto de adicionales cancelado " . ($numeroPedido !== "" ? $numeroPedido : ("#" . $idPresupuesto));
    $body = presup_build_cancel_budget_email_body(
        $idPresupuesto,
        $numeroPedido,
        $nombreCliente,
        $direccionCliente,
        $telefono,
        $equipoInstaladores,
        $usuarioInstalador,
        $importeConIva,
        $fechaPresupuesto
    );

    $mailSent = false;
    $mailError = "";
    if (!empty($destinatariosInternos)) {
        $mailSent = presup_send_mail_with_attachment(
            "",
            $destinatariosInternos,
            $subject,
            $body,
            $pdfAbsolutePath,
            $pdfAttachmentName,
            $pdfPublicUrl,
            $mailError
        );
        if (!$mailSent && $mailError === "") {
            $mailError = "No se pudo enviar el correo interno";
        }
    } else {
        $mailError = "No hay destinatarios internos configurados";
    }

    $message = "Presupuesto cancelado";
    if (!$mailSent) {
        $message .= $mailError !== "" ? ". No se pudo enviar el email interno: " . $mailError : ". No se pudo enviar el email interno";
    }

    presup_json_exit([
        "success" => true,
        "message" => $message,
        "estado" => "CANCELADO",
        "mail_enviado_interno" => $mailSent,
        "mail_error_interno" => $mailError
    ]);
} catch (Exception $e) {
    presup_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}

function presup_build_cancel_budget_email_body(
    int $idPresupuesto,
    string $numeroPedido,
    string $nombreCliente,
    string $direccionCliente,
    string $telefono,
    string $equipoInstaladores,
    string $usuarioInstalador,
    string $importeConIva,
    string $fechaPresupuesto
): string {
    $id = htmlspecialchars((string)$idPresupuesto, ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
    $pedido = htmlspecialchars(presup_normalize_text($numeroPedido, 120), ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
    $cliente = htmlspecialchars(presup_normalize_text($nombreCliente, 255), ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
    $direccion = htmlspecialchars(presup_clean_text_for_mail($direccionCliente), ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
    $telefonoSafe = htmlspecialchars(presup_normalize_text($telefono, 80), ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
    $equipo = htmlspecialchars(presup_normalize_text($equipoInstaladores, 100), ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
    $usuario = htmlspecialchars(presup_normalize_text($usuarioInstalador, 100), ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
    $importe = htmlspecialchars((string)$importeConIva, ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
    $fecha = htmlspecialchars(presup_normalize_text($fechaPresupuesto, 40), ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");

    return "<html><body style=\"font-family:Arial,sans-serif;color:#1f2933;\">"
        . "<h2 style=\"margin-bottom:8px;\">Presupuesto de adicionales cancelado</h2>"
        . "<p>Se ha cancelado un presupuesto de adicionales desde la app.</p>"
        . "<table style=\"border-collapse:collapse;width:100%;max-width:720px;\">"
        . "<tr><td style=\"border:1px solid #d6d6d6;padding:8px;font-weight:bold;width:220px;\">ID presupuesto</td><td style=\"border:1px solid #d6d6d6;padding:8px;\">" . $id . "</td></tr>"
        . "<tr><td style=\"border:1px solid #d6d6d6;padding:8px;font-weight:bold;\">Pedido</td><td style=\"border:1px solid #d6d6d6;padding:8px;\">" . ($pedido !== "" ? $pedido : "N/D") . "</td></tr>"
        . "<tr><td style=\"border:1px solid #d6d6d6;padding:8px;font-weight:bold;\">Cliente</td><td style=\"border:1px solid #d6d6d6;padding:8px;\">" . ($cliente !== "" ? $cliente : "N/D") . "</td></tr>"
        . "<tr><td style=\"border:1px solid #d6d6d6;padding:8px;font-weight:bold;\">Dirección</td><td style=\"border:1px solid #d6d6d6;padding:8px;\">" . ($direccion !== "" ? nl2br($direccion) : "N/D") . "</td></tr>"
        . "<tr><td style=\"border:1px solid #d6d6d6;padding:8px;font-weight:bold;\">Teléfono</td><td style=\"border:1px solid #d6d6d6;padding:8px;\">" . ($telefonoSafe !== "" ? $telefonoSafe : "N/D") . "</td></tr>"
        . "<tr><td style=\"border:1px solid #d6d6d6;padding:8px;font-weight:bold;\">Equipo</td><td style=\"border:1px solid #d6d6d6;padding:8px;\">" . ($equipo !== "" ? $equipo : "N/D") . "</td></tr>"
        . "<tr><td style=\"border:1px solid #d6d6d6;padding:8px;font-weight:bold;\">Usuario instalador</td><td style=\"border:1px solid #d6d6d6;padding:8px;\">" . ($usuario !== "" ? $usuario : "N/D") . "</td></tr>"
        . "<tr><td style=\"border:1px solid #d6d6d6;padding:8px;font-weight:bold;\">Fecha presupuesto</td><td style=\"border:1px solid #d6d6d6;padding:8px;\">" . ($fecha !== "" ? $fecha : "N/D") . "</td></tr>"
        . "<tr><td style=\"border:1px solid #d6d6d6;padding:8px;font-weight:bold;\">Importe total</td><td style=\"border:1px solid #d6d6d6;padding:8px;\">" . ($importe !== "" ? $importe . " €" : "N/D") . "</td></tr>"
        . "<tr><td style=\"border:1px solid #d6d6d6;padding:8px;font-weight:bold;\">Estado</td><td style=\"border:1px solid #d6d6d6;padding:8px;\">CANCELADO</td></tr>"
        . "</table>"
        . "</body></html>";
}
