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
// Las horas son una lista de jornadas (la instalación puede durar varios
// días); el material y el técnico son del parte entero. Las versiones
// antiguas de la app mandan un solo par hora_inicio/hora_final: se guarda
// como una jornada con la fecha de hoy.
//
// POST: referencia, usuario, equipo,
//       jornadas = JSON [{fecha (YYYY-MM-DD), hora_inicio, hora_final}],
//       hora_inicio (HH:MM), hora_final (HH:MM) -> solo compatibilidad,
//       latitud, longitud (opcionales),
//       lineas = JSON [{articulo, articulo_padre, descripcion, unidad,
//                       cantidad_prevista, cantidad}]
//
// El artículo se guarda siempre con el código CINST del catálogo
// (ClimaSinc_ClimaInstal_Consumibles): es la clave con la que GOTEL descuenta
// el stock de la furgoneta. Si una app antigua manda el IdGotel, se traduce.
// La unidad también sale del catálogo, el precio se guarda a 0 (GOTEL calcula
// el coste con sus precios) y las horas quedan vacías: están en
// ClimaInstal_ParteJornadas.
//
// El parte no se borra y se reinserta: se actualizan las líneas que cambian,
// se insertan las nuevas y se borran las que el técnico quitó. Así los `id`
// de las que no cambian se conservan, que es como GOTEL sigue el stock.

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once __DIR__ . "/presupuestos_api_common.php";
require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/ubicaciones_eventos_common.php";
require_once __DIR__ . "/parte_jornadas_common.php";
require_once __DIR__ . "/consumibles_common.php";

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
$jornadasRaw = presup_request_value("jornadas");
$horaInicio = pm_parse_time((string)presup_request_value("hora_inicio"));
$horaFinal = pm_parse_time((string)presup_request_value("hora_final"));
$latitud = trim((string)presup_request_value("latitud"));
$longitud = trim((string)presup_request_value("longitud"));
$lineasRaw = presup_request_value("lineas");

if ($pedido === "") {
    presup_json_exit(["success" => false, "message" => "Referencia requerida"], 400);
}
// Jornadas. Si la app no las manda (versión antigua), se construye una con
// el par de horas suelto y la fecha de hoy.
if ($jornadasRaw === null || $jornadasRaw === "") {
    if ($horaInicio === null || $horaFinal === null) {
        presup_json_exit(["success" => false, "message" => "Indica la hora de llegada y de salida del domicilio"], 400);
    }
    $jornadasRaw = [[
        "fecha" => date("Y-m-d"),
        "hora_inicio" => $horaInicio,
        "hora_final" => $horaFinal
    ]];
}
$norm = clm_jornadas_normaliza($jornadasRaw);
if ($norm["error"] !== "") {
    presup_json_exit(["success" => false, "message" => $norm["error"]], 400);
}
$jornadas = $norm["jornadas"];

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
        "cantidad" => round(max(0.0, $cantidad), 2)
    ];
}
if (empty($lineas)) {
    presup_json_exit(["success" => false, "message" => "Ningún material tiene cantidad"], 400);
}

