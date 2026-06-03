<?php
declare(strict_types=1);

require_once __DIR__ . '/../auth.php';

require_admin();
$pdo = get_admin_pdo();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    $referencia = trim((string)($_GET['referencia'] ?? ''));
    $estado = trim((string)($_GET['estado'] ?? ''));
    $limit = (int)($_GET['limit'] ?? 200);
    if ($limit < 1) {
        $limit = 200;
    }
    if ($limit > 500) {
        $limit = 500;
    }

    $sql = "SELECT id, title, start, end, referencia, nombrecliente, telefono, direccion, equipo_instaladores, estado\n"
        . "FROM ClimaInstal_events\n"
        . "WHERE 1 = 1";
    $params = [];

    if ($referencia !== '') {
        $sql .= " AND referencia = :ref";
        $params[':ref'] = $referencia;
    }

    if ($estado !== '') {
        $sql .= " AND estado = :estado";
        $params[':estado'] = $estado;
    }

    $sql .= " ORDER BY start DESC LIMIT " . $limit;
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    json_ok(['eventos' => $stmt->fetchAll()]);
}

if ($method === 'POST') {
    $body = read_json_body();
    $title = trim((string)($body['title'] ?? ''));
    $start = trim((string)($body['start'] ?? ''));
    $end = trim((string)($body['end'] ?? ''));
    $referencia = trim((string)($body['referencia'] ?? ''));

    if ($title === '' || $start === '' || $end === '' || $referencia === '') {
        json_error('Faltan datos', 400);
    }

    $stmt = $pdo->prepare(
        "INSERT INTO ClimaInstal_events (title, start, end, referencia, estado)\n"
        . "VALUES (:title, :start, :end, :ref, 'pendiente')"
    );
    $stmt->execute([
        ':title' => $title,
        ':start' => $start,
        ':end' => $end,
        ':ref' => $referencia
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
    $allowed = [
        'title', 'start', 'end', 'referencia', 'nombrecliente', 'telefono', 'whatsapp',
        'direccion', 'detalles', 'comentarios', 'equipo_instaladores', 'EmailEquipo', 'estado', 'color'
    ];

    foreach ($allowed as $key) {
        if (array_key_exists($key, $body)) {
            $fields[] = $key . ' = :' . $key;
            $params[':' . $key] = (string)$body[$key];
        }
    }

    if (empty($fields)) {
        json_error('No hay cambios', 400);
    }

    $sql = "UPDATE ClimaInstal_events SET " . implode(', ', $fields) . " WHERE id = :id";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    json_ok();
}

json_error('Metodo no permitido', 405);
