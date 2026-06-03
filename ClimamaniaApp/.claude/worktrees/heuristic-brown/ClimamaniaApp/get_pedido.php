<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once "conexion.php";

$API_KEY = "TEST123";

$PS_PREFIX = isset($PS_DB_PREFIX) && $PS_DB_PREFIX !== "" ? $PS_DB_PREFIX : "ps_";

if (!isset($_GET['api_key']) || $_GET['api_key'] !== $API_KEY) {
    echo json_encode(["success" => false, "message" => "API key invalida"]);
    exit;
}

$referencia = isset($_GET['referencia']) ? trim($_GET['referencia']) : '';
if ($referencia === '') {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Referencia requerida"]);
    exit;
}

try {
    $pdo = getDBConnection();
    $psPdo = getPSConnection();
    $psPrefix = resolvePsPrefix($psPdo, $PS_PREFIX);

    $pedido = [
        "referencia" => $referencia,
        "cliente" => null,
        "email_cliente" => "",
        "equipo_asignado" => [],
        "finalizaciones" => [],
        "articulos_agenda" => [
            "detalles" => null,
            "comentarios" => null
        ],
        "direccion_instalacion" => null,
        "facturacion" => null,
        "entrega" => null,
        "detalle_pedido" => [],
        "observaciones_pedido" => null,
        "comentarios_instalador" => [],
        "fotografias" => [
            "cliente" => [],
            "previas" => [],
            "incidencias" => [],
            "acabada" => [],
            "documentos" => []
        ]
    ];

    // Evento principal (dirección, cliente, detalles)
    $stmt = $pdo->prepare(
        "SELECT referencia, nombrecliente, direccion, detalles, comentarios, equipo_instaladores, start
         FROM ClimaInstal_events
         WHERE referencia = :ref
         ORDER BY start ASC
         LIMIT 1"
    );
    $stmt->execute([":ref" => $referencia]);
    $ev = $stmt->fetch();
    if ($ev) {
        $pedido["referencia"] = $ev["referencia"];
        $pedido["cliente"] = $ev["nombrecliente"];
        $pedido["direccion_instalacion"] = $ev["direccion"];
        $pedido["articulos_agenda"]["detalles"] = $ev["detalles"];
        $pedido["articulos_agenda"]["comentarios"] = $ev["comentarios"];
    }

    // Equipo asignado
    $stmt = $pdo->prepare(
        "SELECT EQ.descripcion, EV.start
         FROM ClimaInstal_events AS EV
         INNER JOIN ClimaInstal_EquiposInstaladores AS EQ
            ON EV.equipo_instaladores = EQ.nombre
         WHERE EV.referencia = :ref
         ORDER BY EV.start ASC"
    );
    $stmt->execute([":ref" => $referencia]);
    $pedido["equipo_asignado"] = $stmt->fetchAll();

    // Finalizadas
    $stmt = $pdo->prepare(
        "SELECT Usuario, Fecha
         FROM ClimaInstal_Finalizadas
         WHERE referencia = :ref
         ORDER BY Fecha ASC"
    );
    $stmt->execute([":ref" => $referencia]);
    $pedido["finalizaciones"] = $stmt->fetchAll();

    // Datos de facturacion y entrega (Prestashop)
    $stmt = $psPdo->prepare(
        "SELECT ped.id_order,
                c.email AS EmailCliente,
                dir.firstname AS NombreFact, dir.lastname AS ApellFact,
                dir.address1 AS DirFact, dir.address2 AS DirFact2,
                dir.postcode AS CPFact, dir.city AS CiudFact,
                dir.phone AS TelFact, dir.phone_mobile AS MovFact,
                dir2.firstname AS NombreInst, dir2.lastname AS ApellInst,
                dir2.address1 AS DirInst, dir2.address2 AS DirInst2,
                dir2.postcode AS CPInst, dir2.city AS CiudInst,
                dir2.phone AS TelInst, dir2.phone_mobile AS MovInst
         FROM {$psPrefix}orders AS ped
         LEFT JOIN {$psPrefix}customer AS c
            ON ped.id_customer = c.id_customer
         INNER JOIN {$psPrefix}address AS dir
            ON ped.id_address_invoice = dir.id_address
         INNER JOIN {$psPrefix}address AS dir2
            ON ped.id_address_delivery = dir2.id_address
         WHERE ped.reference = :ref
         LIMIT 1"
    );
    $stmt->execute([":ref" => $referencia]);
    $ps = $stmt->fetch();

    $orderId = null;
    if ($ps) {
        $orderId = $ps["id_order"];
        $emailCliente = normalizeEmailValue((string)($ps["EmailCliente"] ?? ""));
        if ($emailCliente !== "") {
            $pedido["email_cliente"] = $emailCliente;
        }
        $pedido["facturacion"] = [
            "nombre" => trim($ps["NombreFact"] . " " . $ps["ApellFact"]),
            "direccion" => trim($ps["DirFact"] . " " . $ps["DirFact2"]),
            "poblacion" => trim($ps["CPFact"] . " - " . $ps["CiudFact"]),
            "telefono" => trim($ps["TelFact"] . " " . $ps["MovFact"]),
            "email" => $emailCliente
        ];
        $pedido["entrega"] = [
            "nombre" => trim($ps["NombreInst"] . " " . $ps["ApellInst"]),
            "direccion" => trim($ps["DirInst"] . " " . $ps["DirInst2"]),
            "poblacion" => trim($ps["CPInst"] . " - " . $ps["CiudInst"]),
            "telefono" => trim($ps["TelInst"] . " " . $ps["MovInst"]),
            "email" => $emailCliente
        ];
        if ($pedido["cliente"] === null || $pedido["cliente"] === "") {
            $pedido["cliente"] = $pedido["facturacion"]["nombre"];
        }
    }

    // Detalle del pedido
    if ($orderId) {
        $stmt = $psPdo->prepare(
            "SELECT lin.product_quantity, lin.product_reference, lin.product_name
             FROM {$psPrefix}order_detail AS lin
             WHERE lin.id_order = :order"
        );
        $stmt->execute([":order" => $orderId]);
        $pedido["detalle_pedido"] = $stmt->fetchAll();
    }

    // Observaciones del cliente en pedido
    if ($orderId) {
        $stmt = $psPdo->prepare(
            "SELECT men.message
             FROM {$psPrefix}customer_thread AS cos
             INNER JOIN {$psPrefix}customer_message AS men
                ON cos.id_customer_thread = men.id_customer_thread
             WHERE cos.id_order = :order
             ORDER BY men.date_add ASC"
        );
        $stmt->execute([":order" => $orderId]);
        $mensajes = $stmt->fetchAll();
        if ($mensajes) {
            $pedido["observaciones_pedido"] = implode("\n", array_map(function ($row) {
                return $row["message"];
            }, $mensajes));
        }
    }

    // Comentarios del instalador
    $stmt = $pdo->prepare(
        "SELECT Fecha, Usuario, Texto
         FROM ClimaInstal_Comentarios
         WHERE Pedido = :ref
         ORDER BY Fecha ASC"
    );
    $stmt->execute([":ref" => $referencia]);
    $pedido["comentarios_instalador"] = $stmt->fetchAll();

    // Fotografías (por clave)
    $pedido["fotografias"]["cliente"] = fetchFotosByClave($pdo, $referencia, ["FOTOCLI"]);
    $pedido["fotografias"]["previas"] = fetchFotosByClave($pdo, $referencia, ["PREINST"]);
    $pedido["fotografias"]["incidencias"] = fetchFotosByClave($pdo, $referencia, ["DURINST"]);
    $pedido["fotografias"]["acabada"] = fetchFotosByClave($pdo, $referencia, ["POSTINST"]);
    $pedido["fotografias"]["conforme"] = fetchFotosByClave($pdo, $referencia, ["CONFCLI", "DOCCLI"]);
    $pedido["fotografias"]["boe"] = fetchFotosByClave($pdo, $referencia, ["DOCUBOE"]);
    $pedido["fotografias"]["documentos"] = fetchFotosByClave($pdo, $referencia, ["DOC", "DOCUBOE", "CONFCLI", "DOCCLI"]);

    // Si no hay datos en ningún sitio, devolvemos error controlado
    $hasData = $ev || $ps || !empty($pedido["detalle_pedido"]);
    if (!$hasData) {
        echo json_encode(["success" => false, "message" => "Pedido no encontrado"]);
        exit;
    }

    echo json_encode([
        "success" => true,
        "pedido" => $pedido
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "ERROR: " . $e->getMessage()
    ]);
}

