<?php



include("../conexion.php");

// activa errores
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);


// Establecer el tiempo de vida máximo de la sesión en segundos
$tiempoMaximoSesion = 36000; // 1 hora
ini_set('session.gc_maxlifetime', $tiempoMaximoSesion);

// Establecer la duración de la cookie de sesión en segundos
$tiempoCookie = 36000; // 1 hora
ini_set('session.cookie_lifetime', $tiempoCookie);


		session_start();
		//Comprobamos si el usuario este registrado;
	//	if (isset($_SESSION['k_username'])) {

//echo '<p>Hola <b>'.$_SESSION['k_nombre'].'</b></p>';

  //  } else{
//		header("Location: ".$Base_Url);
  //    exit();

 //   }

$clave="0";
$parametro="1";
$nombreusuario="";

// Verificar si se ha pasado el parámetro "p" en la URL
if(isset($_GET['ku'])) {
    // Obtener el valor del parámetro "p"
    $parametro = $_GET['ku'];
    $nombreusuario = $_GET['u'];
    $clave= '66040577';
    // Verificar si el valor del parámetro coincide con el valor esperado
    if($parametro == $clave) {
        // se ha entrado desde ClimaGest

       				$_SESSION["k_username"] = $nombreusuario;
					$_SESSION["k_nombre"] = 'ClimaMamania';
					$_SESSION["k_apellidos"] = 'Sales Spain SL';
					$_SESSION["k_email"] = 'climamania@climamania.com';
					$_SESSION["k_iniciales"] = 'CLM';
					$_SESSION["k_rol"] = 'adminclm';
					$_SESSION["k_equipo"] = 'ADMIN';
					$_SESSION["k_accion"] = "nada"; // Variables globales necesarias para fotos
					$_SESSION["k_referencia"] = "nada"; // Variables globales necesarias para fotos
					$_SESSION["k_defaultDate"] = date('Y-m-d');
					$_SESSION["k_base_url"] = 'https://clminstal.es/';
       
       
       
       
       
       
        
        // No se realiza la verificación del inicio de sesión
    } else {
        // Redireccionar a la página de inicio de sesión
     header("Location: ".$Base_Url);
        exit();
    }
} else {
    //Comprobamos si el usuario este registrado;
    if (!isset($_SESSION['k_username'])) {
       header("Location: ".$Base_Url);
        exit();
    } else {
        echo '<p>Hola <b>'.$_SESSION['k_nombre'].'</b></p>';
    }
}
//echo 'rol ';
//echo  $_SESSION['k_rol'];
//echo ',username ';
//echo $_SESSION['k_username'];
//echo ',equipo ';
//echo $_SESSION['k_equipo'];







require_once('bdd.php');

$rol = $_SESSION['k_rol'];


if ($_SESSION['k_rol'] == 'adminclm') {
	$sql = "SELECT * FROM ClimaInstal_events ";
};
if ($_SESSION['k_rol'] == 'ope') {
	$equipo = $_SESSION['k_equipo'];
	$sql = "SELECT * FROM ClimaInstal_events WHERE equipo_instaladores = '".$equipo."' ";
};

if ($_SESSION['k_rol'] == 'adminfriconter') {

	$sql = "SELECT * FROM ClimaInstal_events where equipo_instaladores = 'FCB' or equipo_instaladores like 'FCB%' ";
};




//$sql = "SELECT * FROM ClimaInstal_events ";
$req = $bdd->prepare($sql);
$req->execute();
$events = $req->fetchAll();


// Verificamos las instalaciones finalizadas en ClimaInstal_Finalizadas y actualizamos en valor en ClimaInstal_Events

$sql3="SELECT FIN.Referencia, FIN.Usuario 
FROM ClimaInstal_Finalizadas AS FIN
INNER JOIN ClimaInstal_events AS EVE
ON FIN.Referencia = EVE.referencia";

