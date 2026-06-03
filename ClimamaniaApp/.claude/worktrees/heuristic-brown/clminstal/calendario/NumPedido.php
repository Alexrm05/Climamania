<!DOCTYPE html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">  
<title>ClimaMania</title>
<link rel="stylesheet" href="styles.css">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Rubik:wght@300;400;500;600&display=swap" rel="stylesheet">

<script type="text/javascript">
 // centra foco en formulario al cargar la pagina
  window.onload= function(){
  document.formulario.usuario.focus()
  }
</script>
</head>
<body>
<div id="cabecera">
<a href="https://clminstal.es"><img src="img/logo.jpg"></a>
</div>
<div id="ClmCuerpo">


<?php
		session_start();
		//Comprobamos si el usuario este registrado;
		if (isset($_SESSION['k_username'])) {

echo '<p>Hola <b>'.$_SESSION['k_nombre'].'</b></p>';
    } else{
      header("Location: https://www.clminstal.es");
      exit();

    }
?>

 <form name="formulario" action="menu.php" method="post">
	<p>Referencia Instalación <input name="pedido" type="text" class="cuadroform" id="pedido" size="8" maxlength="25" /> </p>

	<p><input type="submit" class="botonformulario" value="Acceder " /> </p>
</form>
<p style="display:none"><a href="https://www.clminstal.es/calendario">a</a></p>
</div>
</body>
</html>