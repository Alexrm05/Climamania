<?php

// Establecer el tiempo de vida máximo de la sesión en segundos
$tiempoMaximoSesion = 36000; // 1 hora
ini_set('session.gc_maxlifetime', $tiempoMaximoSesion);

// Establecer la duración de la cookie de sesión en segundos
$tiempoCookie = 36000; // 1 hora
ini_set('session.cookie_lifetime', $tiempoCookie);
		session_start();


// Conexion a la base de datos
require_once('bdd.php');

if ($_POST['Event'][3] == 1){
	// envia mail al instalador
	$usuario = $_SESSION['k_nombre'];
	

		//El mail equipo de instaladores lo obtenemos de ClimaInstal_EquposInstaladores a traves del ID
		$sql2 = "SELECT ev.referencia, ev.equipo_instaladores, eq.email
		FROM ClimaInstal_events AS ev
		INNER JOIN ClimaInstal_EquiposInstaladores AS eq
		ON eq.nombre = ev.equipo_Instaladores
		WHERE ev.id= '". $_POST['Event'][0]."' ";
		$req2 = $bdd->prepare($sql2);
		$req2->execute();
		while ($row = $req2->fetch()){
			$email_equipo=$row["email"];
			$referencia=$row["referencia"];
			$descripcion_equipo = $row["descripcion"];
		};



		require_once('../class.phpmailer.php');
		include("../class.smtp.php"); // optional, gets called from within class.phpmailer.php if not already loaded
		
		include("../DatosMail.php"); // Claves envio mail

		$email_usuario = $_SESSION["k_email"];

		$body = ' 
		<html> 
		<head> 
		   <title>Cambio Fecha Instalación ClimaMania</title> 
		</head> 
		<body> 
		<p style="font-family: Verdana, Geneva, sans-serif; font-size: 12px;">Se ha cambiado la fecha de la siguiente instalacion:</p> 
		<p>Referencia de la Instalación: ' . $referencia . '.</p>
		<p>Nueva Fecha de instalación: ' .date('d-m-Y H:i', strtotime($_POST['Event'][1]))  . ' </p>
				
		<p>Este es un email automático. No respondas porque no será atendido. Si tienes alguna duda, contacta directamente con '.$usuario.'. </p>
		
		</body> 
		</html> 
		';

		$subject = "Cambio Fecha Instalación ClimaMania";
		$subject = "=?UTF-8?B?" . base64_encode($subject) . "=?=";
		$mail->Subject = $subject;
		$mail->CharSet = 'UTF-8';
		$mail->AltBody = "To view the message, please use an HTML compatible email viewer!"; // optional, comment out and test
		$mail->MsgHTML($body);
		$mail->ClearAllRecipients();

		$mail->addAddress('jlrodriguez@climamania.com', 'Jose Luis');
		$mail->addAddress('cjulia@climamania.com', 'Carlos Julia');
        $mail->addAddress('jortega@climamania.com', 'Jose Ortega');

		$mail->addAddress($email_equipo, $descripcion_equipo);
		$mail->addAddress($email_usuario, $usuario);
		$mail->clearAttachments();
		if (!$mail->Send()) {
		  echo "Mailer Error: " . $mail->ErrorInfo;
		} else {
		  echo "";
		}


}






if (isset($_POST['Event'][0]) && isset($_POST['Event'][1]) && isset($_POST['Event'][2])){

	$proba = $_POST['Event'][3];
	$id = $_POST['Event'][0];
	$start = $_POST['Event'][1];
	$end = $_POST['Event'][2];
	$ahora = date("Y-m-d H:i:s");
	$sql = "UPDATE ClimaInstal_events SET  start = '$start', end = '$end', date_upd = '$ahora', comentarios = '$email_equipo' WHERE id = $id ";
	$query = $bdd->prepare( $sql );
	if ($query == false) {
	 print_r($bdd->errorInfo());
	 die ('Error');
	}
	$sth = $query->execute();
	if ($sth == false) {
	 print_r($query->errorInfo());
	 die ('Error');
	}else{
		die ('OK');
	}


}









//header('Location: '.$_SERVER['HTTP_REFERER']);

	
?>






