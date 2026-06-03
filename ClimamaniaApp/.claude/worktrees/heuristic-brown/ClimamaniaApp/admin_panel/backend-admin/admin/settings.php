<?php
declare(strict_types=1);

require_once __DIR__ . '/../auth.php';

require_admin();
$pdo = get_admin_pdo();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    $stmt = $pdo->query(
        "SELECT setting_key, setting_value, updated_at\n"
        . "FROM Admin_Settings\n"
        . "ORDER BY setting_key ASC"
    );
    $rows = $stmt->fetchAll();
    json_ok(['settings' => $rows]);
}

if ($method === 'PUT') {
    $body = read_json_body();
    $items = $body['items'] ?? null;

    if (!is_array($items)) {
        $singleKey = trim((string)($body['setting_key'] ?? ''));
        $singleValue = (string)($body['setting_value'] ?? '');
        if ($singleKey === '') {
            json_error('Faltan datos', 400);
        }
        $items = [
            ['key' => $singleKey, 'value' => $singleValue]
        ];
    }

    $stmt = $pdo->prepare(
        "INSERT INTO Admin_Settings (setting_key, setting_value, updated_at)\n"
        . "VALUES (:key, :value, NOW())\n"
        . "ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_at = NOW()"
    );

    foreach ($items as $item) {
        $key = trim((string)($item['key'] ?? ''));
        if ($key === '') {
            continue;
        }
        $value = (string)($item['value'] ?? '');
        $stmt->execute([
            ':key' => $key,
            ':value' => $value
        ]);
    }

    json_ok();
}

json_error('Metodo no permitido', 405);
