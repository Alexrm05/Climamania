<?php
include("conexion.php");
  session_start();
  session_destroy();

  header("Location: ".$Base_Url);
    ?>
 