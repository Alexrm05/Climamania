<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

function get_bearer_token(): ?string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if ($header === '') {
        $header = $_SERVER['Authorization'] ?? '';
    }
    if (!is_string($header) || stripos($header, 'Bearer ') !== 0) {
        return null;
    }
    return trim(substr($header, 7));
}

function require_admin(): array
{
    $token = get_bearer_token();
    if ($token === null || $token === '') {
        json_error('No autorizado', 401);
    }

    $pdo = get_admin_pdo();
    $stmt = $pdo->prepare(
        "SELECT s.user_id, s.expires_at, u.usuario, u.rol, u.activo\n"
        . "FROM Admin_Sessions s\n"
        . "INNER JOIN Admin_Users u ON u.id = s.user_id\n"
        . "WHERE s.token = :token\n"
        . "LIMIT 1"
    );
    $stmt->execute([':token' => $token]);
    $row = $stmt->fetch();

    if (!$row || (int)$row['activo'] !== 1) {
        json_error('No autorizado', 401);
    }

    $expires = strtotime((string)$row['expires_at']);
    if ($expires !== false && $expires < time()) {
        json_error('Sesion expirada', 401);
    }

    return [
        'user_id' => (int)$row['user_id'],
        'usuario' => (string)$row['usuario'],
        'rol' => (string)$row['rol']
    ];
}

function create_session(int $userId): string
{
    $token = bin2hex(random_bytes(32));
    $expiresAt = date('Y-m-d H:i:s', time() + 8 * 3600);

    $pdo = get_admin_pdo();
    $stmt = $pdo->prepare(
        "INSERT INTO Admin_Sessions (user_id, token, expires_at, created_at)\n"
        . "VALUES (:user_id, :token, :expires_at, NOW())"
    );
    $stmt->execute([
        ':user_id' => $userId,
        ':token' => $token,
        ':expires_at' => $expiresAt
    ]);

    return $token;
}
