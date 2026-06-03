

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
<?php
echo'hola';
echo $_POST['referencia'];
echo $_SESSION["k_referencia"];
header("Location: https://www.clminstal.es/instalacion.php");

?>