<?php



ini_set('display_errors', 1);

ini_set('display_startup_errors', 1);

error_reporting(E_ALL);



header('Content-Type: application/json; charset=utf-8');



// Cargar conexion.php REAL (fuera del directorio /api)

require_once "conexion.php";



$API_KEY = "TEST123";



// Validación API

if (!isset($_GET['api_key']) || $_GET['api_key'] !== $API_KEY) {

    echo json_encode(["success" => false, "message" => "API key invalida"]);

    exit;

}



$rol     = trim($_GET["rol"] ?? "");

$equipo  = trim($_GET["equipo"] ?? "");

$usuario = trim($_GET["usuario"] ?? "");



try {

    $pdo = getDBConnection();



    $sql = "SELECT 
                ev.id,
                ev.title,
                ev.color,
                ev.start,
                ev.end,
                ev.referencia,
                ev.nombrecliente,
                ev.whatsapp,
                ev.telefono,
                ev.direccion,
                ev.detalles,
                ev.comentarios,
                ev.concertada,
                ev.equipo_instaladores,
                ev.EmailEquipo,
                CASE
                    WHEN fin.referencia IS NOT NULL THEN 'finalizado'
                    ELSE ev.estado
                END AS estado
            FROM ClimaInstal_events ev
            LEFT JOIN (
                SELECT DISTINCT referencia
                FROM ClimaInstal_Finalizadas
            ) fin
            ON fin.referencia = ev.referencia
            WHERE 1 = 1";


    $params = [];



    if ($rol !== "adminclm") {

        if ($equipo === "0") {
            $equipo = "";
        }

        if ($equipo === "" && $usuario !== "") {
            $stmtEquipo = $pdo->prepare("SELECT EquipoInstaladores FROM ClimaInstal_Usuarios WHERE usuario = ?");
            $stmtEquipo->execute([$usuario]);
            $rowEquipo = $stmtEquipo->fetch();
            if ($rowEquipo && !empty($rowEquipo["EquipoInstaladores"])) {
                $equipo = trim($rowEquipo["EquipoInstaladores"]);
            }
        }

        if ($equipo === "") {
            echo json_encode(["success" => false, "message" => "Equipo no asignado"]);
            exit;
        }

        $sql .= " AND (equipo_instaladores = :equipo
                     OR FIND_IN_SET(:equipo, REPLACE(equipo_instaladores, ' ', '')) > 0)";

        $params[":equipo"] = $equipo;

    }



    $sql .= " ORDER BY start ASC";



    $stmt = $pdo->prepare($sql);

    $stmt->execute($params);



    $eventos = $stmt->fetchAll();



    echo json_encode([

        "success" => true,

        "eventos" => $eventos

    ], JSON_UNESCAPED_UNICODE);



} catch (Exception $e) {

    http_response_code(500);

    echo json_encode([

        "success" => false,

        "message" => "ERROR: " . $e->getMessage()

    ]);

}

