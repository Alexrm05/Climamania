<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

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

$apiKey = $_GET["api_key"] ?? "";
if ($apiKey !== $API_KEY) {
    http_response_code(403);
    echo "API key invalida";
    exit;
}

$doc = trim($_GET["doc"] ?? "");
if ($doc === "") {
    http_response_code(400);
    echo "Documento requerido";
    exit;
}

try {
    $pdo = getDBConnection();
    $stmt = $pdo->prepare(
        "SELECT Documento
         FROM ClimaInstal_Fotografias
         WHERE Documento = :doc
         LIMIT 1"
    );
    $stmt->execute([":doc" => $doc]);
    $row = $stmt->fetch();

    if (!$row || empty($row["Documento"])) {
        http_response_code(404);
        echo "No encontrado";
        exit;
    }

    $doc = ltrim($row["Documento"], "/");
    $imagesDir = rtrim($IMAGES_DIR, "/");
    $baseRoot = $imagesDir;
    if (basename($imagesDir) === "imagenes") {
        $baseRoot = dirname($imagesDir);
    }

    $docNoPrefix = preg_replace('#^imagenes/#', '', $doc);
    $candidates = [
        $imagesDir . "/" . $docNoPrefix,
        $imagesDir . "/" . $doc,
        $baseRoot . "/" . $doc,
        $baseRoot . "/" . $docNoPrefix
    ];

    $filePath = null;
    foreach ($candidates as $candidate) {
        $real = realpath($candidate);
        if ($real && is_file($real)) {
            $filePath = $real;
            break;
        }
    }

    if (!$filePath || !is_file($filePath)) {
        http_response_code(404);
        echo "Archivo no encontrado";
        exit;
    }

    $allowedRoots = [];
    if ($imagesDir) $allowedRoots[] = realpath($imagesDir);
    if ($baseRoot) $allowedRoots[] = realpath($baseRoot);
    $allowed = false;
    foreach ($allowedRoots as $root) {
        if ($root && strpos($filePath, $root) === 0) {
            $allowed = true;
            break;
        }
    }
    if (!$allowed) {
        http_response_code(403);
        echo "Ruta no permitida";
        exit;
    }

    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mime = $finfo ? finfo_file($finfo, $filePath) : "application/octet-stream";
    if ($finfo) finfo_close($finfo);

    if (!$mime || $mime === "application/octet-stream") {
        $ext = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
        $videoMap = [
            "mp4" => "video/mp4",
            "mov" => "video/quicktime",
            "m4v" => "video/x-m4v",
            "3gp" => "video/3gpp",
            "webm" => "video/webm",
            "avi" => "video/x-msvideo",
            "mkv" => "video/x-matroska"
        ];
        $imageMap = [
            "jpg" => "image/jpeg",
            "jpeg" => "image/jpeg",
            "png" => "image/png",
            "gif" => "image/gif",
            "webp" => "image/webp"
        ];
        if (isset($videoMap[$ext])) {
            $mime = $videoMap[$ext];
        } elseif (isset($imageMap[$ext])) {
            $mime = $imageMap[$ext];
        }
    }

    $size = filesize($filePath);
    $range = $_SERVER['HTTP_RANGE'] ?? '';
    header("Content-Type: " . $mime);
    header("Accept-Ranges: bytes");

    if ($range && preg_match('/bytes=(\d*)-(\d*)/i', $range, $matches)) {
        $start = $matches[1] !== '' ? intval($matches[1]) : 0;
        $end = $matches[2] !== '' ? intval($matches[2]) : ($size - 1);
        if ($start > $end || $start >= $size) {
            http_response_code(416);
            header("Content-Range: bytes */" . $size);
            exit;
        }
        if ($end >= $size) {
            $end = $size - 1;
        }

        $length = $end - $start + 1;
        http_response_code(206);
        header("Content-Range: bytes $start-$end/$size");
        header("Content-Length: " . $length);

        $fp = fopen($filePath, 'rb');
        if ($fp === false) {
            http_response_code(500);
            echo "ERROR";
            exit;
        }
        fseek($fp, $start);
        $bufferSize = 8192;
        $bytesLeft = $length;
        while ($bytesLeft > 0 && !feof($fp)) {
            $read = fread($fp, min($bufferSize, $bytesLeft));
            if ($read === false) {
                break;
            }
            echo $read;
            $bytesLeft -= strlen($read);
        }
        fclose($fp);
        exit;
    }

    header("Content-Length: " . $size);
    readfile($filePath);
} catch (Exception $e) {
    http_response_code(500);
    echo "ERROR";
}
