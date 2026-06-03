<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";
require_once "visitas_api_common.php";

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

    $stmt = $pdo->prepare(
        "SELECT COUNT(*) AS total
         FROM ClimaInstal_Finalizadas
         WHERE referencia = :ref"
    );
    $stmt->execute([":ref" => $referencia]);
    $count = (int)($stmt->fetchColumn() ?? 0);

    if ($count > 0) {
        echo json_encode(["success" => true, "message" => "Instalación ya finalizada"]);
        exit;
    }

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

    $stmt = $pdo->prepare(
        "UPDATE ClimaInstal_events
         SET estado = 'finalizado'
         WHERE referencia = :ref"
    );
    $stmt->execute([":ref" => $referencia]);

    $destinatarios = obtenerDestinatariosFinalizacion($pdo);
    $mailOk = enviarCorreoFinalizado(
        $destinatarios,
        $referencia,
        $usuario,
        $cobroMetalico,
        $cobroVisa,
        $extras,
        $satisfaccion,
        $observaciones
    );
    if ($mailOk) {
        echo json_encode(["success" => true, "message" => "Instalación finalizada"]);
    } else {
        echo json_encode([
            "success" => true,
            "message" => "Instalación finalizada (correo no enviado)"
        ]);
    }
} catch (Exception $e) {
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
    $variables = [
        "emailCompras",
        "emailGenerico",
        "emailFacturacion",
        "emailGerencia",
        "emailMarketing"
    ];

    $destinatarios = visitas_collect_variable_emails($pdo, $variables);
    if (empty($destinatarios)) {
        $destinatarios[] = "climamania@climamania.com";
    }

    return $destinatarios;
}

function enviarCorreoFinalizado(
    array $destinatarios,
    string $referencia,
    string $usuario,
    string $cobroMetalico,
    string $cobroVisa,
    string $extras,
    string $satisfaccion,
    string $observaciones
): bool
{
    $toList = [];
    foreach ($destinatarios as $email) {
        $clean = trim((string)$email);
        if ($clean !== "") {
            $toList[$clean] = true;
        }
    }
    if (empty($toList)) {
        return false;
    }

    $subject = "Comunicación Instalación Finalizada";

    $cobroMetalicoText = $cobroMetalico === "" ? "0" : $cobroMetalico;
    $cobroVisaText = $cobroVisa === "" ? "0" : $cobroVisa;
    $extrasText = $extras === "" ? "no" : $extras;
    $satisfaccionText = $satisfaccion === "" ? "" : $satisfaccion;
    $observacionesText = $observaciones === "" ? "" : $observaciones;

    $body = $usuario . " ha finalizado una instalacion con los siguientes datos:\n\n"
        . "Referencia de la Instalación: " . $referencia . ".\n\n"
        . "Cobrado en metálico: " . $cobroMetalicoText . " €.\n\n"
        . "Cobrado con VISA: " . $cobroVisaText . " €.\n\n"
        . "¿Ha habido extras?: " . $extrasText . "\n\n"
        . "Percepción de Satisfacción del cliente: " . $satisfaccionText . "\n\n"
        . "Observaciones: " . $observacionesText . "\n\n"
        . "Este es un email automático. No respondas porque no será atendido.";
    $from = "climamania@climamania.com";
    $headers = "From: ClimaMania Instalaciones <{$from}>\r\n"
        . "Reply-To: climamania@climamania.com\r\n"
        . "MIME-Version: 1.0\r\n"
        . "Content-Type: text/plain; charset=UTF-8\r\n";
    $toCsv = implode(",", array_keys($toList));

    $ok = @mail($toCsv, $subject, $body, $headers, "-f {$from}");
    if (!$ok) {
        $ok = @mail($toCsv, $subject, $body, $headers);
    }
    return $ok;
}
