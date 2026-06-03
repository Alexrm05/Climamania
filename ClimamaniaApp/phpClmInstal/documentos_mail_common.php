<?php

require_once __DIR__ . "/boe_pdf_api_common.php";

function documentos_fetch_internal_destinations(PDO $pdo): array
{
    $ordered = ["emailCompras", "emailFacturacion", "emailGenerico"];
    $stmt = $pdo->query(
        "SELECT nombreVariable, valorVariable
         FROM variables_generales
         WHERE nombreVariable IN ('emailCompras', 'emailFacturacion', 'emailGenerico')"
    );

    $map = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $name = trim((string)($row["nombreVariable"] ?? ""));
        $value = (string)($row["valorVariable"] ?? "");
        if ($name !== "") {
            $map[$name] = $value;
        }
    }

    $emails = [];
    foreach ($ordered as $name) {
        $parsed = isset($map[$name]) ? presup_parse_email_values((string)$map[$name]) : [];
        if (empty($parsed)) {
            throw new RuntimeException("Falta configurar " . $name . " en variables_generales");
        }
        foreach ($parsed as $mail) {
            $emails[$mail] = true;
        }
    }

    return array_keys($emails);
}

function documentos_build_installation_email_body(
    string $referencia,
    string $nombreCliente,
    bool $requiereBoe
): string {
    $pedido = htmlspecialchars(presup_normalize_text($referencia, 120), ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
    $cliente = htmlspecialchars(presup_normalize_text($nombreCliente, 255), ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
    $boeLine = $requiereBoe
        ? "<li>Documento BOE debidamente rellenado y firmado</li>"
        : "";

    return "<!doctype html><html><body style=\"font-family:Arial,Helvetica,sans-serif;color:#111;\">"
        . "<p>Adjuntamos la documentación generada para la instalación:</p>"
        . "<p style=\"margin:0 0 6px 0;\">Referencia: " . $pedido . "<br>"
        . "Cliente: " . $cliente . "</p>"
        . "<ul>"
        . "<li>Documento de conformidad firmado</li>"
        . $boeLine
        . "</ul>"
        . "<p style=\"margin-top:18px;\">Atentamente,<br><br>El equipo de ClimaMania</p>"
        . "</body></html>";
}

function documentos_send_mail_with_attachments(
    string $to,
    array $bcc,
    string $subject,
    string $body,
    array $attachments,
    string &$mailError = ""
): bool {
    $mailError = "";
    $fromAddress = "climamania@climamania.com";
    $replyTo = "climamania@climamania.com";
    $encodedSubject = "=?UTF-8?B?" . base64_encode($subject) . "?=";

    $recipients = [];
    foreach (presup_parse_email_values($to) as $email) {
        $recipients[$email] = true;
    }
    foreach ($bcc as $emailRaw) {
        foreach (presup_parse_email_values((string)$emailRaw) as $email) {
            $recipients[$email] = true;
        }
    }
    if (empty($recipients)) {
        $mailError = "No hay destinatarios de correo válidos";
        return false;
    }

    $preparedAttachments = [];
    foreach ($attachments as $attachment) {
        if (!is_array($attachment)) {
            continue;
        }
        $path = (string)($attachment["path"] ?? "");
        $name = trim((string)($attachment["name"] ?? ""));
        if ($path === "" || $name === "" || !is_file($path) || !is_readable($path)) {
            $mailError = "Falta un adjunto obligatorio para el envío";
            return false;
        }
        $data = @file_get_contents($path);
        if (!is_string($data) || $data === "") {
            $mailError = "No se pudo leer un adjunto obligatorio";
            return false;
        }
        $preparedAttachments[] = [
            "name" => $name,
            "data" => chunk_split(base64_encode($data))
        ];
    }
    if (empty($preparedAttachments)) {
        $mailError = "No hay adjuntos para enviar";
        return false;
    }

    $boundary = "=_Part_" . md5(uniqid((string)mt_rand(), true));
    $headers = [];
    $headers[] = "From: ClimaMania Instalaciones <" . $fromAddress . ">";
    $headers[] = "Reply-To: " . $replyTo;
    $headers[] = "X-Mailer: PHP/" . PHP_VERSION;
    $headers[] = "MIME-Version: 1.0";
    $headers[] = "Content-Type: multipart/mixed; boundary=\"" . $boundary . "\"";
    $headersString = implode("\r\n", $headers);

    $message = "";
    $message .= "--" . $boundary . "\r\n";
    $message .= "Content-Type: text/html; charset=UTF-8\r\n";
    $message .= "Content-Transfer-Encoding: quoted-printable\r\n\r\n";
    $message .= presup_encode_mail_html_body($body) . "\r\n\r\n";

    foreach ($preparedAttachments as $attachment) {
        $message .= "--" . $boundary . "\r\n";
        $message .= "Content-Type: application/pdf; name=\"" . $attachment["name"] . "\"\r\n";
        $message .= "Content-Transfer-Encoding: base64\r\n";
        $message .= "Content-Disposition: attachment; filename=\"" . $attachment["name"] . "\"\r\n\r\n";
        $message .= $attachment["data"] . "\r\n";
    }
    $message .= "--" . $boundary . "--\r\n";

    $sent = 0;
    $totalRecipients = count($recipients);
    $okRecipients = [];
    $errors = [];
    foreach (array_keys($recipients) as $recipient) {
        $recipientAttempts = [];
        $delivered = false;

        $attempt = presup_try_mail_call(
            $recipient,
            $encodedSubject,
            $message,
            $headersString,
            "-f " . $fromAddress
        );
        if ($attempt["ok"]) {
            $delivered = true;
        } elseif ($attempt["error"] !== "") {
            $recipientAttempts[] = "adjunto/-f: " . $attempt["error"];
        }

        if (!$delivered) {
            $attempt = presup_try_mail_call(
                $recipient,
                $encodedSubject,
                $message,
                $headersString,
                ""
            );
            if ($attempt["ok"]) {
                $delivered = true;
            } elseif ($attempt["error"] !== "") {
                $recipientAttempts[] = "adjunto/sin-f: " . $attempt["error"];
            }
        }

        if ($delivered) {
            $sent++;
            $okRecipients[] = $recipient;
            continue;
        }

        $errors[] = $recipient . " => "
            . (empty($recipientAttempts) ? "mail() devolvió false en todos los intentos" : implode(" | ", $recipientAttempts));
    }

    if ($sent === $totalRecipients) {
        return true;
    }
    if ($sent > 0) {
        $okList = empty($okRecipients) ? "-" : implode(", ", $okRecipients);
        $mailError = "Parcial (" . $sent . "/" . $totalRecipients . ") OK=[" . $okList . "]"
            . (empty($errors) ? "" : " FAIL=" . implode(" || ", $errors));
        return false;
    }

    $mailError = empty($errors)
        ? "mail() devolvió false en todos los intentos"
        : implode(" || ", $errors);
    return false;
}
