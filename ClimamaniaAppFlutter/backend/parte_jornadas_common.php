<?php
// Escandallo: jornadas de un parte de trabajo (ClimaInstal_ParteJornadas).
//
// Una instalación puede ocupar varios días: cada jornada es una fecha con su
// hora de llegada y de salida. El material y el técnico son del parte
// entero, no de cada jornada.
//
// Los partes creados antes de esta tabla no tienen jornadas: para ellos se
// construye una a partir de la fecha de creación y de las horas guardadas en
// ClimaInstal_ParteMateriales, así se siguen viendo y editando igual.

const CLM_JORNADAS_TABLA = "ClimaInstal_ParteJornadas";

/// "HH:MM" o "HH:MM:SS" -> "HH:MM:SS"; null si no es válida.
function clm_jornada_hora(string $v): ?string
{
    $v = trim($v);
    if (!preg_match('/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/', $v, $m)) {
        return null;
    }
    $h = (int)$m[1];
    $i = (int)$m[2];
    if ($h > 23 || $i > 59) {
        return null;
    }
    return sprintf("%02d:%02d:00", $h, $i);
}

/// "YYYY-MM-DD" -> misma cadena; null si no es una fecha válida.
function clm_jornada_fecha(string $v): ?string
{
    $v = trim(substr($v, 0, 10));
    if (!preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $v, $m)) {
        return null;
    }
    return checkdate((int)$m[2], (int)$m[3], (int)$m[1]) ? $v : null;
}

function clm_jornada_minutos(string $inicio, string $final): int
{
    $a = strtotime("1970-01-01 " . $inicio);
    $b = strtotime("1970-01-01 " . $final);
    return (int)(($b - $a) / 60);
}

/// Jornadas guardadas de un pedido, ordenadas por fecha y hora.
/// Devuelve [] si la tabla aún no existe.
function clm_jornadas_de_pedido(PDO $pdo, string $pedido): array
{
    try {
        $stmt = $pdo->prepare(
            "SELECT fecha, hora_inicio, hora_final
             FROM " . CLM_JORNADAS_TABLA . "
             WHERE pedido = :pedido
             ORDER BY fecha ASC, hora_inicio ASC"
        );
        $stmt->execute([":pedido" => $pedido]);
    } catch (PDOException $e) {
        if ($e->getCode() === "42S02") {
            return [];
        }
        throw $e;
    }
    $out = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
        $ini = substr((string)$r["hora_inicio"], 0, 5);
        $fin = substr((string)$r["hora_final"], 0, 5);
        $out[] = [
            "fecha" => (string)$r["fecha"],
            "hora_inicio" => $ini,
            "hora_final" => $fin,
            "minutos" => clm_jornada_minutos($ini, $fin)
        ];
    }
    return $out;
}

/// Jornada deducida de un parte antiguo (una sola, con la fecha de creación).
/// [] si el parte no tiene horas guardadas.
function clm_jornada_heredada(array $filaParte): array
{
    $ini = substr((string)($filaParte["hora_inicio"] ?? ""), 0, 5);
    $fin = substr((string)($filaParte["hora_final"] ?? ""), 0, 5);
    $fecha = clm_jornada_fecha((string)($filaParte["fecha_creacion"] ?? ""));
    if ($ini === "" || $fin === "" || $fecha === null) {
        return [];
    }
    return [[
        "fecha" => $fecha,
        "hora_inicio" => $ini,
        "hora_final" => $fin,
        "minutos" => clm_jornada_minutos($ini, $fin)
    ]];
}

/// Valida y normaliza las jornadas que manda la app.
/// Devuelve ["jornadas" => [...], "error" => string].
function clm_jornadas_normaliza($entrada): array
{
    $lista = is_string($entrada) ? json_decode($entrada, true) : $entrada;
    if (!is_array($lista)) {
        return ["jornadas" => [], "error" => "Jornadas no válidas"];
    }
    $out = [];
    $vistas = [];
    foreach ($lista as $j) {
        if (!is_array($j)) {
            continue;
        }
        $fecha = clm_jornada_fecha((string)($j["fecha"] ?? ""));
        $ini = clm_jornada_hora((string)($j["hora_inicio"] ?? ""));
        $fin = clm_jornada_hora((string)($j["hora_final"] ?? ""));
        if ($fecha === null) {
            return ["jornadas" => [], "error" => "Indica la fecha de cada jornada"];
        }
        if ($ini === null || $fin === null) {
            return ["jornadas" => [], "error" => "Indica la hora de llegada y de salida de cada jornada"];
        }
        if ($fin <= $ini) {
            return ["jornadas" => [], "error" => "En cada jornada la hora de salida debe ser posterior a la de llegada"];
        }
        $clave = $fecha . " " . $ini;
        if (isset($vistas[$clave])) {
            continue; // misma fecha y hora de llegada: se ignora el duplicado
        }
        $vistas[$clave] = true;
        $out[] = ["fecha" => $fecha, "hora_inicio" => $ini, "hora_final" => $fin];
    }
    if (empty($out)) {
        return ["jornadas" => [], "error" => "Añade al menos una jornada con sus horas"];
    }
    usort($out, fn($a, $b) => [$a["fecha"], $a["hora_inicio"]] <=> [$b["fecha"], $b["hora_inicio"]]);
    return ["jornadas" => $out, "error" => ""];
}

/// Reemplaza las jornadas del pedido. Conserva la fecha_creacion original.
function clm_jornadas_guarda(
    PDO $pdo,
    string $pedido,
    array $jornadas,
    string $usuario,
    string $equipo
): void {
    $stmt = $pdo->prepare(
        "SELECT MIN(fecha_creacion) FROM " . CLM_JORNADAS_TABLA . " WHERE pedido = :pedido"
    );
    $stmt->execute([":pedido" => $pedido]);
    $creacion = $stmt->fetchColumn();
    $existia = is_string($creacion) && $creacion !== "";

    $pdo->prepare("DELETE FROM " . CLM_JORNADAS_TABLA . " WHERE pedido = :pedido")
        ->execute([":pedido" => $pedido]);

    $ins = $pdo->prepare(
        "INSERT INTO " . CLM_JORNADAS_TABLA . "
            (pedido, fecha, hora_inicio, hora_final, usuario, equipo_instaladores,
             fecha_creacion, fecha_edicion)
         VALUES
            (:pedido, :fecha, :ini, :fin, :usuario, :equipo,
             " . ($existia ? ":creacion" : "NOW()") . ", NOW())"
    );
    foreach ($jornadas as $j) {
        $params = [
            ":pedido" => $pedido,
            ":fecha" => $j["fecha"],
            ":ini" => $j["hora_inicio"],
            ":fin" => $j["hora_final"],
            ":usuario" => $usuario !== "" ? $usuario : null,
            ":equipo" => $equipo !== "" ? $equipo : null
        ];
        if ($existia) {
            $params[":creacion"] = $creacion;
        }
        $ins->execute($params);
    }
}
