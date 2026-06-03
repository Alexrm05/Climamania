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
    window.onload = function () {
      document.form1.mensaje.focus()
    }
  </script>
</head>

<body>

<?php
  include("cabeceralog.php");
  $_SESSION["k_referencia"] = trim($_POST["pedido"]);
  ?>


<p>Comentarios:</p>

<p class="textoPeq">REFERENCIA INSTALACION:
    <?php echo trim($_POST["pedido"]); ?>
  </P>

  <form id='form1' name='form1' method="post" action="/graba_comentarios.php">
  <textarea name="mensaje" id="mensaje" rows="5" style="min-width: 100%"></textarea>
  <br><br>

  <input type="submit" value="Grabar el comentario" id="menu" name="menu" class="botonMenuVerde" >
  <input style="display: none" name="pedido" type="text" class="cuadroform" id="pedido" size="8" maxlength="25"
        value="<?php echo trim($_POST["pedido"]); ?>" readonly />


    
</form>


<u><p class="textoAzulCLM"><u>Comentarios de la instalación</u></p>
<?php
//Cargamos el historico de comentarios


$consulta = $mysqli->query('Select * from ClimaInstal_Comentarios
Where Pedido = "' . $_POST["pedido"] . '" ');

    while ($row = $consulta->fetch_assoc()) {
      echo '<p class="textoPeq"> <u>El '. $row["Fecha"] .' ' . $row["Usuario"] . ' escribió:</u> ' . $row["Texto"] . '</p>';
      
    }


?>

<input type="button" value="Volver al Menu" id="menu" name="menu" class="" onclick="document.form1.action = 'menu.php'; 
    document.form1.submit()" />



</body>


</html>