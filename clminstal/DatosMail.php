<?php
$mail = new PHPMailer();

  $mail->IsSMTP(); // telling the class to use SMTP
//$mail->SMTPDebug  = 2;                     // enables SMTP debug information (for testing)
// 1 = errors and messages
// 2 = messages only
  $mail->SMTPAuth = true; // enable SMTP authentication
  $mail->Host = "ssl://eservidor168.factoriadigitalcloud.com"; // sets the SMTP server
  $mail->Port = 465; // set the SMTP port for the GMAIL server
  $mail->Username = "climamania@climamania.com"; // SMTP account username
  $mail->Password = "147962Clm%%147962Abc"; // SMTP account password
  $mail->SetFrom('climamania@climamania.com', 'ClimaMania Instalaciones');
  ?>