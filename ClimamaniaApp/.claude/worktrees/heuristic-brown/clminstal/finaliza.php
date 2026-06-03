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


  //Insertamos los registros en la base de datos
  $mysqli->query("INSERT INTO ClimaInstal_Finalizadas (Usuario ,Referencia , CobroMetalico, CobroVisa, Extras, SatisfaccionCliente, Observaciones, Fecha) 
   VALUES ('$_SESSION[k_username]', '$_POST[pedido]', '$_POST[metalico]', '$_POST[visa]', '$_POST[extras]','$_POST[estrellas]','$_POST[mensaje]', now())");

  // Y enviamos mail con los datos
  

  $body = ' 
<html> 
<head> 
   <title>Instalación ClimaMania</title> 
</head> 
<body> 
<p style="font-family: Verdana, Geneva, sans-serif; font-size: 12px;">' . $_SESSION['k_nombre'] . ' ' . $_SESSION['k_apellidos'] . ' ha finalizado una instalacion con los siguientes datos:</p> 
<p>Referencia de la Instalación: ' . $_POST['pedido'] . '.</p>
<p>Cobrado en metálico:' . $_POST['metalico'] . ' €.</p>
<p>Cobrado con VISA: ' . $_POST['visa'] . ' €.</p>
<p>¿Ha habido extras?: ' . $_POST['extras'] . '</p>
<p>Percepción de Satisfacción del cliente: ' . $_POST['estrellas'] . '</p>
<p>Observaciones: ' . $_POST['mensaje'] . '</p>

<p>Este es un email automático. No respondas porque no será atendido. </p>

</body> 
</html> 
';

  require_once('class.phpmailer.php');
  include("class.smtp.php"); // optional, gets called from within class.phpmailer.php if not already loaded
  
  include("DatosMail.php"); // Claves envio mail
 
  
  $subject = "Comunicación Instalación Finalizada";
  $subject = "=?UTF-8?B?" . base64_encode($subject) . "=?=";
  $mail->Subject = $subject;
  $mail->CharSet = 'UTF-8';
  //$mail->Subject = "COMUNICADO DE INSTALACION FINALIZADA";
  $mail->AltBody = "To view the message, please use an HTML compatible email viewer!"; // optional, comment out and test
  $mail->MsgHTML($body);
  $mail->ClearAllRecipients();

  // En BBDD miramos los destinatarios del mail
  $consulta = $mysqli->query('Select * from ClimaInstal_EmailsEnvioFin');
  
      while ($row = $consulta->fetch_assoc()) {
        if ($row["tipo"] == "cc"){
          $mail->addAddress($row["email"], $row["Nombre"]);
        };
        if ($row["tipo"] == "cco"){
          $mail->addBCC($row["email"]);
        };
             
      };
  $mail->clearAttachments();
  if (!$mail->Send()) {
    echo "Mailer Error: " . $mail->ErrorInfo;
  } else {
    echo "<br\>La finalización de la instalación se ha registrado correctamente";
  }

  ?>
  <form enctype="multipart/form-data" id='form1' name='form1' method="post">
    <input style="display: none" name="pedido" type="text" class="cuadroform" id="pedido" size="8" maxlength="25"
      value="<?php echo trim($_POST["pedido"]); ?>" readonly />
    <input type="button" value="Volver al Menu" id="menu" name="menu" class="" onclick="document.form1.action = 'menu.php'; 
    document.form1.submit()" />

<input type="button" value="Consultar otra referencia" id="atras" class="" name="atras" onclick="document.form1.action = 'NumPedido.php'; 
    document.form1.submit()" />
            <input type="button" value="Acceder al calendario" id="atras" class="" name="atras" onclick="document.form1.action = '/calendario'; 
    document.form1.submit()" />

  </form>
  </div>
</body>
</html>