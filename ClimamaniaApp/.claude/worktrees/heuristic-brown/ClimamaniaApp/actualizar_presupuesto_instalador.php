<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";
require_once "presupuestos_api_common.php";

$API_KEY = "TEST123";
presup_require_api_key($API_KEY);

$idPresupuesto = (int)presup_request_value("id_presupuesto");
if ($idPresupuesto <= 0) {
    presup_json_exit(["success" => false, "message" => "id_presupuesto requerido"], 400);
}

$rol = presup_request_value("rol");
$usuario = presup_request_value("usuario");
$equipoRaw = presup_request_value("equipo");

$nombreClienteIn = presup_normalize_text(presup_request_value("nombre_cliente"), 255);
$direccionClienteIn = presup_normalize_text(presup_request_value("direccion_cliente"), 1000);
$telefonoIn = presup_normalize_text(presup_request_value("telefono"), 80);
$emailClienteInRaw = trim((string)presup_request_value("email_cliente"));
$lineasJsonRaw = trim((string)presup_request_value("lineas_json"));

// Compatibilidad: se aceptan pero se ignoran (se recalculan en servidor).
$unusedTotalSinIva = presup_request_value("total_sin_iva");
$unusedTotalIva = presup_request_value("total_iva");
$unusedTotalConIva = presup_request_value("total_con_iva");
unset($unusedTotalSinIva, $unusedTotalIva, $unusedTotalConIva);

if ($lineasJsonRaw === "") {
    presup_json_exit(["success" => false, "message" => "No hay lineas para guardar"], 400);
}

$lineas = presup_parse_lineas($lineasJsonRaw);
if (empty($lineas)) {
    presup_json_exit(["success" => false, "message" => "No hay lineas validas para guardar"], 400);
}

$pdo = null;
$pdfRelativePath = "";
$pdfAbsolutePath = "";

