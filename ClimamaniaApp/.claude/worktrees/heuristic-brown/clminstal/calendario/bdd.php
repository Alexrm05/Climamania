<?php
try
{
	//$bdd = new PDO('mysql:host=localhost;dbname=calendar;charset=utf8', 'root', '');
        $bdd = new PDO('mysql:host=www.fullwebsystem.com;dbname=ynrlpmed_fulls;charset=utf8', 'ynrlpmed_admin', 'r&^%1CB%Gxfi');
}
catch(Exception $e)
{
        die('Error : '.$e->getMessage());
}
