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

$id = trim($_POST["id"] ?? "");
$referencia = trim($_POST["referencia"] ?? "");
$rol = trim($_POST["rol"] ?? "");
$usuario = trim($_POST["usuario"] ?? "");

if ($id === "" || !ctype_digit($id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Falta el id del comentario"]);
    exit;
}

$rolNorm = strtolower($rol);
$esAdmin = in_array($rolNorm, ["adminclm", "admin", "administrador"], true);

try {
    $pdo = getDBConnection();

    // Localiza el comentario para comprobar propiedad antes de borrar.
    $sel = $pdo->prepare(
        "SELECT Usuario, Pedido FROM ClimaInstal_Comentarios WHERE id = :id"
    );
    $sel->execute([":id" => (int)$id]);
    $row = $sel->fetch();

    if (!$row) {
        echo json_encode([
            "success" => false,
            "message" => "No se encontró el comentario"
        ]);
        exit;
    }

    // Salvaguarda: si llega referencia, debe coincidir con el pedido.
    if ($referencia !== "" && trim((string)$row["Pedido"]) !== $referencia) {
        echo json_encode([
            "success" => false,
            "message" => "El comentario no pertenece a este pedido"
        ]);
        exit;
    }

    // El admin puede borrar cualquiera; el instalador, solo los suyos.
    if (!$esAdmin) {
        $autor = strtolower(trim((string)$row["Usuario"]));
        if ($autor === "" || $autor !== strtolower($usuario)) {
            http_response_code(403);
            echo json_encode([
                "success" => false,
                "message" => "No puedes eliminar comentarios de otro usuario"
            ]);
            exit;
        }
    }

    $stmt = $pdo->prepare("DELETE FROM ClimaInstal_Comentarios WHERE id = :id");
    $stmt->execute([":id" => (int)$id]);

    if ($stmt->rowCount() > 0) {
        echo json_encode(["success" => true, "message" => "Comentario eliminado"]);
    } else {
        echo json_encode([
            "success" => false,
            "message" => "No se encontró el comentario"
        ]);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ]);
}
