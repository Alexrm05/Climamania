<!DOCTYPE html>

<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ClimaMania</title>
  <link rel="stylesheet" href="styles.css">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Rubik:wght@300;400;500;600&display=swap" rel="stylesheet">

  <script type="text/javascript">

  </script>
</head>

<body>

  <?php
  include("cabeceralog.php");

  //Buscamos los datos del cliente
  $consulta = $mysqli2->query('SELECT ped.id_order, ped.id_customer, ped.id_address_delivery, 
   dir.firstname as NombreFact, dir.lastname as ApellFact, dir.address1 as DirFact, dir.address2 as DirFact2, dir.postcode as CPFact, dir.city as CiudFact, dir.phone as TelFact, dir.phone_mobile as MovFact,
   dir2.firstname as NombreInst, dir2.lastname as ApellInst, dir2.address1 as DirInst, dir2.address2 as DirInst2, dir2.postcode as CPInst, dir2.city as CiudInst, dir2.phone as TelInst,dir2.phone_mobile as MovInst
   FROM ps_orders AS ped
   INNER JOIN ps_address as dir
   ON ped.id_address_invoice = dir.id_address
   INNER JOIN ps_address as dir2
   ON ped.id_address_delivery = dir2.id_address
   WHERE ped.reference = "' . $_SESSION["k_referencia"] . '" ');
  while ($row = $consulta->fetch_assoc()) {
    $NombreFact = $row["NombreFact"] . " " . $row["ApellFact"];
    $DirFact = $row["DirFact"] . " " . $row["DirFact2"];
    $PoblaFact = $row["CPFact"] . " - " . $row["CiudFact"];
    $TelFact = $row["TelFact"] . "   " . $row["MovFact"];
    $NombreInst = $row["NombreInst"] . " " . $row["ApellInst"];
    $DirInst = $row["DirInst"] . " " . $row["DirInst2"];
    $PoblaInst = $row["CPInst"] . " - " . $row["CiudInst"];
    $TelInst = $row["TelInst"] . "   " . $row["MovInst"];
  }
  ?>

  <p>REFERENCIA:
    <?php echo trim($_SESSION["k_referencia"]); ?>
  </P>

  <p><u class="textoAzulCLM">EQUIPO INSTALADORES ASIGNADOS</u></p>
  <P>
    <?php
    if ($_SESSION["k_referencia"] <> '') {
      $consulta = $mysqli->query('SELECT EQ.descripcion, EV.start
      FROM ClimaInstal_events AS EV
      INNER JOIN ClimaInstal_EquiposInstaladores AS EQ
      ON EV.equipo_instaladores = EQ.nombre
      WHERE EV.referencia = "' . $_SESSION["k_referencia"] . '" ');
      while ($row = $consulta->fetch_assoc()) {
        $fechaini = $row["start"];
        echo $row["descripcion"]. ' el dia '. date("d-m-Y H:i:s", strtotime($row["start"]));
      }

      //Comprobamos si la instalación ha sido finalizada y por quien.

      $consulta = $mysqli->query('SELECT Usuario, Fecha
      FROM ClimaInstal_Finalizadas
      WHERE referencia = "' . $_SESSION["k_referencia"] . '" ');
      while ($row = $consulta->fetch_assoc()) {
        
        echo '</br>Instalación Finalizada por '.$row["Usuario"]. ' el dia '. date("d-m-Y H:i:s", strtotime($row["Fecha"]));
      }

    }

    ?>
  </P>

  <p><u class="textoAzulCLM">ARTICULOS AL INSTALAR Y OBSERVACIONES AL AGENDAR LA INSTALACION</u></p>
  <P>
    <?php
    if ($_SESSION["k_referencia"] <> '') {
      $consulta = $mysqli->query('SELECT comentarios, detalles FROM ClimaInstal_events
          WHERE referencia = "' . $_SESSION["k_referencia"] . '" ');
      while ($row = $consulta->fetch_assoc()) {
        echo $row["detalles"].': '. $row["comentarios"];
      }
    }
    ?>
  </P>

  <p><u class="textoAzulCLM">DIRECCION DE LA INSTALACION</u></p>
  <P>
    <?php
    if ($_SESSION["k_referencia"] <> '') {
      $consulta = $mysqli->query('SELECT direccion FROM ClimaInstal_events
          WHERE referencia = "' . $_SESSION["k_referencia"] . '" ');
      while ($row = $consulta->fetch_assoc()) {
        echo $row["direccion"];
      }
    }
    ?>
  </P>


<!-- DATOS DE PRESTASHOP, SOLO LO MUESTRA SI ES UNA REFERENCIA DE PS -->

<div id="DatosPresta" >

  <p><u class="textoAzulCLM">DATOS FACTURACIÓN</u></p>
  <div id="textosInstalaciones">
    <P><b>Nombre Cliente:</b>
      <?php echo $NombreFact; ?>
    </p>
    <p><b>Dirección:</b>
      <?php echo $DirFact; ?>
    </p>
    <p><b>Poblacion:</b>
      <?php echo $PoblaFact; ?>
    </p>
    <p><b>Telefono:</b>
      <?php echo $TelFact; ?>
    </p>
  </div>

  <p><u class="textoAzulCLM">DATOS ENTREGA</u></p>
  <div id="textosInstalaciones">
    <P><b>Nombre Cliente:</b>
      <?php echo $NombreInst; ?>
    </p>
    <p><b>Dirección:</b>
      <?php echo $DirInst; ?>
    </p>
    <p><b>Poblacion:</b>
      <?php echo $PoblaInst; ?>
    </p>
    <p><b>Telefono:</b>
      <?php echo $TelInst; ?>
    </p>
  </div>
  <p><u class="textoAzulCLM">DETALLE DEL PEDIDO</u></p>

  <table class="tablaDetallesPedido">
    <tr>
      <th>CTD</th>
      <th>Código</th>
      <th>Descripción</th>
    </tr>
    <?php
    if ($_SESSION["k_referencia"] <> '') {
      $consulta = $mysqli2->query('SELECT  lin.product_quantity, lin.product_reference, lin.product_name
        FROM ps_orders AS ped
        INNER JOIN ps_order_detail AS lin
        ON ped.id_order = lin.id_order
        WHERE ped.reference = "' . $_SESSION["k_referencia"] . '" ');
      echo '<tr>';
      while ($row = $consulta->fetch_assoc()) {
        echo '<td>' . $row["product_quantity"] . '</td><td>' . $row["product_reference"] . '</td><td>' . $row["product_name"] . '</td>';
        echo '</tr>';
      }
    }
    ?>
  </table>

  <p><u class="textoAzulCLM">OBSERVACIONES DEL CLIENTE EN PEDIDO</u></p>
  <P>
    <?php
    if ($_SESSION["k_referencia"] <> '') {
      $consulta = $mysqli2->query('SELECT message FROM ps_customer_thread AS cos
          INNER JOIN ps_customer_message AS men
          ON cos.id_customer_thread = men.id_customer_thread
          WHERE cos.id_order = "' . $_SESSION["k_referencia"] . '" ');
      while ($row = $consulta->fetch_assoc()) {
        echo $row["message"];
      }
    }
    ?>
  </P>
  </div>
  <!-- FIN DATOS DE PRESTASHOP -->

<!-- DATOS DE CALENDARIO, SOLO LO MUESTRA SI ES UNA REFERENCIA DE CALENDARIO -->

<div id="DatosCalend" >

  <p><u class="textoAzulCLM">COMENTARIOS DEL INSTALADOR</u> </p>
  <P>
    <?php
    //Cargamos el historico de comentarios
    if ($_SESSION["k_referencia"] <> '') {
      $consulta = $mysqli->query('SELECT * FROM ClimaInstal_Comentarios
        WHERE Pedido = "' . $_SESSION["k_referencia"] . '" ');
      while ($row = $consulta->fetch_assoc()) {
        echo '<p class="textoPeq"> <u>El ' . $row["Fecha"] . ' ' . $row["Usuario"] . ' escribió:</u> ' . $row["Texto"] . '</p>';
      }
    }
    ?>
  </P>

  <p><u class="textoAzulCLM">FOTOGRAFIAS APORTADAS POR EL CLIENTE </u></p>
  <div id="fotosDetallesInstalaciones">
    <?php
    //Cargamos el historico de fotografias (imágenes o videos)
    if ($_SESSION["k_referencia"] <> '') {
      $consulta = $mysqli->query("SELECT * FROM ClimaInstal_Fotografias WHERE Documento LIKE 'imagenes/" . $_SESSION["k_referencia"] . "-FOTOCLI%' ORDER BY id asc");
      while ($row = $consulta->fetch_assoc()) {
        $archivo = $row["Documento"];
        $extension = strtolower(pathinfo($archivo, PATHINFO_EXTENSION)); // Obtener la extensión

        if (in_array($extension, ['jpg', 'jpeg', 'png', 'gif'])) {
          // Si es una imagen
          echo '<div class="fotoInstDet"> <a target="_blank" href="' . $archivo . '"><img src="' . $archivo . '" width="150"></a></div>';
        } elseif (in_array($extension, ['mp4', 'webm', 'ogg'])) {
          // Si es un video
          echo '<div class="fotoInstDet"><video width="320" height="240" controls><source src="' . $archivo . '" type="video/' . $extension . '">Tu navegador no soporta la reproducción de video.</video></div>';
        } else {
          // Si es otro tipo de archivo
          echo '<div class="fotoInstDet">Archivo no soportado: <a href="' . $archivo . '" target="_blank">Ver archivo</a></div>';
        }
      }
    }
    ?>
  </div>

  <p><u class="textoAzulCLM">FOTOGRAFIAS PREVIAS A LA INSTALACION </u></p>
  <div id="fotosDetallesInstalaciones">
    <?php
    //Cargamos el historico de fotografias
    if ($_SESSION["k_referencia"] <> '') {
      $consulta = $mysqli->query("SELECT * FROM ClimaInstal_Fotografias WHERE Documento LIKE 'imagenes/" . $_SESSION["k_referencia"] . "-PREINST%' ORDER BY id asc");
      while ($row = $consulta->fetch_assoc()) {
        $archivo = $row["Documento"];
        $extension = strtolower(pathinfo($archivo, PATHINFO_EXTENSION));

        if (in_array($extension, ['jpg', 'jpeg', 'png', 'gif'])) {
          echo '<div class="fotoInstDet"><a target="_blank" href="' . $archivo . '"><img src="' . $archivo . '" width="150"></a></div>';
        } elseif (in_array($extension, ['mp4', 'webm', 'ogg'])) {
          echo '<div class="fotoInstDet"><video width="320" height="240" controls><source src="' . $archivo . '" type="video/' . $extension . '">Tu navegador no soporta la reproducción de video.</video></div>';
        }
      }
    }
    ?>
  </div>

  <p><u class="textoAzulCLM">FOTOGRAFIAS DE INCIDENCIAS DURANTE LA INSTALACION </u></p>
  <div id="fotosDetallesInstalaciones">
    <?php
    //Cargamos el historico de fotografias
    if ($_SESSION["k_referencia"] <> '') {
      $consulta = $mysqli->query("SELECT * FROM ClimaInstal_Fotografias WHERE Documento LIKE 'imagenes/" . $_SESSION["k_referencia"] . "-DURINST%' ORDER BY id asc");
      while ($row = $consulta->fetch_assoc()) {
        $archivo = $row["Documento"];
        $extension = strtolower(pathinfo($archivo, PATHINFO_EXTENSION));

        if (in_array($extension, ['jpg', 'jpeg', 'png', 'gif'])) {
          echo '<div class="fotoInstDet"><a target="_blank" href="' . $archivo . '"><img src="' . $archivo . '" width="150"></a></div>';
        } elseif (in_array($extension, ['mp4', 'webm', 'ogg'])) {
          echo '<div class="fotoInstDet"><video width="320" height="240" controls><source src="' . $archivo . '" type="video/' . $extension . '">Tu navegador no soporta la reproducción de video.</video></div>';
        }
      }
    }
    ?>
  </div>

  <p><u class="textoAzulCLM">FOTOGRAFIAS DE LA INSTALACION ACABADA </u></p>
  <div id="fotosDetallesInstalaciones">
    <?php
    //Cargamos el historico de fotografias
    if ($_SESSION["k_referencia"] <> '') {
      $consulta = $mysqli->query("SELECT * FROM ClimaInstal_Fotografias WHERE Documento LIKE 'imagenes/" . $_SESSION["k_referencia"] . "-POSTINST%' ORDER BY id asc");
      while ($row = $consulta->fetch_assoc()) {
        $archivo = $row["Documento"];
        $extension = strtolower(pathinfo($archivo, PATHINFO_EXTENSION));

        if (in_array($extension, ['jpg', 'jpeg', 'png', 'gif'])) {
          echo '<div class="fotoInstDet"><a target="_blank" href="' . $archivo . '"><img src="' . $archivo . '" width="150"></a></div>';
        } elseif (in_array($extension, ['mp4', 'webm', 'ogg'])) {
          echo '<div class="fotoInstDet"><video width="320" height="240" controls><source src="' . $archivo . '" type="video/' . $extension . '">Tu navegador no soporta la reproducción de video.</video></div>';
        }
      }
    }
    ?>
  </div>

  <p><u class="textoAzulCLM">FOTOGRAFIAS DOCUMENTOS </u></p>
  <div id="fotosDetallesInstalaciones">
    <?php
    //Cargamos el historico de fotografias
    if ($_SESSION["k_referencia"] <> '') {
      $consulta = $mysqli->query("SELECT * FROM ClimaInstal_Fotografias WHERE Documento LIKE 'imagenes/" . $_SESSION["k_referencia"] . "-DOC%' ORDER BY id asc");
      while ($row = $consulta->fetch_assoc()) {
        $archivo = $row["Documento"];
        $extension = strtolower(pathinfo($archivo, PATHINFO_EXTENSION));

        if (in_array($extension, ['jpg', 'jpeg', 'png', 'gif'])) {
          echo '<div class="fotoInstDet"><a target="_blank" href="' . $archivo . '"><img src="' . $archivo . '" width="150"></a></div>';
        } elseif (in_array($extension, ['mp4', 'webm', 'ogg'])) {
          echo '<div class="fotoInstDet"><video width="320" height="240" controls><source src="' . $archivo . '" type="video/' . $extension . '">Tu navegador no soporta la reproducción de video.</video></div>';
        }
      }
    }
    ?>
  </div>


  </div>

  <form id='form1' name='form1' method="post">
    <input style="display: none" name="pedido" type="text" class="cuadroform" id="pedido" size="8" maxlength="25"
      value="<?php echo trim($_SESSION["k_referencia"]); ?>" readonly />
    <input type="button" value="Volver al Menu" id="menu" class="" name="menu" onclick="document.form1.action = 'menu.php'; 
    document.form1.submit()" />
  </form>



    <!-- Ocultamos Div de datospresta si no es una referencia de Prestashop -->
    <input type="text" value="<?php echo $NombreFact ?>" id="ps" style="display:none" />
    <input type="text" value="<?php echo $fechaini ?>" id="cl" style="display:none" />
    <script type="text/javascript">
      dato = document.getElementById("ps").value;
      if (dato == '') {
        document.getElementById("DatosPresta").style.display = 'none';
      }


    </script>

</body>
</html>
