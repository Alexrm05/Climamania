
<?php
include("conexion.php");
//Para que no almacene caché el navegador
header("Expires: Fri, 14 Mar 1980 20:53:00 GMT"); //la pagina expira en fecha pasada 
header("Last-Modified: " . gmdate("D, d M Y H:i:s") . " GMT"); //ultima actualizacion ahora cuando la cargamos 
header("Cache-Control: no-cache, must-revalidate"); //no guardar en CACHE 
header("Pragma: no-cache"); //PARANOIA, NO GUARDAR EN CACHE 
// Establecer el tiempo de vida máximo de la sesión en segundos
$tiempoMaximoSesion = 36000; // 1 hora
ini_set('session.gc_maxlifetime', $tiempoMaximoSesion);

// Establecer la duración de la cookie de sesión en segundos
$tiempoCookie = 36000; // 1 hora
ini_set('session.cookie_lifetime', $tiempoCookie);

session_start();
//Comprobamos si el usuario este registrado;
if (isset($_SESSION['k_username'])) {
} else {

    echo $Base_Url;
    header("Location: ".$Base_Url);
    exit();
}

// Controlamos si el pedido viene de un post o no
if ($_POST["pedido"]<>''){
    $pedidorecibido = $_POST["pedido"];
    $_SESSION["k_referencia"]=$_POST["pedido"];       
        }else{
          $pedidorecibido = $_SESSION["k_referencia"];
        };
//Conectamos a las Bases de Datos


?>

<div id="cabecera" style="display: flex;align-items: center;justify-content: space-between;">
    <div>
        <a href="<?php echo $Base_Url; ?>"><img src="img/logo.jpg"></a>
    </div>
    <div>
        <p style="font-size: small"><a href="<?php echo $Base_Url; ?>/cerrarsesion.php">Cerrar Sesión</a></p>
    </div>  
</div>
<p>Hola <b><?php echo  $_SESSION['k_nombre']; ?></b></p>