$pdo = null;
try {
    $pdo = getDBConnection();
    $pdo->beginTransaction();

    // El artículo y la unidad los manda el catálogo, no la app: así una
    // versión antigua que envíe el IdGotel acaba guardando el código CINST.
    $catalogo = clm_consumibles_por_claves(
        $pdo,
        array_column($lineas, "articulo")
    );
    $desconocidos = [];
    foreach ($lineas as $i => $l) {
        $mat = $catalogo[strtoupper($l["articulo"])] ?? null;
        if ($mat === null) {
            $desconocidos[] = $l["articulo"];
            continue;
        }
        $lineas[$i]["articulo"] = $mat["articulo"];
        // La columna es VARCHAR(10): una unidad más larga tiraría el guardado
        // entero con STRICT_TRANS_TABLES.
        $lineas[$i]["unidad"] = presup_normalize_text($mat["unidad"], 10) ?: "ud";
    }

    // Un mismo artículo no puede ir dos veces en el parte: si la app lo
    // repite, se queda la última cantidad.
    $porArticulo = [];
    foreach ($lineas as $l) {
        $porArticulo[$l["articulo"]] = $l;
    }
    $lineas = array_values($porArticulo);

    $stmt = $pdo->prepare(
        "SELECT id, articulo, articulo_padre, descripcion, unidad,
                cantidad_prevista, cantidad, fecha_creacion
         FROM ClimaInstal_ParteMateriales
         WHERE pedido = :pedido
         ORDER BY id ASC
         FOR UPDATE"
    );
    $stmt->execute([":pedido" => $pedido]);
    $previas = [];
    $sobrantes = [];
    $fechaCreacion = null;
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
        $fechaCreacion = $fechaCreacion ?? $r["fecha_creacion"];
        $matPrevio = $catalogo[strtoupper((string)$r["articulo"])] ?? null;
        $clave = $matPrevio !== null ? $matPrevio["articulo"] : (string)$r["articulo"];
        if (isset($previas[$clave])) {
            // Duplicado de antes de este cambio: sobra.
            $sobrantes[] = (int)$r["id"];
            continue;
        }
        $previas[$clave] = $r;
    }
    $existia = $fechaCreacion !== null;

    $ins = $pdo->prepare(
        "INSERT INTO ClimaInstal_ParteMateriales
            (pedido, articulo, articulo_padre, descripcion, unidad, cantidad_prevista, cantidad,
             hora_inicio, hora_final, precio_unitario_sin_iva,
             usuario, equipo_instaladores, fecha_creacion, fecha_edicion)
         VALUES
            (:pedido, :articulo, :padre, :descripcion, :unidad, :prevista, :cantidad,
             NULL, NULL, 0,
             :usuario, :equipo, " . ($existia ? ":fecha_creacion" : "NOW()") . ", NOW())"
    );
    $upd = $pdo->prepare(
        "UPDATE ClimaInstal_ParteMateriales
            SET articulo = :articulo, articulo_padre = :padre, descripcion = :descripcion, unidad = :unidad,
                cantidad_prevista = :prevista, cantidad = :cantidad,
                hora_inicio = NULL, hora_final = NULL, precio_unitario_sin_iva = 0,
                usuario = :usuario, equipo_instaladores = :equipo, fecha_edicion = NOW()
          WHERE id = :id"
    );

    $nuevas = 0;
    $modificadas = 0;
    $vistas = [];
    foreach ($lineas as $l) {
        $prevista = number_format($l["prevista"], 2, ".", "");
        $cantidad = number_format($l["cantidad"], 2, ".", "");
        $previa = $previas[$l["articulo"]] ?? null;
        if ($previa === null) {
            $params = [
                ":pedido" => $pedido,
                ":articulo" => $l["articulo"],
                ":padre" => $l["padre"],
                ":descripcion" => $l["descripcion"],
                ":unidad" => $l["unidad"],
                ":prevista" => $prevista,
                ":cantidad" => $cantidad,
                ":usuario" => $usuario !== "" ? $usuario : null,
                ":equipo" => $equipo !== "" ? $equipo : null
            ];
            if ($existia) {
                $params[":fecha_creacion"] = $fechaCreacion;
            }
            $ins->execute($params);
            $nuevas++;
            continue;
        }
        $vistas[$l["articulo"]] = true;
        // fecha_edicion solo se mueve si algo cambió de verdad: GOTEL la usa
        // para detectar qué líneas tiene que reajustar.
        $igual = (string)$previa["articulo"] === $l["articulo"]
            && (string)$previa["articulo_padre"] === (string)$l["padre"]
            && (string)$previa["descripcion"] === $l["descripcion"]
            && (string)$previa["unidad"] === $l["unidad"]
            && (float)$previa["cantidad_prevista"] === (float)$prevista
            && (float)$previa["cantidad"] === (float)$cantidad;
        if ($igual) {
            continue;
        }
        $upd->execute([
            ":articulo" => $l["articulo"],
            ":padre" => $l["padre"],
            ":descripcion" => $l["descripcion"],
            ":unidad" => $l["unidad"],
            ":prevista" => $prevista,
            ":cantidad" => $cantidad,
            ":usuario" => $usuario !== "" ? $usuario : null,
            ":equipo" => $equipo !== "" ? $equipo : null,
            ":id" => (int)$previa["id"]
        ]);
        $modificadas++;
    }

    // Lo que ya no manda la app es que el técnico lo ha quitado del parte.
    foreach ($previas as $clave => $r) {
        if (!isset($vistas[$clave])) {
            $sobrantes[] = (int)$r["id"];
        }
    }
    $borradas = 0;
    if (!empty($sobrantes)) {
        $ph = implode(",", array_fill(0, count($sobrantes), "?"));
        $del = $pdo->prepare("DELETE FROM ClimaInstal_ParteMateriales WHERE id IN ($ph)");
        $del->execute($sobrantes);
        $borradas = count($sobrantes);
    }

    clm_jornadas_guarda($pdo, $pedido, $jornadas, $usuario, $equipo);

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

    $minutos = 0;
    foreach ($jornadas as $j) {
        $minutos += clm_jornada_minutos($j["hora_inicio"], $j["hora_final"]);
    }

    presup_json_exit([
        "success" => true,
        "message" => $existia ? "Parte de trabajo actualizado" : "Parte de trabajo guardado",
        "num_lineas" => count($lineas),
        "lineas_nuevas" => $nuevas,
        "lineas_modificadas" => $modificadas,
        "lineas_borradas" => $borradas,
        "articulos_fuera_de_catalogo" => $desconocidos,
        "num_jornadas" => count($jornadas),
        "minutos_invertidos" => (int)$minutos,
        "ubicacion_registrada" => $ubicacionRegistrada
    ]);
} catch (PDOException $e) {
    if ($pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    if ($e->getCode() === "42S02") {
        presup_json_exit(["success" => false, "message" => "Falta una tabla del escandallo (ParteMateriales o ParteJornadas). Ejecuta el SQL pendiente."], 200);
    }
    presup_json_exit(["success" => false, "message" => "ERROR: " . $e->getMessage()], 200);
} catch (Throwable $e) {
    if ($pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    presup_json_exit(["success" => false, "message" => $e->getMessage()], 200);
}