function fetchFotosByClave(PDO $pdo, string $referencia, array $claves): array
{
    if (empty($claves)) return [];
    $placeholders = implode(",", array_fill(0, count($claves), "?"));
    $sql = "SELECT Documento
            FROM ClimaInstal_Fotografias
            WHERE Documento LIKE ?
              AND Clave IN ($placeholders)
            ORDER BY id ASC";

    $params = array_merge(["imagenes/" . $referencia . "%"], $claves);

    try {
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();
        $result = [];
        foreach ($rows as $row) {
            if (!empty($row["Documento"])) {
                $result[] = $row["Documento"];
            }
        }
        return $result;
    } catch (Exception $e) {
        return fetchFotosByPattern($pdo, $referencia, $claves);
    }
}

function fetchFotosByPattern(PDO $pdo, string $referencia, array $claves): array
{
    if (empty($claves)) return [];
    $suffixes = [];
    foreach ($claves as $clave) {
        $suffix = mapClaveToSuffix($clave);
        if ($suffix !== "") {
            $suffixes[] = $suffix;
        }
    }
    $suffixes = array_values(array_unique($suffixes));
    if (empty($suffixes)) return [];

    $likes = [];
    $params = [];
    foreach ($suffixes as $suffix) {
        $likes[] = "Documento LIKE ?";
        $params[] = "imagenes/" . $referencia . "-" . $suffix . "%";
    }

    $sql = "SELECT Documento
            FROM ClimaInstal_Fotografias
            WHERE " . implode(" OR ", $likes) . "
            ORDER BY id ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();
    $result = [];
    foreach ($rows as $row) {
        if (!empty($row["Documento"])) {
            $result[] = $row["Documento"];
        }
    }
    return $result;
}

function mapClaveToSuffix(string $clave): string
{
    $upper = strtoupper(trim($clave));
    if ($upper === "CONFCLI") return "DOCCLI";
    return $upper;
}

function resolvePsPrefix(PDO $pdo, string $preferred): string
{
    $preferred = trim($preferred);
    if ($preferred !== "" && tableExists($pdo, $preferred . "orders")) {
        return $preferred;
    }

    $fallbacks = ["ps_", ""];
    foreach ($fallbacks as $prefix) {
        if ($prefix === $preferred) continue;
        if (tableExists($pdo, $prefix . "orders")) {
            return $prefix;
        }
    }

    return $preferred;
}

function tableExists(PDO $pdo, string $table): bool
{
    $stmt = $pdo->prepare("SHOW TABLES LIKE ?");
    $stmt->execute([$table]);
    return $stmt->fetchColumn() !== false;
}

function normalizeEmailValue(string $value): string
{
    $clean = trim($value);
    return filter_var($clean, FILTER_VALIDATE_EMAIL) ? $clean : "";
}
