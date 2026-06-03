<?php
declare(strict_types=1);

require_once __DIR__ . '/../auth.php';

require_admin();

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
    json_error('Metodo no permitido', 405);
}

json_error('No implementado', 501);
