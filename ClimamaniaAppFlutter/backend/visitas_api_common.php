<?php

function visitas_json_exit(array $payload, int $statusCode = 200): void
{
    $jsonFlags = JSON_UNESCAPED_UNICODE;
    if (defined("JSON_INVALID_UTF8_SUBSTITUTE")) {
        $jsonFlags |= JSON_INVALID_UTF8_SUBSTITUTE;
    }

    $json = json_encode($payload, $jsonFlags);
    if ($json === false) {
        $json = json_encode([
            "success" => false,
            "message" => "ERROR: respuesta JSON invalida"
        ], JSON_UNESCAPED_UNICODE);
    }

    http_response_code($statusCode);
    echo $json;
    exit;
}

function visitas_request(string $key): string
{
    if (isset($_POST[$key])) {
        return trim((string)$_POST[$key]);
    }
    if (isset($_GET[$key])) {
        return trim((string)$_GET[$key]);
    }
    return "";
}

function visitas_require_api_key(string $expectedApiKey): void
{
    $apiKey = visitas_request("api_key");
    if ($apiKey !== $expectedApiKey) {
        visitas_json_exit(["success" => false, "message" => "API key invalida"], 401);
    }
}

function visitas_is_admin_role(string $rol): bool
{
    $rolNorm = strtolower(trim($rol));
    return $rolNorm === "adminclm" || $rolNorm === "admin" || $rolNorm === "administrador";
}

function visitas_split_equipo_tokens(string $equipo): array
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

function visitas_resolve_equipo_ids_by_code(PDO $pdo, array $tokens): array
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
            // Intentar siguiente variante de consulta
        }
    }

    return [];
}

function visitas_resolve_equipo_ids(PDO $pdo, string $equipoRaw, string $usuario): array
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

    $tokens = visitas_split_equipo_tokens($equipo);
    $ids = [];

    foreach ($tokens as $token) {
        if (preg_match('/^\d+$/', $token)) {
            $id = (int)$token;
            if ($id > 0) {
                $ids[$id] = true;
            }
        }
    }

    foreach (visitas_resolve_equipo_ids_by_code($pdo, $tokens) as $id) {
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

function visitas_get_visita(PDO $pdo, int $idVisita): ?array
{
    $stmt = $pdo->prepare(
        "SELECT
            id_visita,
            cliente,
            direccion,
            poblacion,
            telefono,
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
    return $visita ?: null;
}

function visitas_authorize_visita(
    PDO $pdo,
    array $visita,
    string $rol,
    string $usuario,
    string $equipoRaw
): bool {
    if (visitas_is_admin_role($rol)) {
        return true;
    }

    $authorized = false;
    $equipoIds = visitas_resolve_equipo_ids($pdo, $equipoRaw, $usuario);
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

    return $authorized;
}

function visitas_normalize_text(string $value, int $maxLen = 3000): string
{
    $clean = trim(str_replace("\0", "", $value));
    if ($maxLen > 0 && mb_strlen($clean, "UTF-8") > $maxLen) {
        $clean = mb_substr($clean, 0, $maxLen, "UTF-8");
    }
    return $clean;
}

function visitas_normalize_prioridad_to_int(string $raw): int
{
    $value = strtolower(trim($raw));
    if ($value === "") {
        return 0;
    }

    if (preg_match('/^\d+$/', $value)) {
        $n = (int)$value;
        if ($n <= 1) return 1;
        if ($n === 2) return 2;
        return 3;
    }

    if ($value === "alta" || $value === "high" || $value === "urgente") {
        return 3;
    }
    if ($value === "media" || $value === "medio" || $value === "normal") {
        return 2;
    }
    if ($value === "baja" || $value === "low") {
        return 1;
    }

    return 0;
}

function visitas_prioridad_label_from_int(int $value): string
{
    if ($value >= 3) return "Alta";
    if ($value === 2) return "Media";
    return "Baja";
}

function visitas_resolve_upload_dir(): string
{
    $imagesDir = getenv("CLM_IMAGES_DIR");
    if ($imagesDir === false || $imagesDir === "") {
        $imagesDir = realpath(__DIR__ . "/../imagenes");
    }
    if ($imagesDir === false || $imagesDir === "") {
        $imagesDir = realpath(__DIR__ . "/../../imagenes");
    }
    if ($imagesDir === false || $imagesDir === "") {
        $imagesDir = __DIR__ . "/../imagenes";
    }
    return rtrim((string)$imagesDir, "/");
}

function visitas_resolve_initials(string $requested, string $usuario): string
{
    $provided = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $requested));
    if ($provided !== "") {
        return substr($provided, 0, 6);
    }

    $fromUser = strtoupper(trim((string)$usuario));
    if ($fromUser === "") {
        return "APP";
    }

    $tokens = preg_split('/[^A-Za-z0-9]+/', $fromUser);
    $letters = "";
    foreach ($tokens as $token) {
        $token = trim((string)$token);
        if ($token === "") {
            continue;
        }
        $letters .= substr($token, 0, 1);
        if (strlen($letters) >= 3) {
            break;
        }
    }

    if ($letters === "") {
        $letters = preg_replace('/[^A-Za-z0-9]/', '', $fromUser);
    }

    $letters = substr($letters, 0, 6);
    return $letters !== "" ? $letters : "APP";
}

