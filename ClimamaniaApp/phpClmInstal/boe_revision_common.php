<?php

function boe_revision_request_value(string $key): string
{
    if (isset($_POST[$key])) {
        return trim((string)$_POST[$key]);
    }
    if (isset($_GET[$key])) {
        return trim((string)$_GET[$key]);
    }
    return "";
}

function boe_revision_json_exit(array $payload, int $status = 200): void
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

function boe_revision_require_api_key(string $expected): void
{
    if (boe_revision_request_value("api_key") !== $expected) {
        boe_revision_json_exit(["success" => false, "message" => "API key invalida"], 401);
    }
}

function boe_revision_normalize_text(string $value, int $maxLen = 255): string
{
    $clean = trim(str_replace("\0", "", $value));
    if ($maxLen > 0 && mb_strlen($clean, "UTF-8") > $maxLen) {
        $clean = mb_substr($clean, 0, $maxLen, "UTF-8");
    }
    return $clean;
}

function boe_revision_parse_lineas(string $jsonRaw): array
{
    $decoded = json_decode($jsonRaw, true);
    if (!is_array($decoded)) {
        return [];
    }

    $lineas = [];
    $orden = 1;
    foreach ($decoded as $row) {
        if (!is_array($row)) {
            continue;
        }
        $codigo = boe_revision_normalize_text((string)($row["codigo"] ?? ""), 120);
        $numSerie = boe_revision_normalize_text((string)($row["num_serie"] ?? ($row["numSerie"] ?? "")), 255);
        if ($codigo === "" && $numSerie === "") {
            continue;
        }
        if ($codigo === "") {
            continue;
        }
        $lineas[] = [
            "orden_linea" => $orden,
            "codigo" => $codigo,
            "num_serie" => $numSerie
        ];
        $orden++;
    }

    return $lineas;
}
