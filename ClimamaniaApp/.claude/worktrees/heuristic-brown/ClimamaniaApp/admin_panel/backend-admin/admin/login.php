<?php
declare(strict_types=1);

require_once __DIR__ . '/../auth.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_error('Metodo no permitido', 405);
}

$body = read_json_body();
$usuario = trim((string)($body['usuario'] ?? ''));
$contrasenya = (string)($body['contrasenya'] ?? '');

if ($usuario === '' || $contrasenya === '') {
    json_error('Faltan datos', 400);
}

$pdo = get_admin_pdo();
$stmt = $pdo->prepare(
    "SELECT id, usuario, password_hash, rol, activo\n"
    . "FROM Admin_Users\n"
    . "WHERE usuario = :usuario\n"
    . "LIMIT 1"
);
$stmt->execute([':usuario' => $usuario]);
$row = $stmt->fetch();

if (!$row || (int)$row['activo'] !== 1) {
    json_error('Credenciales invalidas', 401);
}

if (!password_verify($contrasenya, (string)$row['password_hash'])) {
    json_error('Credenciales invalidas', 401);
}

$token = create_session((int)$row['id']);
json_ok([
    'token' => $token,
    'usuario' => (string)$row['usuario'],
    'rol' => (string)$row['rol']
]);
