<?php
// Catálogo de materiales del escandallo: ClimaSinc_ClimaInstal_Consumibles
// (sincronizada desde PrestaShop). Sustituye a la búsqueda por categoría en
// la tienda, de modo que el escandallo no depende de que PrestaShop responda.
//
// Columnas: Id, IdGotel, Codigo, Nombre, Descripcion, UnidadEscandallo,
//           Factor, Revisado.
//
// IMPORTANTE: el identificador que se guarda en el parte es **IdGotel**, no
// Id (que puede variar al resincronizar). Codigo es solo para que el técnico
// reconozca el material.

const CLM_CONSUMIBLES_TABLA = "ClimaSinc_ClimaInstal_Consumibles";

/// Fila de la tabla -> material tal como lo consume la app.
function clm_consumible_salida(array $r): array
{
    $unidad = trim((string)($r["UnidadEscandallo"] ?? ""));
    $nombre = trim((string)($r["Nombre"] ?? ""));
    $desc = trim((string)($r["Descripcion"] ?? ""));
    return [
        // Lo que se guarda en ClimaInstal_ParteMateriales.articulo.
        "articulo" => trim((string)($r["IdGotel"] ?? "")),
        "codigo" => trim((string)($r["Codigo"] ?? "")),
        "descripcion" => $nombre !== "" ? $nombre : $desc,
        "unidad" => $unidad !== "" ? $unidad : "ud",
        "factor" => number_format((float)($r["Factor"] ?? 1), 4, ".", ""),
        "precio_unitario_sin_iva" => "0.000000"
    ];
}

/// Materiales cuyo IdGotel o Codigo está en [$claves]. Devuelve un mapa
/// indexado por ambos (en mayúsculas), para poder resolver una referencia
/// venga como venga. Vacío si la tabla aún no existe.
function clm_consumibles_por_claves(PDO $pdo, array $claves): array
{
    $claves = array_values(array_unique(array_filter(array_map(
        fn($v) => trim((string)$v),
        $claves
    ), fn($v) => $v !== "")));
    if (empty($claves)) {
        return [];
    }
    $ph = implode(",", array_fill(0, count($claves), "?"));
    $sql = "SELECT IdGotel, Codigo, Nombre, Descripcion, UnidadEscandallo, Factor
            FROM " . CLM_CONSUMIBLES_TABLA . "
            WHERE IdGotel IN ($ph) OR Codigo IN ($ph)";
    try {
        $stmt = $pdo->prepare($sql);
        $stmt->execute(array_merge($claves, $claves));
    } catch (PDOException $e) {
        if ($e->getCode() === "42S02") {
            return [];
        }
        throw $e;
    }
    $out = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
        $mat = clm_consumible_salida($r);
        foreach ([$mat["articulo"], $mat["codigo"]] as $k) {
            if ($k !== "") {
                $out[strtoupper($k)] = $mat;
            }
        }
    }
    return $out;
}

/// Completa una línea (guardada o por defecto) con los datos del catálogo:
/// pasa la referencia a IdGotel y añade el código legible. Si el material no
/// está en el catálogo, se deja como está y se marca en_catalogo = false.
function clm_consumible_completa(array $linea, array $catalogo): array
{
    $clave = strtoupper(trim((string)($linea["articulo"] ?? "")));
    $mat = $catalogo[$clave] ?? null;
    if ($mat === null) {
        $linea["codigo"] = (string)($linea["codigo"] ?? $linea["articulo"] ?? "");
        $linea["en_catalogo"] = false;
        return $linea;
    }
    $linea["articulo"] = $mat["articulo"];
    $linea["codigo"] = $mat["codigo"];
    if (trim((string)($linea["descripcion"] ?? "")) === "") {
        $linea["descripcion"] = $mat["descripcion"];
    }
    if (trim((string)($linea["unidad"] ?? "")) === "") {
        $linea["unidad"] = $mat["unidad"];
    }
    $linea["en_catalogo"] = true;
    return $linea;
}
