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
  // activa errores
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
  include("cabeceralog.php");
  ?>
  


  <script type="text/javascript">
    // muestra y oculta capas
    function ocultar() {
      document.getElementById("menu").style = "display:none";
      document.getElementById("alerta").style = "display:yes";
      document.getElementById("instalacion").style = "display:none";
    }
    function mostrar() {
      document.getElementById("menu").style = "display:yes";
      document.getElementById("alerta").style = "display:none";
    }
  </script>

  <div id="ClmCuerpo2">
    <form id='form1' name='form1' method="post">
      <div id="menu" style="display: none;">
        <p>Referencia <input name="pedido" type="text" class="cuadroform cuadroMenu" id="pedido" size="8" maxlength="25"
            value="<?php echo $pedidorecibido; ?>" readonly /> </p>
        <input type="button" value="Ver Datos Instalación" id="instalacion" class="botonMenu" name="instalacion"
          onclick="document.form1.action = 'instalacion.php'; 
    document.form1.submit()" />
        <p class="letraFotosMenu"><b>SUBIR FOTOS INSTALACIÓN</b></p>
        <input type="button" value="Subir fotos aportadas por el cliente" id="fotoscli" class="botonMenu"
          name="fotoscli" onclick="document.form1.action = 'fotoscli.php'; 
    document.form1.submit()" />

        <div id="botonesAcciones">
          <!--<textarea onclick="document.form1.action = 'fotospre.php'; document.form1.submit()" >Subir Fotos Previas</textarea>-->
          <textarea type="button" value="Subir Fotos  Previas" id="fotospre" class="botonMenuNaranja" name="fotospre"
            onclick="document.form1.action = 'fotospre.php'; 
    document.form1.submit()">Fotos Previas</textarea>
          <textarea type="button" value="Subir Fotos  Durante" id="fotosdur" class="botonMenuNaranja" name="fotosdur"
            onclick="document.form1.action = 'fotosdur.php'; 
    document.form1.submit()">Fotos Incidencias</textarea>
          <textarea type="button" value="Subir Fotos Instalación Acabada" id="fotospost" class="botonMenuNaranja"
            name="fotospost" onclick="document.form1.action = 'fotospost.php'; 
    document.form1.submit()">Fotos Acabada</textarea>
          <textarea type="button" value="Subir Fotos Conforme Cliente" id="fotosconforme" class="botonMenuNaranja"
            name="fotosconforme" onclick="document.form1.action = 'fotosconforme.php'; 
    document.form1.submit()">Fotos Conforme Cliente</textarea>
          <textarea type="button" value="Subir Fotos Documento BOE" id="fotosboe" class="botonMenuNaranja"
            name="fotosboe" onclick="document.form1.action = 'fotosboe.php'; 
    document.form1.submit()">Fotos Documento BOE</textarea>
          <textarea type="button" value="Añadir Comentarios" id="comentarios" class="botonMenuAzul" name="comentarios"
            onclick="document.form1.action = 'comentarios.php'; 
    document.form1.submit()">Añadir Comentarios</textarea>
        </div>

        <?php


        //Verificación de que haya fotografias de la instalación para ponerles el color verde si estan
