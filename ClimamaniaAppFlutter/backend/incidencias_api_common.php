<?php

require_once "visitas_api_common.php";

function incidencias_table_exists(PDO $pdo, string $table): bool
{
    $stmt = $pdo->prepare("SHOW TABLES LIKE ?");
    $stmt->execute([$table]);
    return $stmt->fetchColumn() !== false;
}

function incidencias_first_existing_table(PDO $pdo, array $candidates): ?string
{
    foreach ($candidates as $table) {
        $clean = trim((string)$table);
        if ($clean === "") {
            continue;
        }
        if (incidencias_table_exists($pdo, $clean)) {
            return $clean;
        }
    }
    return null;
}

function incidencias_get_columns(PDO $pdo, string $table): array
{
    $stmt = $pdo->query("DESCRIBE `" . str_replace("`", "``", $table) . "`");
    $cols = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $field = (string)($row["Field"] ?? "");
        if ($field === "") {
            continue;
        }
        $cols[strtolower($field)] = $field;
    }
    return $cols;
}

function incidencias_pick_column(array $columnsMap, array $candidates): ?string
{
    foreach ($candidates as $cand) {
        $key = strtolower(trim((string)$cand));
        if ($key !== "" && isset($columnsMap[$key])) {
            return $columnsMap[$key];
        }
    }
    return null;
}

function incidencias_ident(string $name): string
{
    return "`" . str_replace("`", "``", $name) . "`";
}

function incidencias_resolve_schema(PDO $pdo): array
{
    $mainTable = incidencias_first_existing_table($pdo, [
        "ClimaInstal_Incidencias",
        "ClimaInstal_Incidencia",
        "ClimaInstal_Incidencias_Pendientes"
    ]);

    if ($mainTable === null) {
        return [];
    }

    $mainCols = incidencias_get_columns($pdo, $mainTable);

    $schema = [
        "main_table" => $mainTable,
        "main_cols" => $mainCols,
        "id_col" => incidencias_pick_column($mainCols, ["id_incidencia", "id", "incidencia_id"]),
        "cliente_col" => incidencias_pick_column($mainCols, ["cliente", "nombre_cliente", "nombre"]),
        "direccion_col" => incidencias_pick_column($mainCols, ["direccion", "dir"]),
        "poblacion_col" => incidencias_pick_column($mainCols, ["poblacion", "ciudad", "municipio"]),
        "telefono_col" => incidencias_pick_column($mainCols, ["telefono", "telefono1", "tlf", "movil"]),
        "email_col" => incidencias_pick_column($mainCols, ["email", "correo"]),
        "prioridad_col" => incidencias_pick_column($mainCols, ["prioridad", "nivel_prioridad"]),
        "equipo_col" => incidencias_pick_column($mainCols, ["equipo_id", "id_equipo", "equipo"]),
        "estado_col" => incidencias_pick_column($mainCols, ["estado", "status"]),
        "usuario_col" => incidencias_pick_column($mainCols, ["usuario_solicita", "usuario", "autor", "creado_por"]),
        "fecha_solicitud_col" => incidencias_pick_column($mainCols, ["fecha_solicitud", "fecha", "date_add", "fecha_alta"]),
        "fecha_resolucion_col" => incidencias_pick_column($mainCols, ["fecha_resolucion", "fecha_cierre", "fecha_fin"]),
        "referencia_col" => incidencias_pick_column($mainCols, [
            "referencia",
            "pedido",
            "referencia_instalacion",
            "referencia_pedido",
            "ref_instalacion",
            "ref_pedido"
        ])
    ];

    $muroTable = incidencias_first_existing_table($pdo, [
        "ClimaInstal_Incidencias_Muro",
        "ClimaInstal_Incidencia_Muro"
    ]);
    if ($muroTable !== null) {
        $muroCols = incidencias_get_columns($pdo, $muroTable);
        $schema["muro_table"] = $muroTable;
        $schema["muro_cols"] = $muroCols;
        $schema["muro_rel_col"] = incidencias_pick_column($muroCols, ["id_incidencia", "incidencia_id", "id_relacionado", "id_incid"]);
        $schema["muro_id_col"] = incidencias_pick_column($muroCols, ["id"]);
        $schema["muro_mensaje_col"] = incidencias_pick_column($muroCols, ["mensaje", "texto", "comentario"]);
        $schema["muro_autor_col"] = incidencias_pick_column($muroCols, ["autor", "usuario"]);
        $schema["muro_rol_col"] = incidencias_pick_column($muroCols, ["rol", "tipo_usuario"]);
        $schema["muro_origen_col"] = incidencias_pick_column($muroCols, ["origen", "source"]);
        $schema["muro_fecha_col"] = incidencias_pick_column($muroCols, ["date_add", "fecha", "fecha_add"]);
    }

    $ficherosTable = incidencias_first_existing_table($pdo, [
        "ClimaInstal_Incidencias_Ficheros",
        "ClimaInstal_Incidencia_Ficheros"
    ]);
    if ($ficherosTable !== null) {
        $ficCols = incidencias_get_columns($pdo, $ficherosTable);
        $schema["ficheros_table"] = $ficherosTable;
        $schema["ficheros_cols"] = $ficCols;
        $schema["ficheros_rel_col"] = incidencias_pick_column($ficCols, ["id_incidencia", "incidencia_id", "id_relacionado", "id_incid"]);
        $schema["ficheros_id_col"] = incidencias_pick_column($ficCols, ["id"]);
        $schema["ficheros_tipo_col"] = incidencias_pick_column($ficCols, ["tipo"]);
        $schema["ficheros_ruta_col"] = incidencias_pick_column($ficCols, ["ruta", "documento", "url", "fichero"]);
        $schema["ficheros_tipo_fichero_col"] = incidencias_pick_column($ficCols, ["tipo_fichero", "extension", "ext"]);
        $schema["ficheros_usuario_col"] = incidencias_pick_column($ficCols, ["usuario", "autor"]);
        $schema["ficheros_fecha_col"] = incidencias_pick_column($ficCols, ["date_add", "fecha", "fecha_add"]);
    }

    return $schema;
}

