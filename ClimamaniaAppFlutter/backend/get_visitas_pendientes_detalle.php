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

$rol = trim($_GET["rol"] ?? "");
$usuario = trim($_GET["usuario"] ?? "");
$equipoRaw = trim($_GET["equipo"] ?? "");
$isAdmin = isAdminRole($rol);

try {
    $pdo = getDBConnection();

    $whereActivas = "estado = 1";

    $prioridadOrdenExpr = "CASE
        WHEN LOWER(TRIM(CAST(prioridad AS CHAR))) IN ('alta', 'high', 'urgente') THEN 1
        WHEN LOWER(TRIM(CAST(prioridad AS CHAR))) IN ('media', 'medio', 'normal') THEN 2
        WHEN LOWER(TRIM(CAST(prioridad AS CHAR))) IN ('baja', 'low') THEN 3
        WHEN TRIM(CAST(prioridad AS CHAR)) REGEXP '^[0-9]+$' THEN
            CASE
                WHEN CAST(prioridad AS UNSIGNED) >= 3 THEN 1
                WHEN CAST(prioridad AS UNSIGNED) = 2 THEN 2
                ELSE 3
            END
        ELSE 4
    END";

    $sql = "SELECT
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
                fecha_resolucion,
                $prioridadOrdenExpr AS prioridad_orden
            FROM ClimaInstal_Visitas
            WHERE $whereActivas";

    $params = [];

    if (!$isAdmin) {
        $equipoIds = resolveEquipoIds($pdo, $equipoRaw, $usuario);
        if (empty($equipoIds)) {
            echo json_encode([
                "success" => true,
                "visitas" => []
            ], JSON_UNESCAPED_UNICODE);
            exit;
        }

        $placeholders = [];
        foreach ($equipoIds as $i => $id) {
            $key = ":equipo_" . $i;
            $placeholders[] = $key;
            $params[$key] = $id;
        }
        $sql .= " AND equipo_id IN (" . implode(",", $placeholders) . ")";
    }

    $sql .= " ORDER BY prioridad_orden ASC, fecha_solicitud ASC, id_visita ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $visitas = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($visitas as &$visita) {
        $visita["prioridad_label"] = mapPrioridadLabel($visita["prioridad"] ?? "");
        unset($visita["prioridad_orden"]);
    }
    unset($visita);

    echo json_encode([
        "success" => true,
        "visitas" => $visitas
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ]);
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

function isAdminRole(string $rol): bool
{
    $rolNorm = strtolower(trim($rol));
    return $rolNorm === "adminclm" || $rolNorm === "admin" || $rolNorm === "administrador";
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