$sql3 = "SELECT FIN.Referencia, FIN.Usuario , EVE.estado, EVE.title 
		FROM ClimaInstal_Finalizadas AS FIN
		INNER JOIN ClimaInstal_events AS EVE
		ON FIN.Referencia = EVE.referencia
		where EVE.estado IS NULL ";
							$req3 = $bdd->prepare($sql3);
							$req3->execute();
							while ($row = $req3->fetch()){

								$Operario = "*******************</br>Finalizada por: ".$row["Usuario"]. "</br>*******************</br>";
								$referenciaF = $row["Referencia"];
								$texto= $Operario .$row["title"];
								//$titleF = $texto . '</br>*************</br>' . $Operario . '</br>*************</br>';
								// actualizará el estado
								
								
								
$sql = "UPDATE ClimaInstal_events SET estado = :estado, title = :title WHERE referencia = :referencia";
$query = $bdd->prepare($sql); // Prepara la consulta correctamente

$query->execute([
    ':estado' => htmlspecialchars($Operario, ENT_QUOTES, 'UTF-8'),
    ':title' => htmlspecialchars($texto, ENT_QUOTES, 'UTF-8'),
    ':referencia' => $referenciaF
]);

								
								echo $sql;
								
								$query = $bdd->prepare( $sql );
								$sth = $query->execute();
							};

?>



<!DOCTYPE html>
<html lang="es">

<head>

    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="">
    <meta name="author" content="">

    <title>Inicio</title>

    <!-- Bootstrap Core CSS -->
    <link href="css/bootstrap.min.css" rel="stylesheet">
	
	<!-- FullCalendar -->
	<link href='css/fullcalendar.css' rel='stylesheet' />

	
    <!-- Custom CSS -->
    <style>
    body {
        padding-top: 0px;
        
    }
	.col-centered{
		float: none;
		margin: 0 auto;
	}
	.popover{
		display: none !important;
	}
