<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";

$API_KEY = "TEST123";

if (!isset($_GET["api_key"]) || $_GET["api_key"] !== $API_KEY) {
    echo json_encode(["success" => false, "message" => "API key invalida"]);
    exit;
}

$idVisita = (int)($_GET["id_visita"] ?? 0);
if ($idVisita <= 0) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "id_visita requerido"]);
    exit;
}

$rol = trim($_GET["rol"] ?? "");
$usuario = trim($_GET["usuario"] ?? "");
$equipoRaw = trim($_GET["equipo"] ?? "");
$rolNorm = strtolower($rol);
$isAdmin = ($rolNorm === "adminclm" || $rolNorm === "admin" || $rolNorm === "administrador");

try {
    $pdo = getDBConnection();

    $stmt = $pdo->prepare(
        "SELECT
            id_visita,
            cliente,
            direccion,
            poblacion,
            telefono,
            email,
            prioridad,
            equipo_id,
            estado,
            usuario_solicita,
            fecha_solicitud,
            fecha_resolucion
         FROM ClimaInstal_Visitas
         WHERE id_visita = :id
         LIMIT 1"
    );
    $stmt->execute([":id" => $idVisita]);
    $visita = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$visita) {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Visita no encontrada"]);
        exit;
    }

    if (!$isAdmin) {
        $authorized = false;
        $equipoIds = resolveEquipoIds($pdo, $equipoRaw, $usuario);
        $visitaEquipoId = (int)($visita["equipo_id"] ?? 0);
        if ($visitaEquipoId > 0 && in_array($visitaEquipoId, $equipoIds, true)) {
            $authorized = true;
        }
        if (!$authorized && $usuario !== "") {
            $autorVisita = strtolower(trim((string)($visita["usuario_solicita"] ?? "")));
            $usuarioNorm = strtolower(trim($usuario));
            if ($autorVisita !== "" && $autorVisita === $usuarioNorm) {
                $authorized = true;
            }
        }
        if (!$authorized) {
            http_response_code(403);
            echo json_encode(["success" => false, "message" => "Sin permiso para esta visita"]);
            exit;
        }
    }

    $stmtMuro = $pdo->prepare(
        "SELECT id, id_visita, mensaje, autor, rol, origen, date_add
         FROM ClimaInstal_Visitas_Muro
         WHERE id_visita = :id
         ORDER BY date_add DESC, id DESC"
    );
    $stmtMuro->execute([":id" => $idVisita]);
    $muro = $stmtMuro->fetchAll(PDO::FETCH_ASSOC);

    $stmtFicheros = $pdo->prepare(
        "SELECT id, tipo, id_relacionado, ruta, tipo_fichero, usuario, date_add
         FROM ClimaInstal_Visitas_Ficheros
         WHERE id_relacionado = :id
         ORDER BY date_add DESC, id DESC"
    );
    $stmtFicheros->execute([":id" => $idVisita]);
    $ficheros = $stmtFicheros->fetchAll(PDO::FETCH_ASSOC);

    foreach ($ficheros as &$fichero) {
        $ruta = trim((string)($fichero["ruta"] ?? ""));
        $fichero["url"] = buildFileUrl($ruta);
    }
    unset($fichero);

    $visita["prioridad_label"] = mapPrioridadLabel($visita["prioridad"] ?? "");

    echo json_encode([
        "success" => true,
        "visita" => $visita,
        "muro" => $muro,
        "ficheros" => $ficheros
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ]);
}

function buildFileUrl(string $ruta): string
{
    if ($ruta === "") {
        return "";
    }
    if (stripos($ruta, "http://") === 0 || stripos($ruta, "https://") === 0) {
        return $ruta;
    }
    if ($ruta[0] === '/') {
        return "https://clminstal.es" . $ruta;
    }
    return "https://clminstal.es/" . $ruta;
}