function visitas_insert_muro(
    PDO $pdo,
    int $idVisita,
    string $mensaje,
    string $autor,
    string $rol,
    string $origen = "APP_ANDROID"
): void {
    $mensajeClean = visitas_normalize_text($mensaje, 5000);
    if ($mensajeClean === "") {
        return;
    }

    $autorClean = visitas_normalize_text($autor, 100);
    if ($autorClean === "") {
        $autorClean = "Instalador";
    }

    $rolClean = strtoupper(visitas_normalize_text($rol, 50));
    if ($rolClean === "") {
        $rolClean = "INSTALADOR";
    }

    $origenClean = strtoupper(visitas_normalize_text($origen, 50));
    if ($origenClean === "") {
        $origenClean = "APP_ANDROID";
    }

    $stmt = $pdo->prepare(
        "INSERT INTO ClimaInstal_Visitas_Muro
            (id_visita, mensaje, autor, rol, origen, date_add)
         VALUES
            (:id_visita, :mensaje, :autor, :rol, :origen, NOW())"
    );
    $stmt->execute([
        ":id_visita" => $idVisita,
        ":mensaje" => $mensajeClean,
        ":autor" => $autorClean,
        ":rol" => $rolClean,
        ":origen" => $origenClean
    ]);
}

function visitas_get_variables_generales(PDO $pdo, array $names): array
{
    $cleanNames = [];
    foreach ($names as $name) {
        $nameClean = trim((string)$name);
        if ($nameClean !== "") {
            $cleanNames[$nameClean] = true;
        }
    }
    $cleanNames = array_keys($cleanNames);
    if (empty($cleanNames)) {
        return [];
    }

    $placeholders = [];
    $params = [];
    foreach ($cleanNames as $i => $name) {
        $key = ":n" . $i;
        $placeholders[] = $key;
        $params[$key] = $name;
    }

    $sql = "SELECT nombreVariable, valorVariable
            FROM variables_generales
            WHERE nombreVariable IN (" . implode(",", $placeholders) . ")";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    $values = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $nombre = trim((string)($row["nombreVariable"] ?? ""));
        $valor = trim((string)($row["valorVariable"] ?? ""));
        if ($nombre !== "" && $valor !== "") {
            $values[$nombre] = $valor;
        }
    }

    return $values;
}

function visitas_parse_email_values(string $raw): array
{
    $normalized = str_replace(["\r", "\n"], ";", (string)$raw);
    $chunks = preg_split('/[;,]+/', $normalized);
    if (!is_array($chunks)) {
        return [];
    }

    $emails = [];
    foreach ($chunks as $chunk) {
        $mail = trim((string)$chunk);
        if ($mail === "") {
            continue;
        }
        if (!filter_var($mail, FILTER_VALIDATE_EMAIL)) {
            continue;
        }
        $emails[$mail] = true;
    }
    return array_keys($emails);
}

function visitas_collect_variable_emails(PDO $pdo, array $orderedNames): array
{
    $map = visitas_get_variables_generales($pdo, $orderedNames);
    $emails = [];
    foreach ($orderedNames as $name) {
        if (!isset($map[$name])) {
            continue;
        }
        foreach (visitas_parse_email_values((string)$map[$name]) as $mail) {
            $emails[$mail] = true;
        }
    }
    return array_keys($emails);
}

function visitas_destinatarios_cierre(PDO $pdo): array
{
    $ordered = [
        "emailGerencia",
        "emailCompras",
        "emailFacturacion",
        "emailMarketing",
        "emailGenerico"
    ];

    $emails = [];
    foreach (visitas_collect_variable_emails($pdo, $ordered) as $mail) {
        $emails[$mail] = true;
    }

    if (empty($emails)) {
        $emails["climamania@climamania.com"] = true;
    }

    return array_keys($emails);
}

function visitas_send_mail_plain(array $destinatarios, string $asunto, string $cuerpo): bool
{
    $to = [];
    foreach ($destinatarios as $email) {
        $mail = trim((string)$email);
        if ($mail !== "" && filter_var($mail, FILTER_VALIDATE_EMAIL)) {
            $to[$mail] = true;
        }
    }
    if (empty($to)) {
        return false;
    }

    $from = "climamania@climamania.com";
    $headers = "From: ClimaMania Instalaciones <{$from}>\r\n"
        . "Reply-To: climamania@climamania.com\r\n"
        . "MIME-Version: 1.0\r\n"
        . "Content-Type: text/plain; charset=UTF-8\r\n";

    $toCsv = implode(",", array_keys($to));
    $ok = @mail($toCsv, $asunto, $cuerpo, $headers, "-f {$from}");
    if (!$ok) {
        $ok = @mail($toCsv, $asunto, $cuerpo, $headers);
    }
    return $ok;
}