try {
    $pdo = getDBConnection();
    $psPdo = getPSConnection();
    $psPrefix = presup_resolve_ps_prefix($psPdo, isset($PS_DB_PREFIX) && $PS_DB_PREFIX !== "" ? $PS_DB_PREFIX : "ps_");
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
            EquipoInstaladores,
            UsuarioInstalador,
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

    $firmaRelativePath = presup_resolve_media_path((string)($row["FotoFirma"] ?? ""), $idPresupuesto, "firma");
    if ($firmaRelativePath === "") {
        presup_json_exit(["success" => false, "message" => "El presupuesto no tiene firma guardada"], 400);
    }

    $firmaAbsolutePath = presup_resolve_absolute_path($firmaRelativePath);
    if ($firmaAbsolutePath === "" || !is_file($firmaAbsolutePath)) {
        presup_json_exit(["success" => false, "message" => "No se ha encontrado la firma guardada"], 400);
    }

    $numeroPedido = presup_normalize_text((string)($row["NumeroPedido"] ?? ""), 64);
    $equipoInstaladores = presup_normalize_text((string)($row["EquipoInstaladores"] ?? ""), 100);
    $usuarioInstalador = presup_normalize_text((string)($row["UsuarioInstalador"] ?? ""), 100);

    $nombreCliente = $nombreClienteIn !== ""
        ? $nombreClienteIn
        : presup_normalize_text((string)($row["NombreCliente"] ?? ""), 255);
    if ($nombreCliente === "") {
        $nombreCliente = "Cliente";
    }

    $direccionCliente = $direccionClienteIn !== ""
        ? $direccionClienteIn
        : presup_normalize_text((string)($row["DireccionCliente"] ?? ""), 1000);
    $telefono = $telefonoIn !== ""
        ? $telefonoIn
        : presup_normalize_text((string)($row["Telefono"] ?? ""), 80);

    $isReferenciaPedido = $numeroPedido !== "" && !presup_is_manual_reference($numeroPedido);
    $emailPersistenciaActual = presup_normalize_email((string)($row["EmailCliente"] ?? ""));
    $emailEnvio = "";
    $emailPersistencia = $emailPersistenciaActual;

    if ($isReferenciaPedido) {
        $emailReferencia = presup_resolve_reference_customer_email($psPdo, $psPrefix, $numeroPedido);
        if ($emailReferencia !== "") {
            $emailEnvio = $emailReferencia;
            $emailPersistencia = $emailReferencia;
        } else {
            $emailTemporal = presup_normalize_email($emailClienteInRaw);
            if ($emailTemporal === "") {
                presup_json_exit([
                    "success" => false,
                    "message" => "Esta referencia no tiene email. Introduce uno para este envio"
                ], 400);
            }
            $emailEnvio = $emailTemporal;
            // Temporal: se conserva el valor previo de BD.
            $emailPersistencia = $emailPersistenciaActual;
        }
    } else {
        $emailManual = presup_normalize_email($emailClienteInRaw);
        if ($emailManual === "") {
            $emailManual = $emailPersistenciaActual;
        }
        if ($emailManual === "") {
            presup_json_exit([
                "success" => false,
                "message" => "Sin referencia debes indicar un email de cliente valido"
            ], 400);
        }
        $emailEnvio = $emailManual;
        $emailPersistencia = $emailManual;
    }

    $emailClienteForPdf = $emailEnvio !== "" ? $emailEnvio : $emailPersistencia;

    $totals = presup_calculate_totals($lineas);

    $pdo->beginTransaction();

    $updateHeader = $pdo->prepare(
        "UPDATE ClimaInstal_PresupuestosInstalador
         SET NombreCliente = :NombreCliente,
             DireccionCliente = :DireccionCliente,
             Telefono = :Telefono,
             EmailCliente = :EmailCliente,
             ImporteSinIva = :ImporteSinIva,
             ImporteIva = :ImporteIva,
             ImporteConIva = :ImporteConIva,
             FechaAceptacion = NOW(),
             date_upd = NOW()
         WHERE ID_Presupuesto = :ID_Presupuesto
         LIMIT 1"
    );
    $updateHeader->execute([
        ":NombreCliente" => $nombreCliente,
        ":DireccionCliente" => $direccionCliente,
        ":Telefono" => $telefono,
        ":EmailCliente" => $emailPersistencia,
        ":ImporteSinIva" => presup_format_decimal($totals["sin_iva"], 2),
        ":ImporteIva" => presup_format_decimal($totals["iva"], 2),
        ":ImporteConIva" => presup_format_decimal($totals["con_iva"], 2),
        ":ID_Presupuesto" => $idPresupuesto
    ]);

    $deleteLineas = $pdo->prepare(
        "DELETE FROM ClimaInstal_PresupuestosInstalador_Lineas
         WHERE ID_Presupuesto = :ID_Presupuesto"
    );
    $deleteLineas->execute([":ID_Presupuesto" => $idPresupuesto]);

    $insertLinea = $pdo->prepare(
        "INSERT INTO ClimaInstal_PresupuestosInstalador_Lineas
            (ID_Presupuesto, OrdenLinea, Cantidad, Articulo, Descripcion,
             PrecioUnitarioSinIva, PrecioTotalLinea, IvaPct, PrecioTotalLineaConIva,
             IvaFallback, date_add, date_upd)
         VALUES
            (:ID_Presupuesto, :OrdenLinea, :Cantidad, :Articulo, :Descripcion,
             :PrecioUnitarioSinIva, :PrecioTotalLinea, :IvaPct, :PrecioTotalLineaConIva,
             :IvaFallback, NOW(), NOW())"
    );

    $order = 1;
    foreach ($lineas as $linea) {
        $insertLinea->execute([
            ":ID_Presupuesto" => $idPresupuesto,
            ":OrdenLinea" => $order,
            ":Cantidad" => presup_format_decimal((float)$linea["cantidad"], 2),
            ":Articulo" => $linea["articulo"],
            ":Descripcion" => $linea["descripcion"],
            ":PrecioUnitarioSinIva" => presup_format_decimal((float)$linea["precio_unitario_sin_iva"], 6),
            ":PrecioTotalLinea" => presup_format_decimal((float)$linea["precio_total_linea"], 2),
            ":IvaPct" => presup_format_decimal((float)$linea["iva_pct"], 3),
            ":PrecioTotalLineaConIva" => presup_format_decimal((float)$linea["precio_total_linea_con_iva"], 2),
            ":IvaFallback" => !empty($linea["iva_fallback"]) ? 1 : 0
        ]);
        $order++;
    }

    $pdfData = presup_save_budget_pdf(
        $idPresupuesto,
        $numeroPedido,
        $nombreCliente,
        $direccionCliente,
        $telefono,
        $emailClienteForPdf,
        $usuarioInstalador,
        $equipoInstaladores,
        $lineas,
        $totals,
        $firmaRelativePath
    );
    $pdfRelativePath = $pdfData["relative_path"];
    $pdfAbsolutePath = $pdfData["absolute_path"];

    $updatePdf = $pdo->prepare(
        "UPDATE ClimaInstal_PresupuestosInstalador
         SET PdfPresupuesto = :PdfPresupuesto,
             date_upd = NOW()
         WHERE ID_Presupuesto = :ID_Presupuesto
         LIMIT 1"
    );
    $updatePdf->execute([
        ":PdfPresupuesto" => $pdfRelativePath,
        ":ID_Presupuesto" => $idPresupuesto
    ]);

    $pdo->commit();

    $destinatariosBcc = presup_fetch_bcc_destinations($pdo);
    $asunto = "Presupuesto adicionales instalacion " . $numeroPedido;
    $body = presup_build_email_body(
        $idPresupuesto,
        $numeroPedido,
        $nombreCliente,
        $direccionCliente,
        $totals,
        $lineas
    );

    $mailError = "";
    $pdfPublicUrl = presup_build_public_url($pdfRelativePath);
    $mailSent = presup_send_mail_with_attachment(
        $emailEnvio,
        $destinatariosBcc,
        $asunto,
        $body,
        $pdfAbsolutePath,
        basename($pdfAbsolutePath),
        $pdfPublicUrl,
        $mailError
    );
    if (!$mailSent && $mailError === "") {
        $mailError = "No se pudo enviar el correo";
    }
    $mailErrorDb = ($mailSent && $mailError === "")
        ? null
        : presup_normalize_text($mailError, 500);

    try {
        $mailUpdate = $pdo->prepare(
            "UPDATE ClimaInstal_PresupuestosInstalador
             SET MailEnviado = :MailEnviado,
                 FechaEnvioMail = NOW(),
                 MailError = :MailError,
                 date_upd = NOW()
             WHERE ID_Presupuesto = :ID_Presupuesto
             LIMIT 1"
        );
        $mailUpdate->execute([
            ":MailEnviado" => $mailSent ? 1 : 0,
            ":MailError" => $mailErrorDb,
            ":ID_Presupuesto" => $idPresupuesto
        ]);
    } catch (Exception $ignored) {
        // No bloquear la respuesta por fallo al actualizar estado de correo.
    }

    presup_json_exit([
        "success" => true,
        "message" => $mailSent
            ? (
                $mailErrorDb === null || $mailErrorDb === ""
                    ? "Presupuesto actualizado y enviado correctamente"
                    : "Presupuesto actualizado y enviado con avisos: " . $mailErrorDb
            )
            : "Presupuesto actualizado, pero no se pudo enviar el correo"
                . ($mailErrorDb !== null && $mailErrorDb !== "" ? ": " . $mailErrorDb : ""),
        "id_presupuesto" => $idPresupuesto,
        "pdf" => $pdfRelativePath,
        "pdf_url" => presup_build_public_url($pdfRelativePath),
        "mail_enviado" => $mailSent,
        "mail_error" => $mailErrorDb ?? ""
    ]);
} catch (Exception $e) {
    if ($pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }

    presup_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}
