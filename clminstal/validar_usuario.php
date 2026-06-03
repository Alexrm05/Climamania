<?php
//error_reporting(E_ALL);
//ini_set('display_errors', '1');
?>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>ClimaMania</title>
</head>
<body>

<?php
session_start();
include("conexion.php");
$Version= "1.0 05-2023";

if(trim($_POST["usuario"]) != "" && trim($_POST["password"]) != "")
{
	$usuario = strtolower(htmlentities($_POST["usuario"], ENT_QUOTES));
	$password = $_POST["password"];
    $consulta = $mysqli->query('SELECT * FROM ClimaInstal_Usuarios WHERE usuario=\''.$usuario.'\'');
    while ($row = $consulta->fetch_assoc()) {
		if($row["contrasenya"] == $password){
					$_SESSION["k_username"] = $row['usuario'];
					$_SESSION["k_nombre"] = $row['Nombre'];
					$_SESSION["k_apellidos"] = $row['Apellidos'];
					$_SESSION["k_email"] = $row['email'];
					$_SESSION["k_iniciales"] = $row['iniciales'];
					$_SESSION["k_rol"] = $row['rol'];
					$_SESSION["k_equipo"] = $row['EquipoInstaladores'];
					$_SESSION["k_accion"] = "nada"; // Variables globales necesarias para fotos
					$_SESSION["k_referencia"] = "nada"; // Variables globales necesarias para fotos
					$_SESSION["k_defaultDate"] = date('Y-m-d');
					$_SESSION["k_base_url"] = 'https://clminstal.es/';



					//$_SESSION["k_codusuario"] = $row['cod_usuario'];
				// usuario validado, graba datos de acceso
		$mysqli->query("INSERT INTO ClimaInstal_Accesos (Usuario, TipoAcceso, Fecha, version) VALUES ('$_SESSION[k_nombre]', 'LoginOk', now(), '$Version')");
			// y dirige a pagina de inicio excepto si es el administrador
			 if ( $_SESSION["k_username"] == 'Administrador12345'){
						?>
			 			<SCRIPT LANGUAGE="javascript">
						location.href = "admin.php";
						</SCRIPT>
						<?php
			 };

						?>
 						<SCRIPT LANGUAGE="javascript">
						location.href = "NumPedido.php";
						</SCRIPT>
						<?php
			}
    }



}
mysqli_close($mysqli);
echo 'Usuario o contraseña no valido';
?>
<p><input type="button" value="Volver" onclick="history.back()"></p>
 
 

</body>
</html>