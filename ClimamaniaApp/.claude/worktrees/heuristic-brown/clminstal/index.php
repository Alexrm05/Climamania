<!DOCTYPE html>

<head>
      <link rel="icon" type="image/x-icon" href="/img/favicon.ico">

    <link href="//netdna.bootstrapcdn.com/font-awesome/4.1.0/css/font-awesome.min.css" rel="stylesheet">
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
    <div id="imgPortada">
<img class="imgIndex" src="img/logo.jpg" width="200px"></div>
<div id="ClmCuerpo">
<h3>Bienvenido a ClimaMania Instalaciones</h3>

 <form name="formulario" action="validar_usuario.php" method="post">
	<p class="textNoMargin">Usuario</p> <input name="usuario" type="text" class="cuadroform"  placeholder=' &#xf007; Nombre de usuario' id="usuario" size="8" maxlength="25" />
	<p class="textNoMargin">Contraseña </p><input name="password" type="password" class="cuadroform" placeholder=" &#xf023; Contraseña de tu cuenta" id="password" size="8" maxlength="25" /> 
	<input type="submit" class="botonformulario" value="Acceder " />
</form>

</div>


</body>
</html>