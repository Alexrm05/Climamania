<?php
error_reporting(E_ALL);
ini_set('display_errors', '1');
?>

<!DOCTYPE html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ClimaMania</title>
  <link rel="stylesheet" href="styles.css">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Rubik:wght@300;400;500;600&display=swap" rel="stylesheet">
</head>
<body>

<?php
  include("cabeceralog.php");

  $pedido = $_SESSION["k_referencia"];
  $usuario = $_SESSION['k_username'];
  $texto = $_POST["mensaje"];
  $fecha = date("d-m-Y h:i:s");
  $mysqli->query("INSERT INTO ClimaInstal_Comentarios (Pedido, Usuario, Texto, Fecha) VALUES ('$pedido','$usuario','$texto','$fecha')");
  ?>
  <p>El comentario se ha guardado con éxito</p>
  <form enctype="multipart/form-data" id='form1' name='form1' method="post">
    <input style="display:none" name="pedido" type="text" class="cuadroform" id="pedido" size="8" maxlength="25"
      value="<?php echo $_SESSION["k_referencia"]; ?>" readonly /> </p>
    <input type="button" value="Volver al Menu" id="menu" name="menu" class="" onclick="document.form1.action = 'menu.php'; 
    document.form1.submit()" />
  </form>
</body>
</html>