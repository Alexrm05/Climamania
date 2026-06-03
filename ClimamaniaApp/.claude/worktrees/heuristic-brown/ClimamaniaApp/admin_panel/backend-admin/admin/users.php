<?php
declare(strict_types=1);

require_once __DIR__ . '/../auth.php';

require_admin();
$pdo = get_admin_pdo();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    $stmt = $pdo->query(
        "SELECT id, usuario, rol, activo, created_at, updated_at\n"
        . "FROM Admin_Users\n"
        . "ORDER BY id DESC"
    );
    json_ok(['usuarios' => $stmt->fetchAll()]);
}

if ($method === 'POST') {
    $body = read_json_body();
    $usuario = trim((string)($body['usuario'] ?? ''));
    $contrasenya = (string)($body['contrasenya'] ?? '');
    $rol = trim((string)($body['rol'] ?? 'admin'));

    if ($usuario === '' || $contrasenya === '' || $rol === '') {
        json_error('Faltan datos', 400);
    }

    $hash = password_hash($contrasenya, PASSWORD_DEFAULT);
    $stmt = $pdo->prepare(
        "INSERT INTO Admin_Users (usuario, password_hash, rol, activo, created_at, updated_at)\n"
        . "VALUES (:usuario, :hash, :rol, 1, NOW(), NOW())"
    );
    $stmt->execute([
        ':usuario' => $usuario,
        ':hash' => $hash,
        ':rol' => $rol
    ]);

    json_ok(['id' => (int)$pdo->lastInsertId()]);
}

if ($method === 'PUT') {
    $body = read_json_body();
    $id = (int)($body['id'] ?? 0);
    if ($id <= 0) {
        json_error('ID requerido', 400);
    }

    $fields = [];
    $params = [':id' => $id];

    if (array_key_exists('rol', $body)) {
        $fields[] = 'rol = :rol';
        $params[':rol'] = trim((string)$body['rol']);
    }

    if (array_key_exists('activo', $body)) {
        $fields[] = 'activo = :activo';
        $params[':activo'] = (int)$body['activo'] ? 1 : 0;
    }

    if (!empty($body['contrasenya'])) {
        $fields[] = 'password_hash = :hash';
        $params[':hash'] = password_hash((string)$body['contrasenya'], PASSWORD_DEFAULT);
    }

    if (empty($fields)) {
        json_error('No hay cambios', 400);
    }

    $sql = "UPDATE Admin_Users SET " . implode(', ', $fields) . ", updated_at = NOW() WHERE id = :id";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    json_ok();
}

if ($method === 'DELETE') {
    $body = read_json_body();
    $id = (int)($body['id'] ?? 0);
    if ($id <= 0) {
        json_error('ID requerido', 400);
    }

    $stmt = $pdo->prepare(
        "UPDATE Admin_Users SET activo = 0, updated_at = NOW() WHERE id = :id"
    );
    $stmt->execute([':id' => $id]);

    json_ok();
}

json_error('Metodo no permitido', 405);
