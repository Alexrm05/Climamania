<?php



ini_set('display_errors', 1);

ini_set('display_startup_errors', 1);

error_reporting(E_ALL);



header('Content-Type: application/json');

require_once "conexion.php";



// ******** Clave API ********

$API_KEY = "TEST123";



// Comprobar parámetros

if (!isset($_POST['usuario']) || !isset($_POST['contrasenya']) || !isset($_POST['api_key'])) {

    echo json_encode([

        "success" => false,

        "message" => "Faltan parámetros"

    ]);

    exit;

}



// Validar clave API

if ($_POST['api_key'] !== $API_KEY) {

    echo json_encode([

        "success" => false,

        "message" => "API KEY inválida"

    ]);

    exit;

}



$usuario = $_POST['usuario'];

$contrasenya = $_POST['contrasenya'];



try {

    // Obtener conexión PDO

    $pdo = getDBConnection();



    // Consulta a tu tabla REAL con nombres EXACTOS

    $stmt = $pdo->prepare("

        SELECT usuario, contrasenya, Nombre, Apellidos, email, EquipoInstaladores, rol

        FROM ClimaInstal_Usuarios

        WHERE usuario = ?

    ");



    $stmt->execute([$usuario]);

    $row = $stmt->fetch();



    // Usuario no encontrado

    if (!$row) {

        echo json_encode([

            "success" => false,

            "message" => "Usuario o contraseña incorrectos"

        ]);

        exit;

    }





 // Validar contraseña (texto plano)

if ($contrasenya !== $row["contrasenya"]) {

    echo json_encode([

        "success" => false,

        "message" => "Usuario o contraseña incorrectos"

    ]);

    exit;

}



    // Login correcto

echo json_encode([

    "success" => true,

    "usuario" => $row["usuario"],

    "nombre" => $row["Nombre"],

    "apellidos" => $row["Apellidos"],

    "email" => $row["email"],

    "equipoInstaladores" => $row["EquipoInstaladores"],

    "rol" => $row["rol"]

], JSON_UNESCAPED_UNICODE);



} catch (Exception $e) {

    http_response_code(500);

    echo json_encode([

        "success" => false,

        "message" => "ERROR DEBUG: " . $e->getMessage()

    ]);

}



?>

    