function incidencias_prioridad_label($raw): string
{
    $n = visitas_normalize_prioridad_to_int((string)$raw);
    if ($n <= 0) {
        $clean = trim((string)$raw);
        return $clean === "" ? "Sin prioridad" : ucfirst(strtolower($clean));
    }
    return visitas_prioridad_label_from_int($n);
}

function incidencias_build_main_select(array $schema): string
{
    $map = [
        "id_incidencia" => $schema["id_col"] ?? null,
        "cliente" => $schema["cliente_col"] ?? null,
        "direccion" => $schema["direccion_col"] ?? null,
        "poblacion" => $schema["poblacion_col"] ?? null,
        "telefono" => $schema["telefono_col"] ?? null,
        "email" => $schema["email_col"] ?? null,
        "prioridad" => $schema["prioridad_col"] ?? null,
        "equipo_id" => $schema["equipo_col"] ?? null,
        "estado" => $schema["estado_col"] ?? null,
        "usuario_solicita" => $schema["usuario_col"] ?? null,
        "fecha_solicitud" => $schema["fecha_solicitud_col"] ?? null,
        "fecha_resolucion" => $schema["fecha_resolucion_col"] ?? null,
        "referencia" => $schema["referencia_col"] ?? null
    ];

    $parts = [];
    foreach ($map as $alias => $col) {
        if ($col !== null && $col !== "") {
            $parts[] = incidencias_ident($col) . " AS " . incidencias_ident($alias);
        } else {
            $parts[] = "NULL AS " . incidencias_ident($alias);
        }
    }

    return implode(",\n            ", $parts);
}

function incidencias_pending_where(array $schema): string
{
    $estado = $schema["estado_col"] ?? null;
    if ($estado) {
        $col = incidencias_ident($estado);
        return "(TRIM(CAST($col AS CHAR)) = '1')";
    }

    return "1=0";
}

