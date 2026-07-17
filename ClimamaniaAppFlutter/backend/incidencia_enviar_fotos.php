<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";
require_once "incidencias_api_common.php";

$API_KEY = "TEST123";
visitas_require_api_key($API_KEY);

$idIncidencia = (int)visitas_request("id_incidencia");
if ($idIncidencia <= 0) {
    $idIncidencia = (int)visitas_request("id_visita");
}
if ($idIncidencia <= 0) {
    visitas_json_exit(["success" => false, "message" => "id_incidencia requerido"], 400);
}

$rol = visitas_request("rol");
$usuario = visitas_request("usuario");
$equipo = visitas_request("equipo");
$kIniciales = visitas_request("k_iniciales");

if (!isset($_FILES["archivo"]) || $_FILES["archivo"]["error"] !== UPLOAD_ERR_OK) {
    visitas_json_exit(["success" => false, "message" => "Archivo no recibido"], 400);
}

$originalName = (string)($_FILES["archivo"]["name"] ?? "archivo");
$mimeType = strtolower(trim((string)($_FILES["archivo"]["type"] ?? "")));
$tmpPath = (string)($_FILES["archivo"]["tmp_name"] ?? "");
$extension = incidencia_detect_upload_extension($originalName, $mimeType, $tmpPath);
$allowed = ["jpg", "jpeg", "png", "webp", "gif", "mp4", "mov", "m4v", "3gp", "webm", "avi", "mkv", "mpeg", "mpg"];
if ($extension === "" || !in_array($extension, $allowed, true)) {
    visitas_json_exit(["success" => false, "message" => "Tipo de archivo no permitido"], 400);
}

try {
    $pdo = getDBConnection();
    $schema = incidencias_resolve_schema($pdo);
    $incidencia = incidencias_fetch_by_id($pdo, $schema, $idIncidencia);

    if (!$incidencia) {
        visitas_json_exit(["success" => false, "message" => "Incidencia no encontrada"], 404);
    }

    if (!incidencias_authorize_row($pdo, $schema, $incidencia, $rol, $usuario, $equipo)) {
        visitas_json_exit(["success" => false, "message" => "Sin permiso para esta incidencia"], 403);
    }

    $iniciales = visitas_resolve_initials($kIniciales, $usuario);
    $baseName = "INCIDENCIA" . $idIncidencia . "-" . date("YmdHis") . "-" . $iniciales;
    $nombreFinal = $baseName . "." . $extension;

    $uploadDir = visitas_resolve_upload_dir();
    if (!is_dir($uploadDir) && !mkdir($uploadDir, 0775, true)) {
        visitas_json_exit(["success" => false, "message" => "No existe la carpeta de destino"], 500);
    }

    $counter = 1;
    while (file_exists($uploadDir . "/" . $nombreFinal)) {
        $nombreFinal = $baseName . "-" . $counter . "." . $extension;
        $counter++;
    }

    $destino = $uploadDir . "/" . $nombreFinal;
    if (!move_uploaded_file($_FILES["archivo"]["tmp_name"], $destino)) {
        visitas_json_exit(["success" => false, "message" => "No se pudo guardar el archivo"], 500);
    }

    $rutaRelativa = "imagenes/" . $nombreFinal;
    $ok = incidencias_insert_fichero($pdo, $schema, $idIncidencia, $rutaRelativa, $extension, $usuario);
    if (!$ok) {
        visitas_json_exit(["success" => false, "message" => "No se pudo registrar el fichero en la incidencia"], 500);
    }

    visitas_json_exit([
        "success" => true,
        "message" => "Archivo subido correctamente",
        "nombre" => $nombreFinal,
        "ruta" => $rutaRelativa,
        "url" => incidencias_build_file_url($rutaRelativa)
    ]);
} catch (Exception $e) {
    visitas_json_exit([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ], 500);
}

function incidencia_detect_upload_extension(string $originalName, string $mimeType, string $tmpPath): string
{
    $extension = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
    if ($extension !== "") {
        return $extension;
    }

    $mimeToExt = [
        "image/jpeg" => "jpg",
        "image/jpg" => "jpg",
        "image/png" => "png",
        "image/webp" => "webp",
        "image/gif" => "gif",
        "video/mp4" => "mp4",
        "video/quicktime" => "mov",
        "video/x-m4v" => "m4v",
        "video/3gpp" => "3gp",
        "video/webm" => "webm",
        "video/x-msvideo" => "avi",
        "video/x-matroska" => "mkv",
        "video/mpeg" => "mpeg"
    ];

    if ($mimeType !== "" && isset($mimeToExt[$mimeType])) {
        return $mimeToExt[$mimeType];
    }

    if ($tmpPath !== "" && is_file($tmpPath)) {
        try {
            $finfo = new finfo(FILEINFO_MIME_TYPE);
            $detected = strtolower((string)$finfo->file($tmpPath));
            if ($detected !== "" && isset($mimeToExt[$detected])) {
                return $mimeToExt[$detected];
            }
        } catch (Exception $ignored) {
            // usar fallback vacío
        }
    }

    return "";
}
