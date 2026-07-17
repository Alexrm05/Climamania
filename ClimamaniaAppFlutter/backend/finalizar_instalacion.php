<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/visitas_api_common.php";
require_once __DIR__ . "/ubicaciones_eventos_common.php";

$API_KEY = "TEST123";

$apiKey = $_POST["api_key"] ?? ($_GET["api_key"] ?? "");
if ($apiKey !== $API_KEY) {
    echo json_encode(["success" => false, "message" => "API key invalida"]);
    exit;
}

$referencia = trim($_POST["referencia"] ?? "");
$usuario = trim($_POST["usuario"] ?? "");
$cobroMetalico = trim($_POST["cobroMetalico"] ?? "");
$cobroVisa = trim($_POST["cobroVisa"] ?? "");
$extras = trim($_POST["extras"] ?? "");
$satisfaccion = trim($_POST["satisfaccion"] ?? "");
$observaciones = trim($_POST["observaciones"] ?? "");

if ($referencia === "" || $usuario === "") {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Faltan datos"]);
    exit;
}

try {
    $pdo = getDBConnection();
    $pdo->beginTransaction();

    $stmt = $pdo->prepare(
        "SELECT COUNT(*) AS total
         FROM ClimaInstal_Finalizadas
         WHERE referencia = :ref"
    );
    $stmt->execute([":ref" => $referencia]);
    $count = (int)($stmt->fetchColumn() ?? 0);

    $registroActualizado = false;
    if ($count > 0) {
        $stmt = $pdo->prepare(
            "UPDATE ClimaInstal_Finalizadas
             SET Usuario = :usuario,
                 Fecha = NOW(),
                 CobroMetalico = :cobroMetalico,
                 CobroVisa = :cobroVisa,
                 Extras = :extras,
                 SatisfaccionCliente = :satisfaccion,
                 Observaciones = :observaciones
             WHERE referencia = :ref"
        );
        $stmt->execute([
            ":ref" => $referencia,
            ":usuario" => $usuario,
            ":cobroMetalico" => normalizeMoney($cobroMetalico),
            ":cobroVisa" => normalizeMoney($cobroVisa),
            ":extras" => $extras,
            ":satisfaccion" => $satisfaccion,
            ":observaciones" => $observaciones
        ]);
        $registroActualizado = true;
    } else {
        $stmt = $pdo->prepare(
            "INSERT INTO ClimaInstal_Finalizadas
                (referencia, Usuario, Fecha, CobroMetalico, CobroVisa, Extras, SatisfaccionCliente, Observaciones)
             VALUES
                (:ref, :usuario, NOW(), :cobroMetalico, :cobroVisa, :extras, :satisfaccion, :observaciones)"
        );
        $stmt->execute([
            ":ref" => $referencia,
            ":usuario" => $usuario,
            ":cobroMetalico" => normalizeMoney($cobroMetalico),
            ":cobroVisa" => normalizeMoney($cobroVisa),
            ":extras" => $extras,
            ":satisfaccion" => $satisfaccion,
            ":observaciones" => $observaciones
        ]);
    }

    $stmt = $pdo->prepare(
        "UPDATE ClimaInstal_events
         SET estado = 'finalizado'
         WHERE referencia = :ref"
    );
    $stmt->execute([":ref" => $referencia]);

    clm_eventos_insert_location_event($pdo, [
        "referencia" => $referencia,
        "tipo_evento" => "FINALIZACION_INSTALACION",
        "latitud" => $_POST["latitud"] ?? ($_GET["latitud"] ?? ""),
        "longitud" => $_POST["longitud"] ?? ($_GET["longitud"] ?? ""),
        "usuario" => $usuario,
        "origen" => "APP_ANDROID"
    ]);

    $pdo->commit();

    $destinatarios = obtenerDestinatariosFinalizacion($pdo);
    $mailError = "";
    $mailOk = enviarCorreoFinalizado(
        $destinatarios,
        $referencia,
        $usuario,
        $cobroMetalico,
        $cobroVisa,
        $extras,
        $satisfaccion,
        $observaciones,
        $mailError
    );
    $response = [
        "success" => true,
        "message" => $registroActualizado
            ? "Instalación finalizada (actualizada)"
            : "Instalación finalizada",
        "finalizacion_actualizada" => $registroActualizado,
        "mail_enviado" => $mailOk,
        "mail_destinatarios" => $destinatarios
    ];

    if (!$mailOk) {
        $suffix = $mailError !== "" ? (": " . $mailError) : "";
        $response["message"] = "Instalación finalizada (correo no enviado" . $suffix . ")";
        $response["mail_error"] = $mailError;
    }

    $jsonFlags = JSON_UNESCAPED_UNICODE;
    if (defined("JSON_INVALID_UTF8_SUBSTITUTE")) {
        $jsonFlags |= JSON_INVALID_UTF8_SUBSTITUTE;
    }
    echo json_encode($response, $jsonFlags);
} catch (Exception $e) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ]);
}