function incidencias_prioridad_order_expr(array $schema): string
{
    $prioridad = $schema["prioridad_col"] ?? null;
    if (!$prioridad) {
        return "9";
    }

    $col = incidencias_ident($prioridad);
    return "CASE
        WHEN LOWER(TRIM(CAST($col AS CHAR))) IN ('alta', 'high', 'urgente') THEN 1
        WHEN LOWER(TRIM(CAST($col AS CHAR))) IN ('media', 'medio', 'normal') THEN 2
        WHEN LOWER(TRIM(CAST($col AS CHAR))) IN ('baja', 'low') THEN 3
        WHEN TRIM(CAST($col AS CHAR)) REGEXP '^[0-9]+$' THEN
            CASE
                WHEN CAST($col AS UNSIGNED) >= 3 THEN 1
                WHEN CAST($col AS UNSIGNED) = 2 THEN 2
                ELSE 3
            END
        ELSE 4
    END";
}

function incidencias_build_scope_clause(
    PDO $pdo,
    array $schema,
    string $equipoRaw,
    string $usuario,
    array &$params
): string {
    $equipoCol = $schema["equipo_col"] ?? null;
    if (!$equipoCol) {
        return "";
    }

    $equipoIds = visitas_resolve_equipo_ids($pdo, $equipoRaw, $usuario);
    if (empty($equipoIds)) {
        return "";
    }

    $ph = [];
    foreach ($equipoIds as $i => $id) {
        $key = ":equipo_" . $i;
        $ph[] = $key;
        $params[$key] = $id;
    }

    return incidencias_ident($equipoCol) . " IN (" . implode(",", $ph) . ")";
}

function incidencias_fetch_by_id(PDO $pdo, array $schema, int $idIncidencia): ?array
{
    $idCol = $schema["id_col"] ?? null;
    $mainTable = $schema["main_table"] ?? null;
    if (!$idCol || !$mainTable) {
        return null;
    }

    $sql = "SELECT
            " . incidencias_build_main_select($schema) . "
            FROM " . incidencias_ident($mainTable) . "
            WHERE " . incidencias_ident($idCol) . " = :id
            LIMIT 1";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([":id" => $idIncidencia]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    return $row ?: null;
}

function incidencias_authorize_row(
    PDO $pdo,
    array $schema,
    array $row,
    string $rol,
    string $usuario,
    string $equipoRaw
): bool {
    if (visitas_is_admin_role($rol)) {
        return true;
    }

    $authorized = false;

    $rowEquipo = trim((string)($row["equipo_id"] ?? ""));
    if ($rowEquipo !== "") {
        $equipoIds = visitas_resolve_equipo_ids($pdo, $equipoRaw, $usuario);
        if (preg_match('/^\\d+$/', $rowEquipo)) {
            $equipoNum = (int)$rowEquipo;
            if ($equipoNum > 0 && in_array($equipoNum, $equipoIds, true)) {
                $authorized = true;
            }
        } else {
            $tokens = visitas_split_equipo_tokens($equipoRaw);
            $rowEquipoNorm = strtolower($rowEquipo);
            foreach ($tokens as $tk) {
                if (strtolower(trim((string)$tk)) === $rowEquipoNorm) {
                    $authorized = true;
                    break;
                }
            }
        }
    }

    if (!$authorized && $usuario !== "") {
        $autorIncid = strtolower(trim((string)($row["usuario_solicita"] ?? "")));
        $usuarioNorm = strtolower(trim($usuario));
        if ($autorIncid !== "" && $autorIncid === $usuarioNorm) {
            $authorized = true;
        }
    }

    return $authorized;
}

function incidencias_build_file_url(string $ruta): string
{
    $clean = trim($ruta);
    if ($clean === "") {
        return "";
    }
    if (stripos($clean, "http://") === 0 || stripos($clean, "https://") === 0) {
        return $clean;
    }
    if ($clean[0] === '/') {
        return "https://clminstal.es" . $clean;
    }
    return "https://clminstal.es/" . $clean;
}

