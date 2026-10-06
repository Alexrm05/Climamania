<?php
// Tarifa y pedidos de consumibles: formato de los artículos y correos.
//
// La tarifa sale de ClimaSinc_ClimaInstal_Consumibles (solo lectura). El
// pedido se registra en ClimaInstal_PedidosConsumibles y no toca PrestaShop,
// GOTEL ni ClimaGEST: solo graba y avisa por correo.

require_once __DIR__ . "/consumibles_common.php";
require_once __DIR__ . "/presupuestos_api_common.php";

/// Destinatario de los pedidos. Mientras se prueba va a jlrodriguez; para
/// pasarlo a compras basta con crear o editar la variable
/// 'emailPedidosConsumibles' en variables_generales, sin tocar código.
const CLM_PEDIDOS_EMAIL_PRUEBAS = "jlrodriguez@climamania.com";
const CLM_PEDIDOS_EMAIL_VARIABLE = "emailPedidosConsumibles";

function clm_pedidos_destino(PDO $pdo): string
{
    try {
        $stmt = $pdo->prepare(
            "SELECT valorVariable FROM variables_generales
              WHERE nombreVariable = :n LIMIT 1"
        );
        $stmt->execute([":n" => CLM_PEDIDOS_EMAIL_VARIABLE]);
        $v = (string)$stmt->fetchColumn();
        $emails = presup_parse_email_values($v);
        if (!empty($emails)) {
            return implode(",", $emails);
        }
    } catch (PDOException $e) {
        // Sin la variable (o sin la tabla) se usa el destino de pruebas.
    }
    return CLM_PEDIDOS_EMAIL_PRUEBAS;
}

function clm_num($v): float
{
    return (float)str_replace(",", ".", trim((string)($v ?? "0")));
}

/// Precio en formato español: 94 -> "94,00".
function clm_precio(float $v, int $dec = 2): string
{
    return number_format($v, $dec, ",", ".");
}

/// Cantidad sin decimales de relleno: 100 -> "100", 3.5 -> "3,5".
function clm_cantidad(float $v): string
{
    $s = number_format($v, 4, ",", "");
    $s = rtrim(rtrim($s, "0"), ",");
    return $s === "" ? "0" : $s;
}

/// Fila del catálogo -> artículo de la tarifa tal como lo pinta la app.
function clm_consumible_tarifa_salida(array $r): array
{
    $formato = clm_num($r["Formato"] ?? 1);
    $factor = clm_num($r["Factor"] ?? 1);
    $porFormato = ($formato > 0 ? $formato : 1) * ($factor > 0 ? $factor : 1);
    return [
        "id" => (int)($r["Id"] ?? 0),
        "id_gotel" => (int)($r["IdGotel"] ?? 0),
        "codigo" => trim((string)($r["Codigo"] ?? "")),
        "nombre" => trim((string)($r["Nombre"] ?? "")),
        "descripcion" => trim((string)($r["Descripcion"] ?? "")),
        "texto_formato" => trim((string)($r["TextoFormato"] ?? "")),
        "unidad_venta" => trim((string)($r["UnidadVenta"] ?? "")),
        "precio_formato" => number_format(clm_num($r["PVFormato"] ?? 0), 2, ".", ""),
        "precio_unidad" => number_format(clm_num($r["PVUnidad"] ?? 0), 4, ".", ""),
        "unidades_por_formato" => number_format($porFormato, 4, ".", ""),
        "foto_url" => trim((string)($r["FotoUrl"] ?? "")),
        "fecha_precios" => trim((string)($r["FechaPrecios"] ?? ""))
    ];
}

/// Datos del solicitante: nombre y correo salen de la ficha del usuario, y
/// si no tiene correo, del equipo.
function clm_pedidos_solicitante(PDO $pdo, string $usuario, string $equipo): array
{
    $out = ["nombre" => "", "email" => "", "equipo" => $equipo];
    try {
        $stmt = $pdo->prepare(
            "SELECT Nombre, Apellidos, email, EquipoInstaladores
             FROM ClimaInstal_Usuarios WHERE usuario = :u LIMIT 1"
        );
        $stmt->execute([":u" => $usuario]);
        $u = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($u) {
            $out["nombre"] = trim(trim((string)$u["Nombre"]) . " " . trim((string)$u["Apellidos"]));
            $out["email"] = presup_normalize_email((string)($u["email"] ?? ""));
            if ($out["equipo"] === "" || $out["equipo"] === "0") {
                $out["equipo"] = trim((string)($u["EquipoInstaladores"] ?? ""));
            }
        }
    } catch (PDOException $e) {
        // Sin ficha de usuario se sigue con lo que mandó la app.
    }
    if ($out["email"] === "" && $out["equipo"] !== "") {
        try {
            $stmt = $pdo->prepare(
                "SELECT email FROM ClimaInstal_EquiposInstaladores
                  WHERE nombre = :n LIMIT 1"
            );
            $stmt->execute([":n" => $out["equipo"]]);
            $out["email"] = presup_normalize_email((string)$stmt->fetchColumn());
        } catch (PDOException $e) {
            // El equipo tampoco tiene correo: se queda vacío.
        }
    }
    return $out;
}

