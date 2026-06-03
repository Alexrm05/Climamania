<!DOCTYPE html>

<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv='cache-control' content='no-cache'>
  <meta http-equiv='expires' content='0'>
  <meta http-equiv='pragma' content='no-cache'>
  <title>ClimaMania</title>
  <link rel="stylesheet" href="styles.css">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Rubik:wght@300;400;500;600&display=swap" rel="stylesheet">
</head>

<body>
  <?php
  include("cabeceralog.php");
  ?>
  <script type="text/javascript">
    // centra foco en formulario al cargar la pagina
    window.onload = function () {
      document.formulario.pedido.focus()
    }
  </script>

  <div id="ClmCuerpo">
    <form name="formulario" action="menu.php" method="post">
      <p>Referencia Instalación <input name="pedido" type="text" class="cuadroform" id="pedido" size="8" maxlength="25"
          required /> </p>

      <p><input type="submit" class="botonformulario" value="Acceder a la Instalación " /> </p>
    </form>

    <button class="botonMenu" onclick="location.href='<?php echo $Base_Url; ?>/calendario'">Calendario de Instalaciones</button>
    
</body>

</html>