<?php
// Escandallo: guarda el parte de trabajo (material consumido) de un pedido en
// ClimaInstal_ParteMateriales (una fila por artículo).
//
// La app envía siempre el parte completo: se borran las filas del pedido y se
// insertan las nuevas, conservando la fecha_creacion original si ya existía.
// Si llegan coordenadas, se registra la ubicación en
// ClimaInstal_ControlUbicacionesEventos (tipo PARTE_MATERIALES) sin que el
// usuario intervenga; si no llegan, se guarda el parte igualmente.
//
// POST: referencia, usuario, equipo, hora_inicio (HH:MM), hora_final (HH:MM),
//       latitud, longitud (opcionales),
//       lineas = JSON [{articulo, articulo_padre, descripcion, unidad,
//                       cantidad_prevista, cantidad, precio_unitario_sin_iva}]

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once __DIR__ . "/presupuestos_api_common.php";
require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/ubicaciones_eventos_common.php";

$API_KEY = "TEST123";
presup_require_api_key($API_KEY);

/// "HH:MM" o "HH:MM:SS" -> "HH:MM:SS"; null si no es válida.
function pm_parse_time(string $v): ?string
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

function pm_num($v): float
{
    return (float)str_replace(",", ".", trim((string)($v ?? "0")));
}

$pedido = presup_normalize_text(presup_request_value("referencia"), 64);
$usuario = presup_normalize_text(presup_request_value("usuario"), 100);
$equipo = presup_normalize_text(presup_request_value("equipo"), 100);
$horaInicio = pm_parse_time((string)presup_request_value("hora_inicio"));
$horaFinal = pm_parse_time((string)presup_request_value("hora_final"));
$latitud = trim((string)presup_request_value("latitud"));
$longitud = trim((string)presup_request_value("longitud"));
$lineasRaw = presup_request_value("lineas");

if ($pedido === "") {
    presup_json_exit(["success" => false, "message" => "Referencia requerida"], 400);
}
if ($horaInicio === null || $horaFinal === null) {
    presup_json_exit(["success" => false, "message" => "Indica la hora de llegada y de salida del domicilio"], 400);
}
if ($horaFinal <= $horaInicio) {
    presup_json_exit(["success" => false, "message" => "La hora de salida debe ser posterior a la de llegada"], 400);
}

$lineasIn = is_string($lineasRaw) ? json_decode($lineasRaw, true) : $lineasRaw;
if (!is_array($lineasIn) || empty($lineasIn)) {
    presup_json_exit(["success" => false, "message" => "Añade al menos un material al parte"], 400);
}

$lineas = [];
foreach ($lineasIn as $item) {
    if (!is_array($item)) {
        continue;
    }
    $articulo = presup_normalize_text((string)($item["articulo"] ?? ""), 64);
    if ($articulo === "") {
        continue;
    }
    $cantidad = pm_num($item["cantidad"] ?? 0);
    $prevista = pm_num($item["cantidad_prevista"] ?? 0);
    // Se guarda todo lo que tenga consumo real o previsión: así el parte
    // refleja también lo previsto y no gastado (desviación negativa).
    if ($cantidad <= 0 && $prevista <= 0) {
        continue;
    }
    $padre = presup_normalize_text((string)($item["articulo_padre"] ?? ""), 64);
    $lineas[] = [
        "articulo" => $articulo,
        "padre" => $padre !== "" ? $padre : null,
        "descripcion" => presup_normalize_text((string)($item["descripcion"] ?? ""), 255),
        "unidad" => presup_normalize_text((string)($item["unidad"] ?? "ud"), 10) ?: "ud",
        "prevista" => round(max(0.0, $prevista), 2),
        "cantidad" => round(max(0.0, $cantidad), 2),
        "precio" => round(max(0.0, pm_num($item["precio_unitario_sin_iva"] ?? 0)), 6)
    ];
}
if (empty($lineas)) {
    presup_json_exit(["success" => false, "message" => "Ningún material tiene cantidad"], 400);
}

