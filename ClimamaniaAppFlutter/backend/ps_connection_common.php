<?php
// Conexión a la base de datos de PrestaShop tolerante a fallos.
//
// getPSConnection() (conexion.php) aborta toda la petición si la tienda no
// responde, y con el timeout por defecto de MySQL eso son ~30 s en los que la
// app se queda "pensando". Este helper conecta con un timeout corto y devuelve
// null si falla, para que cada endpoint decida si puede seguir sin PrestaShop
// (p. ej. la ficha del pedido con los datos de ClimaInstal).

require_once __DIR__ . "/conexion.php";

/// PDO de PrestaShop o null si la tienda no está disponible.
function clm_try_ps_connection(int $timeoutSeconds = 4): ?PDO
{
    global $PS_DB_HOST, $PS_DB_NAME, $PS_DB_USER, $PS_DB_PASS, $pdo_options;

    $options = is_array($pdo_options) ? $pdo_options : [];
    $options[PDO::ATTR_TIMEOUT] = max(1, $timeoutSeconds);

    try {
        return new PDO(
            "mysql:host={$PS_DB_HOST};dbname={$PS_DB_NAME};charset=utf8mb4",
            $PS_DB_USER,
            $PS_DB_PASS,
            $options
        );
    } catch (PDOException $e) {
        error_log("[clminstal] PrestaShop no disponible: " . $e->getMessage());
        return null;
    }
}
