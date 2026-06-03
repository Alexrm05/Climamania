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
        "SELECT id, Pedido, Fecha, Usuario, Texto\n"
        . "FROM ClimaInstal_Comentarios\n"
        . "WHERE Pedido = :ref\n"
        . "ORDER BY Fecha ASC"
    );
    $stmt->execute([':ref' => $referencia]);

    json_ok(['comentarios' => $stmt->fetchAll()]);
}

if ($method === 'POST') {
    $body = read_json_body();
    $referencia = trim((string)($body['referencia'] ?? ''));
    $usuario = trim((string)($body['usuario'] ?? ''));
    $texto = trim((string)($body['texto'] ?? ''));

    if ($referencia === '' || $usuario === '' || $texto === '') {
        json_error('Faltan datos', 400);
    }

    $stmt = $pdo->prepare(
        "INSERT INTO ClimaInstal_Comentarios (Pedido, Fecha, Usuario, Texto)\n"
        . "VALUES (:ref, NOW(), :usuario, :texto)"
    );
    $stmt->execute([
        ':ref' => $referencia,
        ':usuario' => $usuario,
        ':texto' => $texto
    ]);

    json_ok(['id' => (int)$pdo->lastInsertId()]);
}

if ($method === 'PUT') {
    $body = read_json_body();
    $id = (int)($body['id'] ?? 0);
    $texto = trim((string)($body['texto'] ?? ''));

    if ($id <= 0 || $texto === '') {
        json_error('Faltan datos', 400);
    }

    $stmt = $pdo->prepare(
        "UPDATE ClimaInstal_Comentarios SET Texto = :texto WHERE id = :id"
    );
    $stmt->execute([
        ':texto' => $texto,
        ':id' => $id
    ]);

    json_ok();
}

if ($method === 'DELETE') {
    $body = read_json_body();
    $id = (int)($body['id'] ?? 0);
    if ($id <= 0) {
        json_error('ID requerido', 400);
    }

    $stmt = $pdo->prepare(
        "DELETE FROM ClimaInstal_Comentarios WHERE id = :id"
    );
    $stmt->execute([':id' => $id]);

    json_ok();
}

json_error('Metodo no permitido', 405);