@media (min-width:1200px){
	.container{width:100% !important}
	#calendar {max-width: 100%;}
    }

	.fc-scroller.fc-time-grid-container {
    height: auto !important;
	}

	.fc-time-grid .fc-event-container {
    position: initial !important;
    z-index: 4;
	}
	/* .fc-event:hover {
    z-index: 100 !important;
    width: 100%;
    top: 50 !important;
    right: 0 !important;
    left: 0 !important;
    -webkit-transition: 1s all;
	transition-delay: 0.5s;
	} */

	#ClmCuerpo form p{display: flex;justify-content: space-between;}
	
	.botonformulario{padding: 10px 20px; margin: 10px auto; color: #fff;background: #ff6500;width: 100%;height: 60px;}

@media (max-width:600px){

	h1{font-size:20px;}
	h2{font-size:25px; padding-top: 10px;}
	.botonformulario{
		width: 90%;
	}

}

#calendar {min-width:100% !important;}	

    </style>



</head>

<body>
    <!-- Page Content -->
    <div class="container">

        <div class="row">
            <div class="col-lg-12 text-center">

                <?php
                if($parametro != $clave) {
                 ?>
                <h1>ClmInstal - Calendario de Instalaciones ClimaMania</h1>
                <?php
                };
                ?>

                    <div id="calendar" class="col-centered">
                </div>
				
            </div>
			
        </div>
        <!-- /.row -->
		
		<!-- Modal Nuevo Evento-->
		<div class="modal fade" id="ModalAdd" tabindex="-1" role="dialog" aria-labelledby="myModalLabel">
		  <div class="modal-dialog" role="document">
			<div class="modal-content">
			<form class="form-horizontal" method="POST" action="addEvent.php">
			
			  <div class="modal-header">
				<button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
				<h4 class="modal-title" id="myModalLabel">Agregar Instalacion</h4>
			  </div>
			  <div class="modal-body">
				
				  <div class="form-group" style="display:none">
					<label for="title" class="col-sm-2 control-label">Titulo</label>
					<div class="col-sm-10">
					  <input type="text" name="title" class="form-control" id="title" placeholder="Titulo del envento">
					</div>
				  </div>
				  <div class="form-group">
					<label for="referencia" class="col-sm-2 control-label">Referencia</label>
					<div class="col-sm-10">
					  <input type="text" name="referencia" class="form-control" id="referencia" placeholder="Referencia de la Instalación" required>
					</div>
				  </div>
				  <div class="form-group">
					<label for="nombrecliente" class="col-sm-2 control-label">Nombre</label>
					<div class="col-sm-10">
					  <input type="text" name="nombrecliente" class="form-control" id="nombrecliente" placeholder="Nombre del Cliente">
					</div>
				  </div>
				  <div class="form-group">
					<label for="whatsapp" class="col-sm-2 control-label">WhatsApp</label>
					<div class="col-sm-10">
					  <input type="text" name="whatsapp" class="form-control" id="whatsapp" placeholder="WhatsApp para Mensajes">
					</div>
				  </div>
				  <div class="form-group">
					<label for="telefono" class="col-sm-2 control-label">Otro Teléfono</label>
					<div class="col-sm-10">
					  <input type="text" name="telefono" class="form-control" id="telefono" placeholder="Otro Teléfono de Contacto">
					</div>
				  </div>
				  <div class="form-group">
					<label for="direccion" class="col-sm-2 control-label">Dirección</label>
					<div class="col-sm-10">
					<textarea name="direccion" class="form-control" id="direccion" placeholder="Dirección de la Instalación"style="min-width: 100%"></textarea>
					</div>
				  </div>
				  <div class="form-group">
					<label for="detalles" class="col-sm-2 control-label">Articulos a Instalar</label>
					<div class="col-sm-10">
					  <textarea name="detalles" class="form-control" id="detalles" placeholder="Descripción de la Instalación"style="min-width: 100%"></textarea>

					</div>
				  </div>

				  <div class="form-group">
					<label for="comentarios" class="col-sm-2 control-label">Comentarios Adicionales</label>
					<div class="col-sm-10">
					  <textarea name="comentarios" class="form-control" id="comentarios" placeholder="Comentarios Adicionales"style="min-width: 100%"></textarea>

					</div>
				  </div>

				  <div class="form-group">
					<label for="color" class="col-sm-2 control-label">Equipo Instaladores</label>
					<div class="col-sm-10">
					  <select name="color" class="form-control" id="color">
						<option value="">Seleccionar</option>
							<?php
							// En el Select irán los instaladores de la BBDD EquiposInstaladores
						//	$sql2 = "SELECT * FROM ClimaInstal_EquiposInstaladores where Activo = 1 order by Nombre ASC ";
						if ($_SESSION['k_rol'] == 'adminfriconter') {
    $sql2 = "SELECT * FROM ClimaInstal_EquiposInstaladores WHERE Activo = 1 AND empresa = 'friconter' ORDER BY Nombre ASC";
} else {
    $sql2 = "SELECT * FROM ClimaInstal_EquiposInstaladores WHERE Activo = 1 ORDER BY Nombre ASC";
}
							$req2 = $bdd->prepare($sql2);
							$req2->execute();
							while ($row = $req2->fetch()){
								?>
								<option style="color:<?php echo $row["Color"]; ?>;" value="<?php echo $row["Color"]; ?>">&#9724; <?php echo $row["Nombre"]." - ".$row["Descripcion"]; ?></option>
								<?php
							};
							?>
						</select>
					</div>
				  </div>


				  <div class="form-group">
					<label for="concertada" class="col-sm-2 control-label">Fijada Cita</label>
					<div class="col-sm-10">
					<select name="concertada" class="form-control" id="concertada">
						<option value="">Si</option>
						<option value="PROVISIONAL">No, es Provisional</option>
						</select>
					</div>
				  </div>





				  <div class="form-group" style="" >
					<label for="start" class="col-sm-2 control-label">Fecha Inicial</label>
					<div class="col-sm-10">
					  <input type="datetime-local" name="start" class="form-control" id="start" >
					</div>


				  </div>
				  <div class="form-group" style="">
					<label for="end" class="col-sm-2 control-label">Fecha Final</label>
					<div class="col-sm-10">
					  <input type="datetime-local" name="end" class="form-control" id="end" >
					</div>
				  </div>


				  	<div class="form-group"> 
						<div class="col-sm-offset-2 col-sm-10">
						  <div class="checkbox">
							<label class="text-success"><input type="checkbox"  name="envmail">Marca esta casilla para enviar mail al Instalador.</label>
						  </div>
						</div>
					</div>



				
			  </div>
			  <div class="modal-footer">
				<button type="button" class="btn btn-info" data-dismiss="modal">Cerrar</button>
				<button type="submit" class="btn btn-success">Guardar</button>
			  </div>
			</form>
			</div>
		  </div>
		</div>
		
		
		
		<!-- Modal Modificar Evento-->
		<div class="modal fade" id="ModalEdit" tabindex="-1" role="dialog" aria-labelledby="myModalLabel">
		  <div class="modal-dialog" role="document">
			<div class="modal-content">
			<form class="form-horizontal" method="POST" action="editEventTitle.php" id="form1"> 
			<!-- <form class="form-horizontal" method="POST" action="proba.php" id="form1"> -->
			  <div class="modal-header">
				<button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
				<h4 class="modal-title" id="myModalLabel">Modificar Evento</h4>
			  </div>
			  <div class="modal-body">
				  <div class="form-group" style="display:none">
					<label for="title" class="col-sm-2 control-label">Titulo</label>
					<div class="col-sm-10">
					  <input type="text" name="title" class="form-control" id="title" placeholder="Titulo">
					</div>
				  </div>

				  <div class="form-group">
					<label for="referencia" class="col-sm-2 control-label">Referencia</label>
					<div class="col-sm-10">
					  <input type="text" name="referencia" class="form-control" id="referencia" placeholder="Referencia de la Instalación">
					</div>
				  </div>
				  
				  <div class="form-group">
					<label for="nombrecliente" class="col-sm-2 control-label">Nombre</label>
					<div class="col-sm-10">
					  <input type="text" name="nombrecliente" class="form-control" id="nombrecliente" placeholder="Nombre del Cliente">
					</div>
				  </div>
				  <div class="form-group">
					<label for="whatsapp" class="col-sm-2 control-label">WhatsApp</label>
					<div class="col-sm-10">
					  <input type="text" name="whatsapp" class="form-control" id="whatsapp" placeholder="WhatsApp para Mensajes">
					</div>
				  </div>
				  <div class="form-group">
					<label for="telefono" class="col-sm-2 control-label">Otro Teléfono</label>
					<div class="col-sm-10">
					  <input type="text" name="telefono" class="form-control" id="telefono" placeholder="Otro Teléfono de contacto">
					</div>
				  </div>
				  <div class="form-group">
					<label for="direccion" class="col-sm-2 control-label">Dirección</label>
					<div class="col-sm-10">
					<textarea name="direccion" class="form-control" id="direccion" placeholder="Dirección de la Instalación"style="min-width: 100%"></textarea>
					</div>
				  </div>
				  <div class="form-group">
					<label for="detalles" class="col-sm-2 control-label">Articulos a Instalar</label>
					<div class="col-sm-10">
					  <textarea name="detalles" class="form-control" id="detalles" placeholder="Descripción de la Instalación"style="min-width: 100%"></textarea>

					</div>
				  </div>

				  <div class="form-group">
					<label for="comentarios" class="col-sm-2 control-label">Comentarios Adicionales</label>
					<div class="col-sm-10">
					  <textarea name="comentarios" class="form-control" id="comentarios" placeholder="Comentarios Adicionales"style="min-width: 100%"></textarea>

					</div>
				  </div>



				  <div class="form-group" style="" >
					<label for="start" class="col-sm-2 control-label">Fecha Inicial</label>
					<div class="col-sm-10">
					  <input type="datetime-local" name="start" class="form-control" id="start" >
					</div>
				  </div>
				  <div class="form-group" style="">
					<label for="end" class="col-sm-2 control-label">Fecha Final</label>
					<div class="col-sm-10">
					  <input type="datetime-local" name="end" class="form-control" id="end" >
					</div>
				  </div>

				  <div class="form-group">
					<label for="concertada" class="col-sm-2 control-label">Fijada Cita</label>
					<div class="col-sm-10">
					<select name="concertada" class="form-control" id="concertada">
						<option value="">Si</option>
						<option value="PROVISIONAL">No, es Provisional</option>
						</select>
					</div>
				  </div>



				  <div class="form-group">
					<label for="color" class="col-sm-2 control-label">Equipo Instaladores</label>
					<div class="col-sm-10">
					<select name="color" class="form-control" id="color">
						<option value="">Seleccionar</option>
							<?php
							// En el Select irán los instaladores de la BBDD EquiposInstaladores
						//	$sql2 = "SELECT * FROM ClimaInstal_EquiposInstaladores where Activo = 1";
							
							if ($_SESSION['k_rol'] == 'adminfriconter') {
    $sql2 = "SELECT * FROM ClimaInstal_EquiposInstaladores WHERE Activo = 1 AND empresa = 'friconter' ORDER BY Nombre ASC";
} else {
    $sql2 = "SELECT * FROM ClimaInstal_EquiposInstaladores WHERE Activo = 1 ORDER BY Nombre ASC";
}
							
							
							$req2 = $bdd->prepare($sql2);
							$req2->execute();
							while ($row = $req2->fetch()){
								?>
								<option style="color:<?php echo $row["Color"]; ?>;" value="<?php echo $row["Color"]; ?>">&#9724; <?php echo $row["Nombre"]." - ".$row["Descripcion"]; ?></option>
								<?php
							};
							?>
						</select>
					</div>
				  </div>

				  <div class="form-group"> 
						<div class="col-sm-offset-2 col-sm-10">
						  <div class="checkbox">
							<label class="text-success"><input type="checkbox"  name="envmail">Marca esta casilla para enviar mail al Instalador.</label>
						  </div>
						</div>
					</div>

				    <div class="form-group"> 
						<div class="col-sm-offset-2 col-sm-10">
						  <div class="checkbox">
							<label class="text-success"><input type="checkbox"  name="ver"> Ver datos instalacion</label>
						  </div>
						</div>
					</div>


				    <div class="form-group"> 
						<div class="col-sm-offset-2 col-sm-10">
						  <div class="checkbox">
							<label class="text-success"><input type="checkbox"  name="duplica"> Duplicar Cita</label>
						  </div>
						</div>
					</div>



				    <div class="form-group"> 
						<div class="col-sm-offset-2 col-sm-10">
						  <div class="checkbox">
							<label class="text-danger"><input type="checkbox"  name="delete"> Eliminar Evento</label>
						  </div>
						</div>
					</div>


				  
				  <input type="hidden" name="id" class="form-control" id="id">
				
				
			  </div>
			  <div class="modal-footer">
				<button type="button" class="btn btn-danger" data-dismiss="modal">Cerrar</button>
		
				<button type="submit" class="btn btn-success">Guardar</button>
			  </div>
			</form>


			</div>
		  </div>
		</div>

    </div>




	<script>
		document.getElementById('send').addEventListener('click', (e) => {
  e.preventDefault()

  if(document.getElementById('cod').value == '01')
    formulario.setAttribute('action', 'ventas/registrar_venta')

  if(document.getElementById('cod').value == '03')
    formulario.setAttribute('action', 'ventas/registrar_compra')

  document.getElementById('comprobante').submit()

})
	</script>	

    <!-- /.container -->

    <!-- jQuery Version 1.11.1 -->
    <script src="js/jquery.js"></script>

    <!-- Bootstrap Core JavaScript -->
    <script src="js/bootstrap.min.js"></script>
	
	<!-- FullCalendar -->
	<script src='js/moment.min.js'></script>
	<script src='js/fullcalendar/fullcalendar.min.js'></script>
	<script src='js/fullcalendar/fullcalendar.js'></script>
	<script src='js/fullcalendar/locale/es.js'></script>
	
	
	<script>
		//Elimina espacios de la referencia
		$("#referencia").keyup(function(){
			let string = $("#referencia").val();
			$("#referencia").val(string.replace(/ /g, ""));

		}),

		//Compone el calendario
	$(document).ready(function() {

		var date = new Date();
       var yyyy = date.getFullYear().toString();
       var mm = (date.getMonth()+1).toString().length == 1 ? "0"+(date.getMonth()+1).toString() : (date.getMonth()+1).toString();
       var dd  = (date.getDate()).toString().length == 1 ? "0"+(date.getDate()).toString() : (date.getDate()).toString();
		
		$('#calendar').fullCalendar({
			header: {
				language: 'es',
				left: 'prev next today',
				center: 'title',
				right: 'agendaWeek agendaDay'

			},
			businessHours: {
				start: '08:00', // hora final
				end: '20:00', // hora inicial
				dow: [ 1, 2, 3, 4, 5, 6 ] // dias de semana, 0=Domingo
      		},


			eventLimit: true,
			weekend: true,
			allDaySlot: false,
			minTime: '08:00:00',
			maxTime: '21:00:00',
			dayMinWidth: 240,
			hiddenDays: [ 0 ],

 
			defaultView: 'agendaDay',

			 <?php if ($_SESSION['k_rol']!='ope'){
		 	?>
			defaultView: 'agendaWeek', // si es administrador, la vista por defecto es semanal
			<?php } ?>

			// la fecha de la vista del calendario la tomamos de la variable global, para que al guardar o modificar no cambie a hoy
			defaultDate: "<?php echo $_SESSION["k_defaultDate"];?>", 
			//defaultDate: yyyy+"-"+mm+"-"+dd,
			
			editable: true,
			eventLimit: true, // allow "more" link when too many events
			selectable: true,
			selectHelper: true,
			select: function(start, end) {
				
				$('#ModalAdd #start').val(moment(start).format('YYYY-MM-DD HH:mm:ss'));
				$('#ModalAdd #end').val(moment(end).format('YYYY-MM-DD HH:mm:ss'));
				$('#ModalAdd').modal('show');
			},
			eventRender: function(event, element) {
				element.popover({
                    title: event.title,
                    placement: 'bottom',
                    content: event.description,
					
                });
                element.find('div.fc-title').html(element.find('div.fc-title').text()) ;

				element.bind('dblclick', function() {
					$('#ModalEdit #id').val(event.id);
					$('#ModalEdit #title').val(event.title);
					$('#ModalEdit #color').val(event.color);
					$('#ModalEdit #referencia').val(event.referencia);
					$('#ModalEdit #nombrecliente').val(event.nombrecliente);
					$('#ModalEdit #whatsapp').val(event.whatsapp);
					$('#ModalEdit #telefono').val(event.telefono);
					$('#ModalEdit #direccion').val(event.direccion);
					$('#ModalEdit #detalles').val(event.detalles);
					$('#ModalEdit #comentarios').val(event.comentarios);
					$('#ModalEdit #concertada').val(event.concertada);
					//$('#ModalEdit #start').val((event.start);
					//$('#ModalEdit #end').val(event.end);
					$('#ModalEdit #start').val((event.start).format('YYYY-MM-DD HH:mm:ss'));
					$('#ModalEdit #end').val((event.end).format('YYYY-MM-DD HH:mm:ss'));
					
					// No permite editar a los operarios, solo a los Administradores
					<?php
					if ($_SESSION['k_rol']!='ope'){
						
						?>
					$('#ModalEdit').modal('show');	
						<?php
					}?>
				
				});
			},
			eventDrop: function(event, delta, revertFunc) { // si changement de position
	
				edit(event);

			},
			eventResize: function(event,dayDelta,minuteDelta,revertFunc) { // si changement de longueur

				edit(event);

			},
			events: [
			<?php foreach($events as $event): 
			
				$start = explode(" ", $event['start']);
				$end = explode(" ", $event['end']);
				if($start[1] == '00:00:00'){
					$start = $start[0];
				}else{
					$start = $event['start'];
				}
				if($end[1] == '00:00:00'){
					$end = $end[0];
				}else{
					$end = $event['end'];
				}
			?>
				{
					id: '<?php echo $event['id']; ?>',
					title: '<?php echo $event['title']; ?>',
					start: '<?php echo $start; ?>',
					end: '<?php echo $end; ?>',
					color: '<?php echo $event['color']; ?>',
					referencia: '<?php echo $event['referencia']; ?>',
					nombrecliente: '<?php echo $event['nombrecliente']; ?>',
					whatsapp: '<?php echo $event['whatsapp']; ?>',
					telefono: '<?php echo $event['telefono']; ?>',
					direccion: '<?php echo $event['direccion']; ?>',
					detalles: '<?php echo $event['detalles']; ?>',
					comentarios: '<?php echo $event['comentarios']; ?>',
					concertada: '<?php echo $event['concertada']; ?>',


				},
			<?php endforeach; ?>
			]
		});
		
		function edit(event){
			start = event.start.format('YYYY-MM-DD HH:mm:ss');
			if(event.end){
				end = event.end.format('YYYY-MM-DD HH:mm:ss');
			}else{
				end = start;
			}
			
			id =  event.id;
			Event = [];
			Event[0] = id;
			Event[1] = start;
			Event[2] = end;
			// Al hacer Drop pregunta si quiere enviar o no mail al instalador
			var mensaje;
				var opcion = confirm("¿Quieres enviar mail al instalador");
				if (opcion == true) {
					Event[3] = 1; // 1 envia mensaje
				} else {
					Event[3] = 0; // 0 no envia mensaje
				}
			
			$.ajax({
			 url: 'editEventDate.php',
			 type: "POST",
			 data: {Event:Event},
			 success: function(rep) {
					if(rep == 'OK'){
						//alert('Evento se ha guardado correctamente');
					}else{
						alert('No se pudo guardar. Inténtalo de nuevo.'); 
					}
				}
			});
		}
		
	});

</script>


                <?php
                if($parametro != $clave) {
                 ?>
<div id="ClmCuerpo">
<form name="formulario" action="/NumPedido.php" method="post">
		<p><input type="submit" class="botonformulario" value="Regresar al menú " /></p>
</form>
</div>
                <?php
                };
                ?>



</body>

</html>
