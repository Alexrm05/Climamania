<?php

function clm_eventos_normalize_text(string $value, int $maxLen): string
{
    $clean = trim(str_replace("\0", "", $value));
    if ($maxLen > 0 && mb_strlen($clean, "UTF-8") > $maxLen) {
        $clean = mb_substr($clean, 0, $maxLen, "UTF-8");
    }
    return $clean;
}

function clm_eventos_parse_coordinate($rawValue, string $field): float
{
    $value = trim((string)$rawValue);
    if ($value === "") {
        throw new InvalidArgumentException("Falta el campo " . $field);
    }
    $value = str_replace(",", ".", $value);
    if (!is_numeric($value)) {
        throw new InvalidArgumentException("El campo " . $field . " no es valido");
    }

    $number = (float)$value;
    if (!is_finite($number)) {
        throw new InvalidArgumentException("El campo " . $field . " no es valido");
    }

    if ($field === "latitud" && ($number < -90.0 || $number > 90.0)) {
        throw new InvalidArgumentException("La latitud no es valida");
    }
    if ($field === "longitud" && ($number < -180.0 || $number > 180.0)) {
        throw new InvalidArgumentException("La longitud no es valida");
    }

    return round($number, 7);
}

function clm_eventos_insert_location_event(PDO $pdo, array $event): void
{
    $tipoEvento = clm_eventos_normalize_text((string)($event["tipo_evento"] ?? ""), 50);
    if ($tipoEvento === "") {
        throw new InvalidArgumentException("tipo_evento requerido");
    }

    $latitud = clm_eventos_parse_coordinate($event["latitud"] ?? "", "latitud");
    $longitud = clm_eventos_parse_coordinate($event["longitud"] ?? "", "longitud");
    $referencia = clm_eventos_normalize_text((string)($event["referencia"] ?? ""), 64);
    $numeroPedido = clm_eventos_normalize_text((string)($event["numero_pedido"] ?? ""), 64);
    $tokenEvento = clm_eventos_normalize_text((string)($event["token_evento"] ?? ""), 64);
    $usuario = clm_eventos_normalize_text((string)($event["usuario"] ?? ""), 100);
    $origen = clm_eventos_normalize_text((string)($event["origen"] ?? "APP_ANDROID"), 30);
    $idPresupuesto = isset($event["id_presupuesto"]) ? (int)$event["id_presupuesto"] : 0;

    $stmt = $pdo->prepare(
        "INSERT INTO ClimaInstal_ControlUbicacionesEventos
            (referencia, id_presupuesto, numero_pedido, tipo_evento, token_evento, latitud, longitud, fecha_hora, usuario, origen)
         VALUES
            (:referencia, :id_presupuesto, :numero_pedido, :tipo_evento, :token_evento, :latitud, :longitud, NOW(), :usuario, :origen)"
    );

    try {
        $stmt->execute([
            ":referencia" => $referencia !== "" ? $referencia : null,
            ":id_presupuesto" => $idPresupuesto > 0 ? $idPresupuesto : null,
            ":numero_pedido" => $numeroPedido !== "" ? $numeroPedido : null,
            ":tipo_evento" => $tipoEvento,
            ":token_evento" => $tokenEvento !== "" ? $tokenEvento : null,
            ":latitud" => number_format($latitud, 7, ".", ""),
            ":longitud" => number_format($longitud, 7, ".", ""),
            ":usuario" => $usuario !== "" ? $usuario : null,
            ":origen" => $origen !== "" ? $origen : "APP_ANDROID"
        ]);
    } catch (PDOException $e) {
        if ($e->getCode() === "42S02") {
            throw new RuntimeException("No existe la tabla ClimaInstal_ControlUbicacionesEventos. Ejecuta el script SQL de la fase 6.");
        }
        if ($e->getCode() === "23000" && $tokenEvento !== "") {
            return;
        }
        throw $e;
    }
}

function clm_eventos_find_location_event_by_token(PDO $pdo, string $tipoEvento, string $tokenEvento): ?array
{
    $tipo = clm_eventos_normalize_text($tipoEvento, 50);
    $token = clm_eventos_normalize_text($tokenEvento, 64);
    if ($tipo === "" || $token === "") {
        return null;
    }

    $stmt = $pdo->prepare(
        "SELECT id, referencia, id_presupuesto, numero_pedido, tipo_evento, token_evento, latitud, longitud, fecha_hora, usuario, origen
         FROM ClimaInstal_ControlUbicacionesEventos
         WHERE tipo_evento = :tipo_evento
           AND token_evento = :token_evento
         LIMIT 1"
    );
    $stmt->execute([
        ":tipo_evento" => $tipo,
        ":token_evento" => $token
    ]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    return is_array($row) ? $row : null;
}
