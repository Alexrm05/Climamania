<?php
// Catálogo de materiales del escandallo: ClimaSinc_ClimaInstal_Consumibles
// (sincronizada desde PrestaShop). Sustituye a la búsqueda por categoría en
// la tienda, de modo que el escandallo no depende de que PrestaShop responda.
//
// Columnas: Id, IdGotel, Codigo, Nombre, Descripcion, UnidadEscandallo,
//           Factor, Revisado.
//
// IMPORTANTE: el identificador que se guarda en el parte es **Codigo**
// (CINST0300010), nunca Id ni IdGotel: es la clave con la que GOTEL descuenta
// el stock de la furgoneta. El Id de esta tabla cambia al resincronizar y el
// IdGotel no es su clave de negocio.

const CLM_CONSUMIBLES_TABLA = "ClimaSinc_ClimaInstal_Consumibles";

/// Fila de la tabla -> material tal como lo consume la app.
function clm_consumible_salida(array $r): array
{
    $unidad = trim((string)($r["UnidadEscandallo"] ?? ""));
    $nombre = trim((string)($r["Nombre"] ?? ""));
    $desc = trim((string)($r["Descripcion"] ?? ""));
    $codigo = trim((string)($r["Codigo"] ?? ""));
    return [
        // Lo que se guarda en ClimaInstal_ParteMateriales.articulo.
        "articulo" => $codigo,
        // Mismo valor: lo siguen leyendo versiones antiguas de la app.
        "codigo" => $codigo,
        "id_gotel" => trim((string)($r["IdGotel"] ?? "")),
        "descripcion" => $nombre !== "" ? $nombre : $desc,
        "unidad" => $unidad !== "" ? $unidad : "ud",
        "factor" => number_format((float)($r["Factor"] ?? 1), 4, ".", ""),
        // El precio no se guarda en el parte: se lee en vivo del catálogo
        // cuando GOTEL añada la columna de coste (clm_consumibles_precio_columna).
        "precio_unitario_sin_iva" => isset($r["_precio"])
            ? number_format((float)$r["_precio"], 6, ".", "")
            : "0.000000"
    ];
}

/// Materiales cuyo Codigo o IdGotel está en [$claves]. El mapa se indexa por
/// ambos (en mayúsculas) para resolver una referencia venga como venga: así
/// las filas antiguas, guardadas con el IdGotel, se corrigen solas al pasar
/// por clm_consumible_completa(). Vacío si la tabla aún no existe.
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
    $sql = "SELECT IdGotel, Codigo, Nombre, Descripcion, UnidadEscandallo, Factor"
        . clm_consumibles_precio_select($pdo) . "
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
        // Indexado también por IdGotel: las versiones de la app anteriores a
        // octubre de 2026 mandan ese valor y hay que poder traducirlo.
        foreach ([$mat["articulo"], $mat["id_gotel"]] as $k) {
            if ($k !== "") {
                $out[strtoupper($k)] = $mat;
            }
        }
    }
    return $out;
}

/// Completa una línea (guardada o por defecto) con los datos del catálogo:
/// pasa la referencia al Codigo y pone la unidad del catálogo, que es la que
/// manda. Si el material no está en el catálogo, se deja como está y se marca
/// en_catalogo = false.
///
/// [$forzarDescripcion] = true para los materiales por defecto: su texto sale
/// siempre del catálogo, porque el guardado en la plantilla se desincroniza.
/// Para las líneas ya grabadas es false: el técnico puede editar la
/// descripción y lo que dejó escrito se respeta.
function clm_consumible_completa(
    array $linea,
    array $catalogo,
    bool $forzarDescripcion = false
): array {
    $clave = strtoupper(trim((string)($linea["articulo"] ?? "")));
    $mat = $catalogo[$clave] ?? null;
    if ($mat === null) {
        $linea["codigo"] = (string)($linea["codigo"] ?? $linea["articulo"] ?? "");
        $linea["en_catalogo"] = false;
        return $linea;
    }
    $linea["articulo"] = $mat["articulo"];
    $linea["codigo"] = $mat["codigo"];
    if ($forzarDescripcion || trim((string)($linea["descripcion"] ?? "")) === "") {
        $linea["descripcion"] = $mat["descripcion"];
    }
    $linea["unidad"] = $mat["unidad"];
    $linea["precio_unitario_sin_iva"] = $mat["precio_unitario_sin_iva"];
    $linea["en_catalogo"] = true;
    return $linea;
}

/// Nombre de la columna de precio de coste del catálogo, o null si GOTEL aún
/// no la ha añadido. El precio nunca se guarda en el parte: se lee de aquí
/// cada vez, así que el día que exista la columna empieza a mostrarse sin
/// tocar código.
function clm_consumibles_precio_columna(PDO $pdo): ?string
{
    static $cache = false;
    if ($cache !== false) {
        return $cache;
    }
    $cache = null;
    try {
        $cols = $pdo->query("SHOW COLUMNS FROM " . CLM_CONSUMIBLES_TABLA)
            ->fetchAll(PDO::FETCH_COLUMN);
    } catch (PDOException $e) {
        return $cache;
    }
    foreach (["PrecioCoste", "PrecioMedio", "Precio", "Coste"] as $preferida) {
        foreach ($cols as $c) {
            if (strcasecmp((string)$c, $preferida) === 0) {
                $cache = (string)$c;
                return $cache;
            }
        }
    }
    return $cache;
}

/// Condición para cruzar el catálogo con una columna de nuestras tablas.
/// La tabla sincronizada viene con otra collation (utf8mb4_general_ci) que la
/// nuestra (utf8mb4_unicode_ci), y comparar textos entre ambas da el error
/// 1267, así que hay que forzar una. Antes no se notaba porque se cruzaba
/// contra IdGotel, que es numérico.
function clm_consumibles_cruce(string $alias, string $columna): string
{
    $c = "`" . $alias . "`.";
    return "(" . $c . "Codigo COLLATE utf8mb4_unicode_ci = " . $columna
        . " OR " . $c . "IdGotel COLLATE utf8mb4_unicode_ci = " . $columna . ")";
}

/// Trozo de SELECT con el precio del catálogo bajo el alias _precio, o "" si
/// no hay columna de precio. [$alias] es el alias de la tabla en la consulta.
/// [$agregado] = true en consultas con GROUP BY: sin envolverlo en MAX(),
/// ONLY_FULL_GROUP_BY (que viene activo por defecto) tumbaría la consulta.
function clm_consumibles_precio_select(
    PDO $pdo,
    string $alias = "",
    bool $agregado = false
): string {
    $col = clm_consumibles_precio_columna($pdo);
    if ($col === null) {
        return "";
    }
    $ref = ($alias !== "" ? "`" . $alias . "`." : "") . "`" . $col . "`";
    return ", " . ($agregado ? "MAX($ref)" : $ref) . " AS _precio";
}
