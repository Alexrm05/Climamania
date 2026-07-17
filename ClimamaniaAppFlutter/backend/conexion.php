<?php

// -------------------------------------------

// CONFIGURACIÓN GENERAL DE CONEXIÓN

// -------------------------------------------



// SERVIDOR MySQL
$DB_HOST = "153.92.42.147";
$DB_NAME = "ynrlpmed_fulls";
$DB_USER = "ynrlpmed_admin";
$DB_PASS = "r&^%1CB%Gxfi";  

// -------------------------------------------
// CONFIGURACION PRESTASHOP (SEGUNDA BD)
// -------------------------------------------

$PS_DB_HOST = "www.climamania.com";
$PS_DB_NAME = "climaman_2023";
$PS_DB_USER = "climaman_2023";
$PS_DB_PASS = "!+6o7G]ohSEy";

// Raiz de imagenes en servidor (presupuestos/firma/fotos)
// Subdirectorios usados:
// - /home/ynrlpmed/clminstal.es/imagenes/firmasConforme
// - /home/ynrlpmed/clminstal.es/imagenes/presupuestosAdicionales
$CLM_IMAGES_DIR = "/home/ynrlpmed/clminstal.es/imagenes";
putenv("CLM_IMAGES_DIR=" . $CLM_IMAGES_DIR);

// Raiz de documentos BOE en servidor
// Subdirectorios usados:
// - /home/ynrlpmed/clminstal.es/docs
$CLM_DOCS_DIR = "/home/ynrlpmed/clminstal.es/docs";
putenv("CLM_DOCS_DIR=" . $CLM_DOCS_DIR);


// OPCIONES DE PDO

$pdo_options = [

    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, // Errores como excepciones

    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC, // Arrays asociativos

    PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4", // Forzar UTF-8

    PDO::ATTR_PERSISTENT => false, // Desactivar conexión persistente (más seguro)

];



// -------------------------------------------

// FUNCIÓN GLOBAL PARA OBTENER LA CONEXIÓN

// -------------------------------------------

function getDBConnection()
{

    global $DB_HOST, $DB_NAME, $DB_USER, $DB_PASS, $pdo_options;



    try {

        $pdo = new PDO(

            "mysql:host=$DB_HOST;dbname=$DB_NAME;charset=utf8mb4",

            $DB_USER,

            $DB_PASS,

            $pdo_options

        );

        return $pdo;



    } catch (PDOException $e) {

        // En producción es mejor NO mostrar detalles del error

        http_response_code(500);

        echo json_encode([

            "status" => "error",

            "message" => "Error al conectar con la base de datos"

        ]);

        exit;

    }

}

// -------------------------------------------
// CONEXION PRESTASHOP
// -------------------------------------------
function getPSConnection()
{
    global $PS_DB_HOST, $PS_DB_NAME, $PS_DB_USER, $PS_DB_PASS, $pdo_options;

    try {
        $pdo = new PDO(
            "mysql:host=$PS_DB_HOST;dbname=$PS_DB_NAME;charset=utf8mb4",
            $PS_DB_USER,
            $PS_DB_PASS,
            $pdo_options
        );
        return $pdo;
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode([
            "status" => "error",
            "message" => "Error al conectar con la base de datos Prestashop"
        ]);
        exit;
    }
}
?>
