<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";

$API_KEY = "TEST123";

// Ruta real donde se guardan los archivos (igual que upload_foto.php).
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

$documento = trim((string)($_POST["doc"] ?? ""));
$usuario = trim((string)($_POST["usuario"] ?? ""));
$rol = trim((string)($_POST["rol"] ?? ""));

if ($documento === "") {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Falta el documento"]);
    exit;
}

$documento = str_replace("\\", "/", $documento);
if (strpos($documento, "..") !== false) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Ruta no válida"]);
    exit;
}

$basename = basename($documento);

// Usuario que subió la foto, extraído del nombre:
// {referencia}-{clave}-{YYYYMMDDHHMMSS}-{usuario}.ext
$uploader = "";
if (preg_match('/-(\d{14})-(.+)\.[^.]+$/', $basename, $m)) {
    $uploader = $m[2];
}

$sanit = static function (string $s): string {
    return preg_replace('/[^A-Za-z0-9_-]/', '', $s);
};

$esAdmin = in_array(strtolower($rol), ["adminclm", "admin", "administrador"], true);

// El admin puede borrar cualquiera; el instalador, solo las suyas.
if (!$esAdmin) {
    if ($uploader === "" ||
        strtolower($sanit($usuario)) !== strtolower($uploader)) {
        http_response_code(403);
        echo json_encode([
            "success" => false,
            "message" => "Solo puedes eliminar las fotos que has añadido tú"
        ]);
        exit;
    }
}

try {
    $pdo = getDBConnection();
    $stmt = $pdo->prepare(
        "DELETE FROM ClimaInstal_Fotografias WHERE Documento = :doc"
    );
    $stmt->execute([":doc" => $documento]);
    $deleted = $stmt->rowCount();

    // Borra también el fichero físico (dentro de la carpeta de imágenes).
    $filePath = rtrim($IMAGES_DIR, "/") . "/" . $basename;
    if (is_file($filePath)) {
        @unlink($filePath);
    }

    if ($deleted > 0 || !is_file($filePath)) {
        echo json_encode(["success" => true, "message" => "Foto eliminada"]);
    } else {
        echo json_encode([
            "success" => false,
            "message" => "No se pudo eliminar la foto"
        ]);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ]);
}
