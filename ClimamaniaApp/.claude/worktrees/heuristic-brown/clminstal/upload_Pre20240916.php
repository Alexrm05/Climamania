<!DOCTYPE html>

<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">  
<title>ClimaMania</title>
<link rel="stylesheet" href="styles.css">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Rubik:wght@300;400;500;600&display=swap" rel="stylesheet">

<script type="text/javascript">
 // centra foco en formulario al cargar la pagina
  window.onload= function(){
  document.formulario.usuario.focus()
  }
</script>
</head>
<body>


<?php
  include("cabeceralog.php");


$directorio = 'imagenes/';
$subir_archivo = $directorio.basename($_FILES['subir_archivo']['name']);


$parts = explode(".",$_FILES['subir_archivo']['name']);

$subir_archivo = $directorio . $_SESSION["k_referencia"] . "-" . $_SESSION["k_accion"] . "-". date("Ymdhis") . "-" . $_SESSION["k_iniciales"] . "." . end($parts);

//$subir_archivo = $directorio . $_SESSION["k_referencia"] . "-" . $_SESSION["k_accion"] . "-". date("Ymdhis") . "-" . $_SESSION["k_iniciales"] . end($parts);

// Reemplazar '..' por '.' a veces ocurre error en preinst
$subir_archivo = str_replace('..', '.', $subir_archivo);


echo "<div>";
if (move_uploaded_file($_FILES['subir_archivo']['tmp_name'], $subir_archivo)) {
      echo "El archivo es válido y se cargó correctamente.<br><br>";
	   echo"<a href='".$subir_archivo."' target='_blank'><img src='".$subir_archivo."' width='150'></a>";

// y guardamos el registro en la Base de Datos
include("conexion.php");
$clave=$_SESSION["k_accion"];

$subir_archivo = str_replace('..', '.', $subir_archivo); 

$mysqli->query("INSERT INTO ClimaInstal_Fotografias (Documento, Clave, Fecha) VALUES ('$subir_archivo','$clave', now())");



    } else {
       echo "La subida ha fallado. Tipo de archivo no valido o superado el tamaño máximo";
    }
    echo "</div>";
?>
<br>
<form id='form1' name='form1' method="post">
  <p></p>
<input  style= "display: none" name="pedido" type="text" class="cuadroform" id="pedido" size="8" maxlength="25" value = "<?php ECHO trim($_POST["pedido"]); ?>" readonly /> 
<input type="button" value="Volver al Menu" id="menu" name="menu" class="" onclick= "document.form1.action = 'menu.php'; 
    document.form1.submit()" />
</form>
	</body>
</html>