function incidencias_fetch_muro(PDO $pdo, array $schema, int $idIncidencia): array
{
    $table = $schema["muro_table"] ?? null;
    $relCol = $schema["muro_rel_col"] ?? null;
    if (!$table || !$relCol) {
        return [];
    }

    $idCol = $schema["muro_id_col"] ?? null;
    $msgCol = $schema["muro_mensaje_col"] ?? null;
    $autorCol = $schema["muro_autor_col"] ?? null;
    $rolCol = $schema["muro_rol_col"] ?? null;
    $origenCol = $schema["muro_origen_col"] ?? null;
    $fechaCol = $schema["muro_fecha_col"] ?? null;

    $select = [];
    $select[] = $idCol ? incidencias_ident($idCol) . " AS id" : "NULL AS id";
    $select[] = incidencias_ident($relCol) . " AS id_incidencia";
    $select[] = $msgCol ? incidencias_ident($msgCol) . " AS mensaje" : "NULL AS mensaje";
    $select[] = $autorCol ? incidencias_ident($autorCol) . " AS autor" : "NULL AS autor";
    $select[] = $rolCol ? incidencias_ident($rolCol) . " AS rol" : "NULL AS rol";
    $select[] = $origenCol ? incidencias_ident($origenCol) . " AS origen" : "NULL AS origen";
    $select[] = $fechaCol ? incidencias_ident($fechaCol) . " AS date_add" : "NULL AS date_add";

    $orderParts = [];
    if ($fechaCol) {
        $orderParts[] = incidencias_ident($fechaCol) . " DESC";
    }
    if ($idCol) {
        $orderParts[] = incidencias_ident($idCol) . " DESC";
    }
    if (empty($orderParts)) {
        $orderParts[] = incidencias_ident($relCol) . " DESC";
    }

    $sql = "SELECT\n            " . implode(",\n            ", $select) . "
            FROM " . incidencias_ident($table) . "
            WHERE " . incidencias_ident($relCol) . " = :id
            ORDER BY " . implode(", ", $orderParts);

    $stmt = $pdo->prepare($sql);
    $stmt->execute([":id" => $idIncidencia]);
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

function incidencias_fetch_ficheros(PDO $pdo, array $schema, int $idIncidencia): array
{
    $table = $schema["ficheros_table"] ?? null;
    $relCol = $schema["ficheros_rel_col"] ?? null;
    if (!$table || !$relCol) {
        return [];
    }

    $idCol = $schema["ficheros_id_col"] ?? null;
    $tipoCol = $schema["ficheros_tipo_col"] ?? null;
    $rutaCol = $schema["ficheros_ruta_col"] ?? null;
    $tipoFCol = $schema["ficheros_tipo_fichero_col"] ?? null;
    $usuarioCol = $schema["ficheros_usuario_col"] ?? null;
    $fechaCol = $schema["ficheros_fecha_col"] ?? null;

    if (!$rutaCol) {
        return [];
    }

    $select = [];
    $select[] = $idCol ? incidencias_ident($idCol) . " AS id" : "NULL AS id";
    $select[] = $tipoCol ? incidencias_ident($tipoCol) . " AS tipo" : "'INCIDENCIA' AS tipo";
    $select[] = incidencias_ident($relCol) . " AS id_relacionado";
    $select[] = incidencias_ident($rutaCol) . " AS ruta";
    $select[] = $tipoFCol ? incidencias_ident($tipoFCol) . " AS tipo_fichero" : "NULL AS tipo_fichero";
    $select[] = $usuarioCol ? incidencias_ident($usuarioCol) . " AS usuario" : "NULL AS usuario";
    $select[] = $fechaCol ? incidencias_ident($fechaCol) . " AS date_add" : "NULL AS date_add";

    $orderParts = [];
    if ($fechaCol) {
        $orderParts[] = incidencias_ident($fechaCol) . " DESC";
    }
    if ($idCol) {
        $orderParts[] = incidencias_ident($idCol) . " DESC";
    }

    $sql = "SELECT\n            " . implode(",\n            ", $select) . "
            FROM " . incidencias_ident($table) . "
            WHERE " . incidencias_ident($relCol) . " = :id";

    if (!empty($orderParts)) {
        $sql .= " ORDER BY " . implode(", ", $orderParts);
    }

    $stmt = $pdo->prepare($sql);
    $stmt->execute([":id" => $idIncidencia]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($rows as &$row) {
        $ruta = trim((string)($row["ruta"] ?? ""));
        $row["url"] = incidencias_build_file_url($ruta);
        $row["origen_fichero"] = "INCIDENCIA";
    }
    unset($row);

    return $rows;
}

function incidencias_fetch_instalacion_fotos(PDO $pdo, string $referencia, int $idIncidencia): array
{
    $ref = trim($referencia);
    if ($ref === "") {
        return [];
    }

    if (!incidencias_table_exists($pdo, "ClimaInstal_Fotografias")) {
        return [];
    }

    $claves = ["FOTOCLI", "PREINST", "DURINST", "POSTINST", "CONFCLI", "DOCCLI", "DOCUBOE", "DOC"];
    $placeholders = implode(",", array_fill(0, count($claves), "?"));

    $sql = "SELECT Documento, Clave
            FROM ClimaInstal_Fotografias
            WHERE Documento LIKE ?
              AND Clave IN ($placeholders)
            ORDER BY id DESC";

    $params = array_merge(["imagenes/" . $ref . "%"], $claves);
    $rows = [];

    try {
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        $fallbackLikes = [];
        $fallbackParams = [];
        foreach ($claves as $clave) {
            $suffix = $clave === "CONFCLI" ? "DOCCLI" : $clave;
            $fallbackLikes[] = "Documento LIKE ?";
            $fallbackParams[] = "imagenes/" . $ref . "-" . $suffix . "%";
        }
        $sql2 = "SELECT Documento
                 FROM ClimaInstal_Fotografias
                 WHERE " . implode(" OR ", $fallbackLikes) . "
                 ORDER BY id DESC";
        $stmt = $pdo->prepare($sql2);
        $stmt->execute($fallbackParams);
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
            $row["Clave"] = "INST";
            $rows[] = $row;
        }
    }

    $result = [];
    foreach ($rows as $row) {
        $doc = trim((string)($row["Documento"] ?? ""));
        if ($doc === "") {
            continue;
        }
        $clave = trim((string)($row["Clave"] ?? "INST"));
        $ext = strtolower(pathinfo($doc, PATHINFO_EXTENSION));
        $result[] = [
            "id" => 0,
            "tipo" => "INSTALACION",
            "id_relacionado" => $idIncidencia,
            "ruta" => $doc,
            "tipo_fichero" => $clave !== "" ? $clave : $ext,
            "usuario" => "Instalacion",
            "date_add" => null,
            "url" => incidencias_build_file_url($doc),
            "origen_fichero" => "INSTALACION"
        ];
    }

    return $result;
}

function incidencias_insert_muro(
    PDO $pdo,
    array $schema,
    int $idIncidencia,
    string $mensaje,
    string $autor,
    string $rol,
    string $origen = "APP_ANDROID"
): bool {
    $table = $schema["muro_table"] ?? null;
    $relCol = $schema["muro_rel_col"] ?? null;
    $msgCol = $schema["muro_mensaje_col"] ?? null;
    if (!$table || !$relCol || !$msgCol) {
        return false;
    }

    $mensajeClean = visitas_normalize_text($mensaje, 5000);
    if ($mensajeClean === "") {
        return false;
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

    $cols = [incidencias_ident($relCol), incidencias_ident($msgCol)];
    $vals = [":id_rel", ":mensaje"];
    $params = [
        ":id_rel" => $idIncidencia,
        ":mensaje" => $mensajeClean
    ];

    $autorCol = $schema["muro_autor_col"] ?? null;
    if ($autorCol) {
        $cols[] = incidencias_ident($autorCol);
        $vals[] = ":autor";
        $params[":autor"] = $autorClean;
    }
    $rolCol = $schema["muro_rol_col"] ?? null;
    if ($rolCol) {
        $cols[] = incidencias_ident($rolCol);
        $vals[] = ":rol";
        $params[":rol"] = $rolClean;
    }
    $origenCol = $schema["muro_origen_col"] ?? null;
    if ($origenCol) {
        $cols[] = incidencias_ident($origenCol);
        $vals[] = ":origen";
        $params[":origen"] = $origenClean;
    }
    $fechaCol = $schema["muro_fecha_col"] ?? null;
    if ($fechaCol) {
        $cols[] = incidencias_ident($fechaCol);
        $vals[] = "NOW()";
    }

    $sql = "INSERT INTO " . incidencias_ident($table)
        . " (" . implode(", ", $cols) . ")"
        . " VALUES (" . implode(", ", $vals) . ")";

    $stmt = $pdo->prepare($sql);
    return $stmt->execute($params);
}

function incidencias_insert_fichero(
    PDO $pdo,
    array $schema,
    int $idIncidencia,
    string $ruta,
    string $tipoFichero,
    string $usuario
): bool {
    $table = $schema["ficheros_table"] ?? null;
    $relCol = $schema["ficheros_rel_col"] ?? null;
    $rutaCol = $schema["ficheros_ruta_col"] ?? null;
    if (!$table || !$relCol || !$rutaCol) {
        return false;
    }

    $usuarioClean = visitas_normalize_text($usuario, 50);
    if ($usuarioClean === "") {
        $usuarioClean = "Instalador";
    }

    $cols = [incidencias_ident($relCol), incidencias_ident($rutaCol)];
    $vals = [":id_rel", ":ruta"];
    $params = [
        ":id_rel" => $idIncidencia,
        ":ruta" => $ruta
    ];

    $tipoCol = $schema["ficheros_tipo_col"] ?? null;
    if ($tipoCol) {
        $cols[] = incidencias_ident($tipoCol);
        $vals[] = ":tipo";
        $params[":tipo"] = "INCIDENCIA";
    }

    $tipoFCol = $schema["ficheros_tipo_fichero_col"] ?? null;
    if ($tipoFCol) {
        $cols[] = incidencias_ident($tipoFCol);
        $vals[] = ":tipo_fichero";
        $params[":tipo_fichero"] = $tipoFichero;
    }

    $usuarioCol = $schema["ficheros_usuario_col"] ?? null;
    if ($usuarioCol) {
        $cols[] = incidencias_ident($usuarioCol);
        $vals[] = ":usuario";
        $params[":usuario"] = $usuarioClean;
    }

    $fechaCol = $schema["ficheros_fecha_col"] ?? null;
    if ($fechaCol) {
        $cols[] = incidencias_ident($fechaCol);
        $vals[] = "NOW()";
    }

    $sql = "INSERT INTO " . incidencias_ident($table)
        . " (" . implode(", ", $cols) . ")"
        . " VALUES (" . implode(", ", $vals) . ")";

    $stmt = $pdo->prepare($sql);
    return $stmt->execute($params);
}

function incidencias_update_prioridad(PDO $pdo, array $schema, int $idIncidencia, int $prioridad): bool
{
    $table = $schema["main_table"] ?? null;
    $idCol = $schema["id_col"] ?? null;
    $priorCol = $schema["prioridad_col"] ?? null;
    if (!$table || !$idCol || !$priorCol) {
        return false;
    }

    $sql = "UPDATE " . incidencias_ident($table)
        . " SET " . incidencias_ident($priorCol) . " = :prioridad"
        . " WHERE " . incidencias_ident($idCol) . " = :id LIMIT 1";
    $stmt = $pdo->prepare($sql);
    return $stmt->execute([
        ":prioridad" => $prioridad,
        ":id" => $idIncidencia
    ]);
}

function incidencias_update_estado_resolucion(PDO $pdo, array $schema, int $idIncidencia, int $estado): bool
{
    $table = $schema["main_table"] ?? null;
    $idCol = $schema["id_col"] ?? null;
    $estadoCol = $schema["estado_col"] ?? null;
    if (!$table || !$idCol || !$estadoCol) {
        return false;
    }

    $setParts = [incidencias_ident($estadoCol) . " = :estado"];
    if (!empty($schema["fecha_resolucion_col"])) {
        $setParts[] = incidencias_ident($schema["fecha_resolucion_col"]) . " = NOW()";
    }

    $sql = "UPDATE " . incidencias_ident($table)
        . " SET " . implode(", ", $setParts)
        . " WHERE " . incidencias_ident($idCol) . " = :id LIMIT 1";
    $stmt = $pdo->prepare($sql);
    return $stmt->execute([
        ":estado" => $estado,
        ":id" => $idIncidencia
    ]);
}
