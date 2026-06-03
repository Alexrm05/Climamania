<?php
declare(strict_types=1);

require_once __DIR__ . '/../auth.php';

require_admin();
$pdo = get_admin_pdo();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    $referencia = trim((string)($_GET['referencia'] ?? ''));
    if ($referencia === '') {
        json_error('Referencia requerida', 400);
    }

    $stmt = $pdo->prepare(
        "SELECT id, Documento, Clave, Fecha\n"
        . "FROM ClimaInstal_Fotografias\n"
        . "WHERE Documento LIKE :doc\n"
        . "ORDER BY id ASC"
    );
    $stmt->execute([':doc' => 'imagenes/' . $referencia . '%']);

    json_ok(['fotos' => $stmt->fetchAll()]);
}

if ($method === 'DELETE') {
    $body = read_json_body();
    $documento = trim((string)($body['documento'] ?? ''));
    if ($documento === '') {
        json_error('Documento requerido', 400);
    }

    $stmt = $pdo->prepare(
        "DELETE FROM ClimaInstal_Fotografias WHERE Documento = :doc"
    );
    $stmt->execute([':doc' => $documento]);

    $baseDir = realpath(__DIR__ . '/../../');
    $filePath = $baseDir ? realpath($baseDir . '/' . $documento) : null;

    if ($baseDir && $filePath && is_file($filePath) && strpos($filePath, $baseDir) === 0) {
        @unlink($filePath);
    }

    json_ok();
}

json_error('Metodo no permitido', 405);