$consulta = $mysqli->query("SELECT DISTINCT Clave, id FROM ClimaInstal_Fotografias WHERE Documento LIKE 'imagenes/" . $pedidorecibido . "-%' ORDER BY id ASC");
        $fotopre = 0;
        $fotodur = 0;
        $fotopost = 0;
        $confcli = 0;
        $fotoboe = 0;

        while ($row = $consulta->fetch_assoc()) {
          if ($row["Clave"] == 'PREINST') {
            $fotopre = 1;
          }
          ;
          if ($row["Clave"] == 'DURINST') {
            $fotodur = 1;
          }
          ;
          if ($row["Clave"] == 'POSTINST') {
            $fotopost = 1;
          }
          ;
          if ($row["Clave"] == 'DOCCLI') {
            $confcli = 1;
          }
          ;
          if ($row["Clave"] == 'DOCUBOE') {
            $fotoboe = 1;
          }
          ;
        }
        ;

        if ($fotopre == 1) {
          ?>
          <script
            type="text/javascript">document.getElementById("fotospre").className = "botonMenuVerdeCompletado";</script>
          <?php
        }
        ;
        if ($fotodur == 1) {
          ?>
          <script
            type="text/javascript">document.getElementById("fotosdur").className = "botonMenuVerdeCompletado";</script>
          <?php
        }
        ;
        if ($fotopost == 1) {
          ?>
          <script
            type="text/javascript">document.getElementById("fotospost").className = "botonMenuVerdeCompletado";</script>
          <?php
        }
        ;
        if ($confcli == 1) {
          ?>
          <script
            type="text/javascript">document.getElementById("fotosconforme").className = "botonMenuVerdeCompletado";</script>
          <?php
        }
        ;
        if ($fotoboe == 1) {
          ?>
          <script
            type="text/javascript">document.getElementById("fotosboe").className = "botonMenuVerdeCompletado";</script>
          <?php
        }
        ;
        ?>

        <p class="letraFotosMenu"><b>FINALIZAR INSTALACIÓN</b></p>
        <input type="button" value="Finalizar Instalación" id="fin" class="botonMenuVerde" name="fin" onclick="document.form1.action = 'fin.php'; 
    document.form1.submit()" />
        <input type="button" value="Consultar otra referencia" id="atras" class="" name="atras" onclick="document.form1.action = 'NumPedido.php'; 
    document.form1.submit()" />
            <input type="button" value="Acceder al calendario" id="atras" class="" name="atras" onclick="document.form1.action = '/calendario'; 
    document.form1.submit()" />
      </div>
    </form>
    <div id="alerta" style="display: none;">
      <p> No consta que tengas ninguna instalación asignada con esa referencia.</p>
      
        <!--<button class="botonMenuNaranja" onclick="mostrar()">Continuar con la Referencia introducida</button> -->
        <button class="botonMenuVerde" onclick="location.href='NumPedido.php'">Cambiar Referencia Instalación</button>
    </div>

    <?php
    // Comprobamos que el pedido esté asignado al instalador, o que sea un administrador.
    //administrador accede a todos
    // no administrador solo accede a los suyos


    $pedido = 0;
    $pedidoconsultado = $pedidorecibido;
  //   $consulta = $mysqli2->query('SELECT DISTINCT ped.id_order 
  //  FROM ps_orders AS ped
  //  INNER JOIN ps_order_detail AS lin
  //  ON ped.id_order = lin.id_order
  //  WHERE ped.reference = "' . $pedidorecibido . '" AND lin.product_reference LIKE "INST%"');


$consulta = $mysqli->query('SELECT DISTINCT * 
FROM ClimaInstal_events 
WHERE referencia = "' . $pedidorecibido . '" AND equipo_instaladores = "' . $_SESSION["k_equipo"] . '"');

    while ($row = $consulta->fetch_assoc()) {
      $pedido = $row["referencia"];
    }

    if ($pedido > 0 || $_SESSION["k_equipo"]=="ADMIN") {
      // Tiene instalacion o es un administrador
      //Grabamos el log de la instalacion en la que ha entrado, pero solo la primera vez que entra en esa referencia
      $mysqli->query("INSERT INTO ClimaInstal_Accesos (Usuario, TipoAcceso, Fecha) 
      SELECT '$_SESSION[k_nombre]', 'InstalacionOk-.$pedido',now()
      FROM ClimaInstal_Accesos
      WHERE NOT EXISTS (SELECT Usuario,TipoAcceso FROM ClimaInstal_Accesos WHERE Usuario = '$_SESSION[k_nombre]' and TipoAcceso='InstalacionOk-.$pedido' )
      LIMIT 1");
      // Y mostramos el menu
      ?>

      <script type="text/javascript">
        mostrar();
      </script>
      <?php
    } else {
      //No tiene instalacion, 
      //Grabamos el log del pedido que ha intentado entrar, pero solo la primera vez que entra en esa referencia
    
      $mysqli->query("INSERT INTO ClimaInstal_Accesos (Usuario, TipoAcceso, Fecha) 
      SELECT '$_SESSION[k_nombre]', 'InstalacionNoOk****-.$pedidoconsultado',now()
      FROM ClimaInstal_Accesos
      WHERE NOT EXISTS (SELECT Usuario,TipoAcceso FROM ClimaInstal_Accesos WHERE Usuario = '$_SESSION[k_nombre]' and TipoAcceso='InstalacionNoOk****-.$pedidoconsultado' )
      LIMIT 1");

      //mostramos mensaje alerta y osultamos la posibilidad de ver los datos del pedido
      


      ?>
      <script type="text/javascript">

        ocultar();
      </script>
      <?php
    }
    ;
    ?>


    <!-- Ocultamos boton subir fotos cliente a operarios -->
    <input type="text" value="<?php echo $_SESSION['k_rol']; ?>" id="rol" style="display:none" />
    <script type="text/javascript">
      dato = document.getElementById("rol").value;
      if (dato == 'ope') {
        document.getElementById("fotoscli").style.display = 'none';
      }
    </script>



  </div>
</body>

</html>