/// Descripción del equipo (las personas), para el asunto del correo.
function clm_pedidos_equipo_descripcion(PDO $pdo, string $equipo): string
{
    if ($equipo === "") {
        return "";
    }
    try {
        $stmt = $pdo->prepare(
            "SELECT descripcion FROM ClimaInstal_EquiposInstaladores
              WHERE nombre = :n LIMIT 1"
        );
        $stmt->execute([":n" => $equipo]);
        return trim((string)$stmt->fetchColumn());
    } catch (PDOException $e) {
        return "";
    }
}

/// Cuerpo HTML del correo. [$intro] es el texto que va antes del detalle.
function clm_pedidos_cuerpo(array $cab, array $lineas, string $intro): string
{
    $e = fn($v) => htmlspecialchars((string)$v, ENT_QUOTES, "UTF-8");

    $filas = "";
    foreach ($lineas as $l) {
        $unidades = clm_cantidad((float)$l["cantidad_unidades"]) . " " . $e($l["unidad_venta"]);
        $filas .= "<tr>"
            . "<td style=\"padding:4px 8px;border:1px solid #ddd\">" . $e($l["codigo"]) . "</td>"
            . "<td style=\"padding:4px 8px;border:1px solid #ddd\">" . $e($l["descripcion"]) . "</td>"
            . "<td style=\"padding:4px 8px;border:1px solid #ddd\">" . $e($l["texto_formato"]) . "</td>"
            . "<td style=\"padding:4px 8px;border:1px solid #ddd;text-align:right\">"
            . clm_cantidad((float)$l["cantidad_formatos"]) . "</td>"
            . "<td style=\"padding:4px 8px;border:1px solid #ddd;text-align:right\">" . $unidades . "</td>"
            . "<td style=\"padding:4px 8px;border:1px solid #ddd;text-align:right\">"
            . clm_precio((float)$l["precio_formato"]) . " €</td>"
            . "<td style=\"padding:4px 8px;border:1px solid #ddd;text-align:right\">"
            . clm_precio((float)$l["importe_linea"]) . " €</td>"
            . "</tr>";
    }

    $obs = trim((string)($cab["observaciones"] ?? ""));
    $html = "<html><body style=\"font-family:Arial,Helvetica,sans-serif;font-size:14px;color:#222\">"
        . "<p>" . $e($intro) . "</p>"
        . "<p><b>Pedido:</b> " . $e($cab["referencia"]) . "<br>"
        . "<b>Fecha:</b> " . $e($cab["fecha"]) . "<br>"
        . "<b>Instalador:</b> " . $e($cab["nombre"]) . " (" . $e($cab["usuario"]) . ")<br>"
        . "<b>Equipo:</b> " . $e($cab["equipo"]) . "<br>"
        . "<b>Email:</b> " . $e($cab["email"]) . "</p>"
        . "<table style=\"border-collapse:collapse;font-size:13px\">"
        . "<tr style=\"background:#f3f3f3\">"
        . "<th style=\"padding:4px 8px;border:1px solid #ddd\">Código</th>"
        . "<th style=\"padding:4px 8px;border:1px solid #ddd\">Descripción</th>"
        . "<th style=\"padding:4px 8px;border:1px solid #ddd\">Formato</th>"
        . "<th style=\"padding:4px 8px;border:1px solid #ddd\">Cant.</th>"
        . "<th style=\"padding:4px 8px;border:1px solid #ddd\">Unidades</th>"
        . "<th style=\"padding:4px 8px;border:1px solid #ddd\">Precio formato</th>"
        . "<th style=\"padding:4px 8px;border:1px solid #ddd\">Importe</th>"
        . "</tr>" . $filas
        . "<tr><td colspan=\"6\" style=\"padding:6px 8px;text-align:right\"><b>Total estimado sin IVA</b></td>"
        . "<td style=\"padding:6px 8px;border:1px solid #ddd;text-align:right\"><b>"
        . clm_precio((float)$cab["total"]) . " €</b></td></tr>"
        . "</table>";
    if ($obs !== "") {
        $html .= "<p><b>Observaciones:</b><br>" . nl2br($e($obs)) . "</p>";
    }
    $html .= "<p style=\"color:#666;font-size:12px\">Precios sin IVA, orientativos."
        . " Los artículos con formato se piden por formato completo.</p>"
        . "</body></html>";
    return $html;
}

/// Envía un correo HTML sin adjuntos. Devuelve false y deja el motivo en
/// [$error] si no sale.
function clm_pedidos_enviar_mail(
    string $to,
    string $subject,
    string $html,
    string $replyTo,
    string &$error = ""
): bool {
    $error = "";
    $destinos = presup_parse_email_values($to);
    if (empty($destinos)) {
        $error = "No hay destinatario de correo válido";
        return false;
    }
    $from = "climamania@climamania.com";
    $headers = [
        "From: ClimaMania Instalaciones <" . $from . ">",
        "Reply-To: " . ($replyTo !== "" ? $replyTo : $from),
        "MIME-Version: 1.0",
        "Content-Type: text/html; charset=UTF-8",
        "Content-Transfer-Encoding: quoted-printable",
        "X-Mailer: PHP/" . PHP_VERSION
    ];
    $res = presup_try_mail_call(
        implode(",", $destinos),
        "=?UTF-8?B?" . base64_encode($subject) . "?=",
        presup_encode_mail_html_body($html),
        implode("\r\n", $headers),
        ""
    );
    if (!$res["ok"]) {
        $error = $res["error"] !== "" ? $res["error"] : "mail() devolvió false";
        return false;
    }
    return true;
}
