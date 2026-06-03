<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";

$API_KEY = "TEST123";

// Ruta real donde se guardan los archivos (ajusta si tu estructura es distinta)
$IMAGES_DIR = getenv("CLM_IMAGES_DIR");
if ($IMAGES_DIR === false || $IMAGES_DIR === "") {
    $IMAGES_DIR = realpath(__DIR__ . "/../imagenes");
}
if ($IMAGES_DIR === false || $IMAGES_DIR === "") {
    $IMAGES_DIR = realpath(__DIR__ . "/../../imagenes");
}
if ($IMAGES_DIR === false || $IMAGES_DIR === "") {
    $IMAGES_DIR = __DIR__ . "/../imagenes";
}

$apiKey = $_POST["api_key"] ?? ($_GET["api_key"] ?? "");
if ($apiKey !== $API_KEY) {
    echo json_encode(["success" => false, "message" => "API key invalida"]);
    exit;
}

$referencia = trim($_POST["referencia"] ?? "");
$clave = trim($_POST["clave"] ?? "");
$usuario = trim($_POST["usuario"] ?? "");

if ($referencia === "" || $clave === "" || $usuario === "") {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Faltan datos"]);
    exit;
}

if (!isset($_FILES["archivo"]) || $_FILES["archivo"]["error"] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Archivo no recibido"]);
    exit;
}

$suffixMap = [
    "FOTOCLI" => "FOTOCLI",
    "PREINST" => "PREINST",
    "DURINST" => "DURINST",
    "POSTINST" => "POSTINST",
    "CONFCLI" => "DOCCLI",
    "DOCUBOE" => "DOCUBOE"
];
$suffix = $suffixMap[$clave] ?? $clave;

$originalName = $_FILES["archivo"]["name"] ?? "foto.jpg";
$ext = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
$allowed = ["jpg", "jpeg", "png", "webp", "gif", "mp4", "mov", "m4v", "3gp", "webm", "avi", "mkv"];

if (!in_array($ext, $allowed, true)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Tipo de archivo no permitido"]);
    exit;
}

$safeUser = preg_replace("/[^A-Za-z0-9_-]/", "", $usuario);
if ($safeUser === "") {
    $safeUser = "user";
}

$timestamp = date("YmdHis");
$filename = $referencia . "-" . $suffix . "-" . $timestamp . "-" . $safeUser . "." . $ext;

// Directorio final de subida
$uploadDir = rtrim($IMAGES_DIR, "/");

if (!is_dir($uploadDir)) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Carpeta de destino no existe"
    ]);
    exit;
}

$dest = $uploadDir . "/" . $filename;
if (!move_uploaded_file($_FILES["archivo"]["tmp_name"], $dest)) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "No se pudo guardar el archivo"]);
    exit;
}

$documento = "imagenes/" . $filename;

try {
    $pdo = getDBConnection();
    $stmt = $pdo->prepare(
        "INSERT INTO ClimaInstal_Fotografias (Documento, Clave, Fecha)
         VALUES (:doc, :clave, NOW())"
    );
    $stmt->execute([
        ":doc" => $documento,
        ":clave" => $clave
    ]);

    echo json_encode([
        "success" => true,
        "message" => "Archivo subido",
        "documento" => $documento
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ]);
}
