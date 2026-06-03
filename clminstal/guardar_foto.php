


<?php
include("conexion.php");

session_start();
//Comprobamos si el usuario este registrado;
if (isset($_SESSION['k_username'])) {
} else{
    header("Location: ".$Base_Url);
exit();

}
/*
    Tomar una fotografía y guardarla en un archivo
    @date @date 2018-10-22
    @author parzibyte
    @web parzibyte.me/blog
*/

$imagenCodificada = file_get_contents("php://input"); //Obtener la imagen
if(strlen($imagenCodificada) <= 0) exit("No se recibió ninguna imagen");
//La imagen traerá al inicio data:image/png;base64, cosa que debemos remover
$imagenCodificadaLimpia = str_replace("data:image/png;base64,", "", urldecode($imagenCodificada));

//Venía en base64 pero sólo la codificamos así para que viajara por la red, ahora la decodificamos y
//todo el contenido lo guardamos en un archivo
$imagenDecodificada = base64_decode($imagenCodificadaLimpia);

//Calcular un nombre único
$nombreImagenGuardada = "imagenes/" . $_SESSION["k_referencia"] . "-" . $_SESSION["k_accion"] . "-". date("Ymdhis") . "-" . $_SESSION["k_iniciales"] . ".png";
//Escribir el archivo
file_put_contents($nombreImagenGuardada, $imagenDecodificada);

//Grabamos en la Base de datos el nombre de la foto

$clave=$_SESSION["k_accion"];
$mysqli->query("INSERT INTO ClimaInstal_Fotografias (Documento,Clave, Fecha) VALUES ('$nombreImagenGuardada','$clave', now())");



//Terminar y regresar el nombre de la foto
exit($nombreImagenGuardada);
?>