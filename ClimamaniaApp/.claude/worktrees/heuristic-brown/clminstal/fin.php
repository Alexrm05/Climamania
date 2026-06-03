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
  ?>

 

<div id="textosInstalaciones">
  <p>Vas a dar por finalizada la instalación: <strong> <?php ECHO trim($_POST["pedido"]); ?></strong>
  </br>Revisa y completa la siguiente información antes de darle a finalizar
</P>
<p class="letraFotosMenu textoAzulCLM"><b>FOTOGRAFIAS DISPONIBLES</b></p>

<?php
//Verificación de que haya fotografias previas de la instalación
$consulta = $mysqli->query("SELECT DISTINCT Clave FROM ClimaInstal_Fotografias WHERE Documento LIKE 'imagenes/".$_POST["pedido"]."-%' ORDER BY id asc");
$fotopre=0;
$fotopost=0;
$confcli=0;

    while ($row = $consulta->fetch_assoc()) {
 
      if ($row["Clave"] =='PREINST'){
        $fotopre=1;   

    };
      if ($row["Clave"] =='POSTINST'){
        $fotopost=1;  
  
    };
    if ($row["Clave"] =='DOCCLI'){
      $confcli=1;     

  };
}

if ($fotopre ==1){
echo '<P class="textoOk" >EXISTEN FOTOS PREVIAS A LA INSTALACION</p>';
}else{
  echo '<P class="textoNoOk" >FALTAN FOTOS PREVIAS A LA INSTALACION</p>';
}
if ($fotopost ==1){
  echo '<P class="textoOk" >EXISTEN FOTOS INSTALACION ACABADA</p>';
  }else{
    echo '<P class="textoNoOk" >FALTAN FOTOS INSTALACION ACABADA</p>';
  }
  if ($confcli ==1){
    echo '<P class="textoOk" >EXISTE CONFORME CLIENTE</p>';
    }else{
      echo '<P class="textoNoOk" >FALTAN FOTOS CONFORME CLIENTE</p>';
    }

?>

<form enctype="multipart/form-data" id='form1' name='form1' method="post">
<p class="letraFotosMenu textoAzulCLM"><b>COBROS RECIBIDOS</b></p>

<p>Importante: Verifica en la documentación si el cliente tiene algo pendiente de abonar y anota aquí el importe que hayas recibido.</p>
<p>Cobrado en Metálico <input name="metalico" type="text" class="cuadroform" id="metalico" size="8" maxlength="25"  required/>€. </p>
<p>Cobrado con VISA <input name="visa" type="text" class="cuadroform" id="visa" size="8" maxlength="25"  required/>€. </p>

<p class="letraFotosMenu textoAzulCLM"><b>EXTRAS EN LA INSTALACIÓN</b></p>
<p>Indica si han habido extras en la instalación que no estaban en la documentación.</p>
<p><input id ="radioextras1" name="extras" type="radio" value="si" required />Si</p>
<p><input  id ="radioextras2" name="extras" type="radio" value="no" />No</p>

<p class="letraFotosMenu textoAzulCLM"><b>SATISFACCION PERCIBIDA DEL CLIENTE</b></p>
<p>¿Cual crees que ha sido la satisfacción del cliente con la instalación que le has realizado?</p>
<div class="valoracion">
    <input id="radio1" type="radio" name="estrellas" value="5" ><!--
    --><label for="radio1">★</label><!--
    --><input id="radio2" type="radio" name="estrellas" value="4"><!--
    --><label for="radio2">★</label><!--
    --><input id="radio3" type="radio" name="estrellas" value="3"><!--
    --><label for="radio3">★</label><!--
    --><input id="radio4" type="radio" name="estrellas" value="2"><!--
    --><label for="radio4">★</label><!--
    --><input id="radio5" type="radio" name="estrellas" value="1"><!--
    --><label for="radio5">★</label>
  </div>
 
  <p class="letraFotosMenu textoAzulCLM"><b>OBSERVACIONES FINALES</b></p>
   <textarea name="mensaje" id="mensaje" rows="5" style="min-width: 100%"></textarea>
  <br><br>

      <input style="display: none" name="pedido" type="text" class="cuadroform" id="pedido" size="8" maxlength="25"
        value="<?php echo trim($_POST["pedido"]); ?>" readonly />

        <input type="submit" value="FINALIZAR INSTALACION" id="menu" name="menu" class="botonMenuVerde" onclick="document.form1.action = 'finaliza.php';" />

        <input type="button" value="Volver al Menu de esta instalación" id="menu" name="menu" class="" onclick="document.form1.action = 'menu.php'; 
    document.form1.submit()" />

<input type="button" value="Consultar otra referencia" id="atras" class="" name="atras" onclick="document.form1.action = 'NumPedido.php'; 
    document.form1.submit()" />
            <input type="button" value="Acceder al calendario" id="atras" class="" name="atras" onclick="document.form1.action = '/calendario'; 
    document.form1.submit()" />


  </form>



</div>










</body>
</html>