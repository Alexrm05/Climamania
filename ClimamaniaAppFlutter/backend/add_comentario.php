<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";

$API_KEY = "TEST123";

$apiKey = $_POST["api_key"] ?? ($_GET["api_key"] ?? "");
if ($apiKey !== $API_KEY) {
    echo json_encode(["success" => false, "message" => "API key invalida"]);
    exit;
}

$referencia = trim($_POST["referencia"] ?? "");
$usuario = trim($_POST["usuario"] ?? "");
$texto = trim($_POST["texto"] ?? "");

if ($referencia === "" || $usuario === "" || $texto === "") {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Faltan datos"]);
    exit;
}

try {
    $pdo = getDBConnection();
    $stmt = $pdo->prepare(
        "INSERT INTO ClimaInstal_Comentarios (Pedido, Fecha, Usuario, Texto)
         VALUES (:ref, NOW(), :usuario, :texto)"
    );
    $stmt->execute([
        ":ref" => $referencia,
        ":usuario" => $usuario,
        ":texto" => $texto
    ]);

    echo json_encode(["success" => true, "message" => "Comentario guardado"]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ]);
}
