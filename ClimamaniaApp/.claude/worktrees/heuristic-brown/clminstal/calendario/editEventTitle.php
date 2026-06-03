<?php
include("conexion.php");

// Establecer el tiempo de vida máximo de la sesión en segundos
$tiempoMaximoSesion = 36000; // 1 hora
ini_set('session.gc_maxlifetime', $tiempoMaximoSesion);

// Establecer la duración de la cookie de sesión en segundos
$tiempoCookie = 36000; // 1 hora
ini_set('session.cookie_lifetime', $tiempoCookie);

		session_start();
		//Comprobamos si el usuario este registrado;
		if (isset($_SESSION['k_username'])) {

echo '<p>Hola <b>'.$_SESSION['k_nombre'].'</b></p>';
    } else{
		header("Location: ".$Base_Url);
      exit();

    }

// Conexion a la base de datos
require_once('bdd.php');
$_SESSION["k_referencia"] = $_POST['referencia'];
$_SESSION["k_defaultDate"] = $_POST['start'];

//Se ha marcado la opción de ver datos de instalación
if (isset($_POST['ver']) && isset($_POST['referencia'])){
	header("Location: ".$Base_Url."/instalacion.php");
	exit();
}


// Se ha marcado la opcion de borrar evento
if (isset($_POST['delete']) && isset($_POST['id'])){
	
	
	$id = $_POST['id'];
	
	$sql = "DELETE FROM ClimaInstal_events WHERE id = $id";
	$query = $bdd->prepare( $sql );
	if ($query == false) {
	 print_r($bdd->errorInfo());
	 die ('Erreur prepare');
	}
	$res = $query->execute();
	if ($res == false) {
	 print_r($query->errorInfo());
	 die ('Erreur execute');
	}

	if (isset($_POST['envmail']) ){

		require_once('../class.phpmailer.php');
		include("../class.smtp.php"); // optional, gets called from within class.phpmailer.php if not already loaded
		
		include("../DatosMail.php"); // Claves envio mail

		$email_usuario = $_SESSION["k_email"];

		$body = ' 
		<html> 
		<head> 
		   <title>Instalación ClimaMania</title> 
		</head> 
		<body> 
		<p style="font-family: Verdana, Geneva, sans-serif; font-size: 12px;">' . $usuario . '  ha ANULADO del calendario la instalacion prevista con los siguientes datos:</p> 
		<p>Referencia de la Instalación: ' . $referencia . '.</p>
		<p>Fecha de la instalación: ' .date('d-m-Y H:i', strtotime($_POST['start']))  . ' </p>
		<p>Nombre del Cliente: ' . $nombrecliente . ' </p>
		<p>Telefono del Cliente: ' . $whatsapp . ' '.$telefono. ' </p>
		<p>Dirección: ' . $direccion . ' </p>
		<p>Detalles: ' . $detalles . '</p>
		<p>Observaciones: ' . $comentarios . '</p>
				
		<p>Este es un email automático. No respondas porque no será atendido. Si tienes alguna duda, contacta directamente con '.$usuario.'. </p>
		
		</body> 
		</html> 
		';

		$subject = "Anulación de  Instalación ClimaMania";
		$subject = "=?UTF-8?B?" . base64_encode($subject) . "=?=";
		$mail->Subject = $subject;
		$mail->CharSet = 'UTF-8';
		$mail->AltBody = "To view the message, please use an HTML compatible email viewer!"; // optional, comment out and test
		$mail->MsgHTML($body);
		$mail->ClearAllRecipients();
		$mail->addAddress($email_equipo, $descripcion_equipo);
		$mail->addAddress($email_usuario, $usuario);
		$mail->clearAttachments();
		if (!$mail->Send()) {
		  echo "Mailer Error: " . $mail->ErrorInfo;
		} else {
		  echo "<br\>La finalización de la instalación se ha registrado correctamente";
		}
	}


	
}elseif (isset($_POST['title']) && isset($_POST['color']) && isset($_POST['id'])){
	
	$id = $_POST['id'];
	$title = $_POST['title'];
	$start = $_POST['start'];
	$end = $_POST['end'];
	$color = $_POST['color'];
	$referencia = $_POST['referencia'];
	$nombrecliente = $_POST['nombrecliente'];
	$telefono = $_POST['telefono'];
	$whatsapp = $_POST['whatsapp'];
	$concertada = $_POST['concertada'];
	$direccion = str_replace("<br />", "</br>", nl2br($_POST['direccion']));
	$direccion = preg_replace("[\n|\r|\n\r]", "", $direccion);
	$detalles = str_replace("<br />", "</br>", nl2br($_POST['detalles']));
	$detalles = preg_replace("[\n|\r|\n\r]", "", $detalles);
	$comentarios = str_replace("<br />", "</br>", nl2br($_POST['comentarios']));
	$comentarios = preg_replace("[\n|\r|\n\r]", "", $comentarios);
	$nombrecliente = str_replace("'", '´', $nombrecliente);
	$direccion = str_replace("'", '´', $direccion);
	$detalles = str_replace("'", '´', $detalles);
	$comentarios = str_replace("'", '´', $comentarios);


	//El equipo de instaladores lo obtenemos de ClimaInstal_EquposInstaladores
	$sql2 = "SELECT Nombre FROM ClimaInstal_EquiposInstaladores where color = '".$_POST['color']."' ";
	$req2 = $bdd->prepare($sql2);
	$req2->execute();
	while ($row = $req2->fetch()){
		$equipo_instaladores= $row["Nombre"];
	};

	
	// Miramos si hay texto en finalizada, y si está finalizada lo añadimos
	
	$sql4 = "SELECT estado FROM ClimaInstal_events where referencia = '".$referencia."' ";
	$req4 = $bdd->prepare($sql4);
	$req4->execute();
	while ($row = $req4->fetch()){
		$textoestado= $row["estado"];
	};

// Comprobamos si la cita es provisional o es fija
	if ($concertada == "PROVISIONAL"){
	$provisional = $concertada;
	}else{
		$provisional = "";
	};


// Componemos el title con los datos
$title = '<p>'. $textoestado.'<u>'.$referencia . '</u>: ' . $concertada. '-' .$nombrecliente . '<b> ' . $whatsapp . ' '.$telefono . '</p><p>'.$direccion. '</p><p>'.$detalles. '</p><p>'.$comentarios.'</p>';

	$ahora = date("Y-m-d H:i:s");	
	$usuario= $_SESSION['k_username'];

$inicio = date("Y-m-d H:i:s", strtotime($start));
$fin = date("Y-m-d H:i:s", strtotime($end));

	// Si se ha marcado duplicar el evento
	if (isset($_POST['duplica']) && isset($_POST['id'])){

	
		$sql = "INSERT INTO ClimaInstal_events(title, start, end, color, referencia, nombrecliente, whatsapp, telefono, direccion, detalles, comentarios, concertada, equipo_instaladores, EmailEquipo, date_add, usuario_add ) 
		values ('$title', '$inicio', '$fin', '$color', '$referencia', '$nombrecliente', '$whatsapp','$telefono', '$direccion', '$detalles', '$comentarios', '$concertada', '$equipo_instaladores', '$email_equipo', '$ahora', '$usuario')";
		
	
	}else{
	$sql = "UPDATE ClimaInstal_events SET  title = '$title', color = '$color', start = '$inicio', end = '$fin',referencia = '$referencia', nombrecliente = '$nombrecliente', whatsapp = '$whatsapp',
	telefono = '$telefono', direccion = '$direccion', detalles = '$detalles' , comentarios = '$comentarios', concertada = '$concertada', equipo_instaladores = '$equipo_instaladores', date_upd = '$ahora', usuario_upd ='$usuario'  WHERE id = $id ";
	}

	

	$query = $bdd->prepare( $sql );
	if ($query == false) {
	 print_r($bdd->errorInfo());
	 die ('Erreur prepare');
	}
	$sth = $query->execute();
	if ($sth == false) {
	 print_r($query->errorInfo());
	 die ('Erreur execute');
	}

	if (isset($_POST['envmail']) ){

		require_once('../class.phpmailer.php');
		include("../class.smtp.php"); // optional, gets called from within class.phpmailer.php if not already loaded
		
		include("../DatosMail.php"); // Claves envio mail

		$email_usuario = $_SESSION["k_email"];

		$body = ' 
		<html> 
		<head> 
		   <title>Instalación ClimaMania</title> 
		</head> 
		<body> 
		<p style="font-family: Verdana, Geneva, sans-serif; font-size: 12px;">' . $usuario . '  ha modificado/añadido una instalación en el calendario con los siguientes datos:</p> 
		<p>Referencia de la Instalación: ' . $referencia . '.</p>
		<p>Fecha de la instalación: ' .date('d-m-Y H:i', strtotime($_POST['start']))  . ' </p>
		<p>Nombre del Cliente: ' . $nombrecliente . ' </p>
		<p>Telefono del Cliente: ' . $whatsapp . ' '.$telefono. ' </p>
		<p>Dirección: ' . $direccion . ' </p>
		<p>Detalles: ' . $detalles . '</p>
		<p>Observaciones: ' . $comentarios . '</p>
				
		<p>Este es un email automático. No respondas porque no será atendido. Si tienes alguna duda, contacta directamente con '.$usuario.'. </p>
		
		</body> 
		</html> 
		';

		$subject = "Alta/Modificación de Instalación ClimaMania";
		$subject = "=?UTF-8?B?" . base64_encode($subject) . "=?=";
		$mail->Subject = $subject;
		$mail->CharSet = 'UTF-8';
		$mail->AltBody = "To view the message, please use an HTML compatible email viewer!"; // optional, comment out and test
		$mail->MsgHTML($body);
		$mail->ClearAllRecipients();
		$mail->addAddress($email_equipo, $descripcion_equipo);
		$mail->addAddress($email_usuario, $usuario);
		$mail->clearAttachments();
		if (!$mail->Send()) {
		  echo "Mailer Error: " . $mail->ErrorInfo;
		} else {
		  echo "<br\>La finalización de la instalación se ha registrado correctamente";
		}
	}







}
header('Location: index.php');

	
?>