$pdo = null;
try {
    $pdo = getDBConnection();
    $pdo->beginTransaction();

    $stmt = $pdo->prepare("SELECT MIN(fecha_creacion) FROM ClimaInstal_ParteMateriales WHERE pedido = :pedido FOR UPDATE");
    $stmt->execute([":pedido" => $pedido]);
    $fechaCreacion = $stmt->fetchColumn();
    $existia = is_string($fechaCreacion) && $fechaCreacion !== "";

    $pdo->prepare("DELETE FROM ClimaInstal_ParteMateriales WHERE pedido = :pedido")
        ->execute([":pedido" => $pedido]);

    $ins = $pdo->prepare(
        "INSERT INTO ClimaInstal_ParteMateriales
            (pedido, articulo, articulo_padre, descripcion, unidad, cantidad_prevista, cantidad,
             hora_inicio, hora_final, precio_unitario_sin_iva,
             usuario, equipo_instaladores, fecha_creacion, fecha_edicion)
         VALUES
            (:pedido, :articulo, :padre, :descripcion, :unidad, :prevista, :cantidad,
             :hora_inicio, :hora_final, :precio,
             :usuario, :equipo, " . ($existia ? ":fecha_creacion" : "NOW()") . ", NOW())"
    );
    foreach ($lineas as $l) {
        $params = [
            ":pedido" => $pedido,
            ":articulo" => $l["articulo"],
            ":padre" => $l["padre"],
            ":descripcion" => $l["descripcion"],
            ":unidad" => $l["unidad"],
            ":prevista" => number_format($l["prevista"], 2, ".", ""),
            ":cantidad" => number_format($l["cantidad"], 2, ".", ""),
            ":hora_inicio" => $horaInicio,
            ":hora_final" => $horaFinal,
            ":precio" => number_format($l["precio"], 6, ".", ""),
            ":usuario" => $usuario !== "" ? $usuario : null,
            ":equipo" => $equipo !== "" ? $equipo : null
        ];
        if ($existia) {
            $params[":fecha_creacion"] = $fechaCreacion;
        }
        $ins->execute($params);
    }

    // Ubicación silenciosa: solo si la app pudo obtenerla.
    $ubicacionRegistrada = false;
    if ($latitud !== "" && $longitud !== "") {
        try {
            clm_eventos_insert_location_event($pdo, [
                "referencia" => $pedido,
                "numero_pedido" => $pedido,
                "tipo_evento" => "PARTE_MATERIALES",
                "token_evento" => "PM_" . $pedido . "_" . date("YmdHis"),
                "latitud" => $latitud,
                "longitud" => $longitud,
                "usuario" => $usuario,
                "origen" => "APP"
            ]);
            $ubicacionRegistrada = true;
        } catch (Throwable $e) {
            // La ubicación es complementaria: no impide guardar el parte.
        }
    }

    $pdo->commit();

    $minutos = (strtotime("1970-01-01 " . $horaFinal) - strtotime("1970-01-01 " . $horaInicio)) / 60;

    presup_json_exit([
        "success" => true,
        "message" => $existia ? "Parte de trabajo actualizado" : "Parte de trabajo guardado",
        "num_lineas" => count($lineas),
        "minutos_invertidos" => (int)$minutos,
        "ubicacion_registrada" => $ubicacionRegistrada
    ]);
} catch (PDOException $e) {
    if ($pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    if ($e->getCode() === "42S02") {
        presup_json_exit(["success" => false, "message" => "No existe la tabla ClimaInstal_ParteMateriales. Ejecuta el SQL del escandallo."], 200);
    }
    presup_json_exit(["success" => false, "message" => "ERROR: " . $e->getMessage()], 200);
} catch (Throwable $e) {
    if ($pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    presup_json_exit(["success" => false, "message" => $e->getMessage()], 200);
}
