<?php

//datos para establecer la conexion con la base de mysql en FullwebSystem


$mysqli = new mysqli("www.fullwebsystem.com", "ynrlpmed_admin", "r&^%1CB%Gxfi", "ynrlpmed_fulls");
if ($mysqli->connect_errno) {
    echo "Falló la conexión a FULLWEBSYSTEM: (" . $mysqli->connect_errno . ") " . $mysqli->connect_error;
}

// IMPORTANTE, LOS ACCESOS A LA BASE DE DATOS DEL CALENDARIO ESTAN EN /calendario/bdd.php  HAY QUE CAMBIARLOS TAMBIEN ALLI.

$mysqli->query("SET NAMES 'utf8'");


//datos para establecer la conexion con la base de mysql en PS

// $mysqli2 = new mysqli("www.climamania.com", "climaman_2109", "eQoTbJu9KXnR", "climaman_2019"); Web PRE 2023
$mysqli2 = new mysqli("www.climamania.com", "climaman_2023", "!+6o7G]ohSEy", "climaman_2023");

if ($mysqli2->connect_errno) {
    echo "Falló la conexión a MySQL: (" . $mysqli2->connect_errno . ") " . $mysqli2->connect_error;
}

$mysqli2->query("SET NAMES 'utf8'");

$Base_Url = "https://clminstal.es";

header("Content-type:text/html; charset=utf-8");

?>