function resolveEquipoIds(PDO $pdo, string $equipoRaw, string $usuario): array
{
    $equipo = trim($equipoRaw);

    if ($equipo === "" || $equipo === "0") {
        if ($usuario !== "") {
            $stmt = $pdo->prepare(
                "SELECT EquipoInstaladores
                 FROM ClimaInstal_Usuarios
                 WHERE usuario = ?
                 LIMIT 1"
            );
            $stmt->execute([$usuario]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($row && isset($row["EquipoInstaladores"])) {
                $equipo = trim((string)$row["EquipoInstaladores"]);
            }
        }
    }

    if ($equipo === "" || $equipo === "0") {
        return [];
    }

    $tokens = splitEquipoTokens($equipo);
    $ids = [];

    foreach ($tokens as $token) {
        if (preg_match('/^\d+$/', $token)) {
            $id = (int)$token;
            if ($id > 0) {
                $ids[$id] = true;
            }
        }
    }

    foreach (resolveEquipoIdsByCode($pdo, $tokens) as $id) {
        if ($id > 0) {
            $ids[$id] = true;
        }
    }

    if (empty($ids)) {
        foreach ($tokens as $token) {
            if (preg_match('/(\d+)$/', $token, $m)) {
                $id = (int)$m[1];
                if ($id > 0) {
                    $ids[$id] = true;
                }
            }
        }
    }

    return array_keys($ids);
}

function splitEquipoTokens(string $equipo): array
{
    $parts = preg_split('/[,\s;|]+/', $equipo);
    $tokens = [];
    foreach ($parts as $part) {
        $token = trim((string)$part);
        if ($token !== "" && $token !== "0") {
            $tokens[$token] = true;
        }
    }
    return array_keys($tokens);
}

function resolveEquipoIdsByCode(PDO $pdo, array $tokens): array
{
    $codes = [];
    foreach ($tokens as $token) {
        $clean = strtolower(trim((string)$token));
        if ($clean === "" || preg_match('/^\d+$/', $clean)) {
            continue;
        }
        $codes[$clean] = true;
    }
    $codes = array_keys($codes);
    if (empty($codes)) {
        return [];
    }

    $ids = [];
    $queries = [
        "SELECT id AS equipo_id
         FROM ClimaInstal_EquiposInstaladores
         WHERE LOWER(TRIM(nombre)) IN (%s)",
        "SELECT id AS equipo_id
         FROM ClimaInstal_EquiposInstaladores
         WHERE LOWER(TRIM(descripcion)) IN (%s)",
        "SELECT id_equipo AS equipo_id
         FROM ClimaInstal_EquiposInstaladores
         WHERE LOWER(TRIM(nombre)) IN (%s)",
        "SELECT id_equipo AS equipo_id
         FROM ClimaInstal_EquiposInstaladores
         WHERE LOWER(TRIM(descripcion)) IN (%s)"
    ];

    foreach ($queries as $queryTpl) {
        try {
            $ph = [];
            $params = [];
            foreach ($codes as $i => $code) {
                $key = ":c" . $i;
                $ph[] = $key;
                $params[$key] = $code;
            }
            $sql = sprintf($queryTpl, implode(",", $ph));
            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
            foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
                $id = (int)($row["equipo_id"] ?? 0);
                if ($id > 0) {
                    $ids[$id] = true;
                }
            }
            if (!empty($ids)) {
                return array_keys($ids);
            }
        } catch (Exception $ignored) {
            // tabla/columna distinta: intentar siguiente variante
        }
    }

    return [];
}

function mapPrioridadLabel($raw): string
{
    $value = trim((string)$raw);
    if ($value === "") {
        return "Sin prioridad";
    }

    $lower = strtolower($value);
    if ($lower === "alta" || $lower === "high" || $lower === "urgente") {
        return "Alta";
    }
    if ($lower === "media" || $lower === "medio" || $lower === "normal") {
        return "Media";
    }
    if ($lower === "baja" || $lower === "low") {
        return "Baja";
    }
    if (preg_match('/^\d+$/', $value)) {
        $n = (int)$value;
        if ($n >= 3) {
            return "Alta";
        }
        if ($n === 2) {
            return "Media";
        }
        return "Baja";
    }
    return ucfirst($value);
}