function normalizeMoney(string $value)
{
    $normalized = trim(str_replace(",", ".", $value));
    return $normalized === "" ? null : $normalized;
}

function obtenerDestinatariosFinalizacion(PDO $pdo): array
{
    $ordered = [
        "emailGerencia",
        "emailCompras",
        "emailFacturacion",
        "emailMarketing",
        "emailGenerico"
    ];

    $emails = [];
    foreach (visitas_collect_variable_emails($pdo, $ordered) as $mail) {
        $emails[$mail] = true;
    }

    if (empty($emails)) {
        $emails["climamania@climamania.com"] = true;
    }

    return array_keys($emails);
}

function enviarCorreoFinalizado(
    array $destinatarios,
    string $referencia,
    string $usuario,
    string $cobroMetalico,
    string $cobroVisa,
    string $extras,
    string $satisfaccion,
    string $observaciones,
    string &$mailError = ""
): bool
{
    $mailError = "";
    $toList = [];
    foreach ($destinatarios as $email) {
        $clean = trim((string)$email);
        if ($clean !== "" && filter_var($clean, FILTER_VALIDATE_EMAIL)) {
            $toList[$clean] = true;
        }
    }
    if (empty($toList)) {
        $mailError = "No hay destinatarios válidos";
        return false;
    }

    $subject = "Comunicacion Instalacion Finalizada";
    $encodedSubject = "=?UTF-8?B?" . base64_encode($subject) . "?=";

    $cobroMetalicoText = $cobroMetalico === "" ? "0" : str_replace(",", ".", $cobroMetalico);
    $cobroVisaText = $cobroVisa === "" ? "0" : str_replace(",", ".", $cobroVisa);
    $extrasText = $extras === "" ? "no" : $extras;
    $satisfaccionText = $satisfaccion === "" ? "N/D" : $satisfaccion;
    $observacionesText = trim($observaciones) === "" ? "-" : trim($observaciones);

    $usuarioSafe = finalizar_escape_html($usuario);
    $referenciaSafe = finalizar_escape_html($referencia);
    $cobroMetalicoSafe = finalizar_escape_html($cobroMetalicoText);
    $cobroVisaSafe = finalizar_escape_html($cobroVisaText);
    $extrasSafe = finalizar_escape_html($extrasText);
    $satisfaccionSafe = finalizar_escape_html($satisfaccionText);
    $observacionesSafe = nl2br(finalizar_escape_html($observacionesText), false);

    $bodyText = $usuario . " ha finalizado una instalacion con los siguientes datos:\n\n"
        . "Referencia de la Instalación: " . $referencia . ".\n\n"
        . "Cobrado en metálico: " . $cobroMetalicoText . " €.\n\n"
        . "Cobrado con VISA: " . $cobroVisaText . " €.\n\n"
        . "¿Ha habido extras?: " . $extrasText . "\n\n"
        . "Percepción de Satisfacción del cliente: " . $satisfaccionText . "\n\n"
        . "Observaciones: " . $observacionesText . "\n\n"
        . "Este es un email automático. No respondas porque no será atendido.";

    $bodyHtml = "<!doctype html><html><body style=\"font-family:Arial,Helvetica,sans-serif;color:#111;\">"
        . "<p>" . $usuarioSafe . " ha <span style=\"background:#FFF59D;\">finalizado</span> una instalacion con los siguientes datos:</p>"
        . "<p>Referencia de la Instalación: " . $referenciaSafe . ".</p>"
        . "<p>Cobrado en metálico: " . $cobroMetalicoSafe . " €.</p>"
        . "<p>Cobrado con VISA: " . $cobroVisaSafe . " €.</p>"
        . "<p>¿Ha habido extras?: " . $extrasSafe . "</p>"
        . "<p>Percepción de Satisfacción del cliente: " . $satisfaccionSafe . "</p>"
        . "<p>Observaciones: " . $observacionesSafe . "</p>"
        . "<p>Este es un email automático. No respondas porque no será atendido.</p>"
        . "</body></html>";

    $from = "climamania@climamania.com";
    $boundary = "=_Finalizacion_" . md5(uniqid((string)mt_rand(), true));
    $headers = [];
    $headers[] = "From: ClimaMania Instalaciones <{$from}>";
    $headers[] = "Reply-To: climamania@climamania.com";
    $headers[] = "X-Mailer: PHP/" . PHP_VERSION;
    $headers[] = "MIME-Version: 1.0";
    $headers[] = "Date: " . date(DATE_RFC2822);
    $headers[] = "Content-Type: multipart/alternative; boundary=\"" . $boundary . "\"";
    $headersString = implode("\r\n", $headers);

    $message = "";
    $message .= "--" . $boundary . "\r\n";
    $message .= "Content-Type: text/plain; charset=UTF-8\r\n";
    $message .= "Content-Transfer-Encoding: quoted-printable\r\n\r\n";
    $message .= finalizar_encode_mail_body($bodyText) . "\r\n\r\n";
    $message .= "--" . $boundary . "\r\n";
    $message .= "Content-Type: text/html; charset=UTF-8\r\n";
    $message .= "Content-Transfer-Encoding: quoted-printable\r\n\r\n";
    $message .= finalizar_encode_mail_body($bodyHtml) . "\r\n\r\n";
    $message .= "--" . $boundary . "--\r\n";

    $sent = 0;
    $total = count($toList);
    $okRecipients = [];
    $errors = [];

    foreach (array_keys($toList) as $to) {
        $attempts = [];
        $try = finalizar_try_mail($to, $encodedSubject, $message, $headersString, "-f " . $from);
        if ($try["ok"]) {
            $sent++;
            $okRecipients[] = $to;
            continue;
        }
        if ($try["error"] !== "") {
            $attempts[] = "-f: " . $try["error"];
        }

        $try = finalizar_try_mail($to, $encodedSubject, $message, $headersString, "");
        if ($try["ok"]) {
            $sent++;
            $okRecipients[] = $to;
            continue;
        }
        if ($try["error"] !== "") {
            $attempts[] = "sin-f: " . $try["error"];
        }

        if (empty($attempts)) {
            $errors[] = $to . " => mail() devolvio false";
        } else {
            $errors[] = $to . " => " . implode(" | ", $attempts);
        }
    }

    if ($sent === $total) {
        return true;
    }

    if ($sent > 0) {
        $mailError = "envío parcial (" . $sent . "/" . $total . ")"
            . " OK: " . implode(", ", $okRecipients)
            . " | FAIL: " . implode(" || ", $errors);
        error_log("[finalizar_instalacion_mail] " . $mailError);
        return false;
    }

    $mailError = "no se pudo enviar a ningún destinatario: " . implode(" || ", $errors);
    error_log("[finalizar_instalacion_mail] " . $mailError);
    return false;
}

function finalizar_try_mail(
    string $to,
    string $subject,
    string $message,
    string $headers,
    string $additionalParams
): array {
    if (function_exists("error_clear_last")) {
        error_clear_last();
    }

    if ($additionalParams !== "") {
        $ok = @mail($to, $subject, $message, $headers, $additionalParams);
    } else {
        $ok = @mail($to, $subject, $message, $headers);
    }

    $err = "";
    $last = error_get_last();
    if (is_array($last) && isset($last["message"])) {
        $err = trim((string)$last["message"]);
    }

    return [
        "ok" => (bool)$ok,
        "error" => $err
    ];
}

function finalizar_encode_mail_body(string $content): string
{
    if ($content === "") {
        return "";
    }
    if (function_exists("quoted_printable_encode")) {
        return quoted_printable_encode($content);
    }

    $normalized = preg_replace("/\r\n|\r|\n/", "\r\n", $content);
    return wordwrap((string)$normalized, 73, "=\r\n", true);
}

function finalizar_escape_html(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
}
