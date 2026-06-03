<!DOCTYPE html>

<head>
  <link href="//netdna.bootstrapcdn.com/font-awesome/4.1.0/css/font-awesome.min.css" rel="stylesheet">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ClimaMania</title>
  <link rel="stylesheet" href="styles.css">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Rubik:wght@300;400;500;600&display=swap" rel="stylesheet">
  <script type="text/javascript">
    // centra foco en formulario al cargar la pagina
    window.onload = function () {
      document.formulario.usuario.focus()
    }
  </script>
</head>

<body>
<?php
  include("cabeceralog.php");
  $_SESSION["k_accion"] = "POSTINST";
  $_SESSION["k_referencia"] = trim($_POST["pedido"]);
  ?>


  <p class="textoPeq">REFERENCIA INSTALACION:
    <?php echo trim($_POST["pedido"]); ?>
  </P>

  <p class="letraFotos"><b>FOTOS INSTALACIÓN ACABADA</b></p>
  <p style=" font-size:small; color: red; text-align:center;"><b>(Por favor: haz las fotos con el móvil en vertical) </b></p> 
  <div id="fotoCam">
    <video muted="muted" id="video"></video>
    <canvas id="canvas" style="display: none;"></canvas>

    <button id="boton" class="botonCamara"><img src="img/botonCamara.png"></button>
  </div>
    <!--<p class="textoPeq">Selecciona una cámara para hacer la foto</p>-->
    <div>
    <select style="display:none" name="listaDeDispositivos" id="listaDeDispositivos"></select>
    <p id="estado"></p>
  </div>
  <br>
  <form enctype="multipart/form-data" id='form1' name='form1' method="post">
    <input type="hidden" name="MAX_FILE_SIZE" value="100000000" />

      <div id="cargarFoto">
<p>Si lo deseas, puedes cargar un archivo desde tu teléfono</p>
  <label for="subir_archivo" class="subir">
    <i class="fa fa-cloud-upload" aria-hidden="true"></i> Subir archivo
</label>
      <p><input id="subir_archivo" name="subir_archivo" class="botonSubirArchivo" type="file" onchange='cambiar()' style='display: none;' /></p>
     <p>Archivo cargado:<div id="info">No hay archivos cargados</div></p>

      <p> <input type="submit" value="Enviar Archivo" class="botonMenuVerde" onclick="document.form1.action = 'upload.php'; 
    document.form1.submit()" /></p>
      <input style="display: none" name="pedido" type="text" class="cuadroform" id="pedido" size="8" maxlength="25"
        value="<?php echo trim($_POST["pedido"]); ?>" readonly />

    </div>
    <input type="button" value="Volver al Menu" id="menu" name="menu" class="" onclick="document.form1.action = 'menu.php'; 
    document.form1.submit()" />
  </form>
</body>
<script src="script.js"></script>
<script type="text/javascript">

function cambiar(){
    var pdrs = document.getElementById('subir_archivo').files[0].name;
    document.getElementById('info').innerHTML = pdrs;
}

  </script>
</html>