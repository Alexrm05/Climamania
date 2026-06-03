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
        window.onload = function () {
            document.formulario.usuario.focus()
        }
    </script>
</head>

<body>

    <?php
    include("cabeceralog.php");

    $directorio = 'imagenes/';

    // Usamos pathinfo para extraer la extensión del archivo de manera más segura
    $info_archivo = pathinfo($_FILES['subir_archivo']['name']);
    $extension = $info_archivo['extension'];

    // Asegúrate de que la extensión no esté vacía
    if (!empty($extension)) {
        // Construye el nombre del archivo correctamente
        $subir_archivo = $directorio . $_SESSION["k_referencia"] . "-" . $_SESSION["k_accion"] . "-" . date("Ymdhis") . "-" . $_SESSION["k_iniciales"] . "." . $extension;

        // Reemplazar '..' por '.' a veces ocurre error en preinst
        $subir_archivo = str_replace('..', '.', $subir_archivo);

        echo "<div>";
        if (move_uploaded_file($_FILES['subir_archivo']['tmp_name'], $subir_archivo)) {
            echo "El archivo es válido y se cargó correctamente.<br><br>";
            echo "<a href='" . $subir_archivo . "' target='_blank'><img src='" . $subir_archivo . "' width='150'></a>";

            // Guardamos el registro en la base de datos
            include("conexion.php");
            $clave = $_SESSION["k_accion"];

            $mysqli->query("INSERT INTO ClimaInstal_Fotografias (Documento, Clave, Fecha) VALUES ('$subir_archivo', '$clave', now())");

            // Actualizamos el campo Documento para reemplazar '..' por '.' si existe
            $mysqli->query("UPDATE ClimaInstal_Fotografias SET Documento = REPLACE(Documento, '..', '.') WHERE Documento LIKE '%..%'");

            // Mostrar mensaje de alerta en un alert
            echo "<script>alert('La fotografía se ha almacenado correctamente.');</script>";
        } else {
            echo "La subida ha fallado. Tipo de archivo no válido o superado el tamaño máximo";
        }
        echo "</div>";
    } else {
        echo "Error: No se pudo obtener la extensión del archivo.";
    }
    ?>

    <br>
    <form id='form1' name='form1' method="post">
        <p></p>
        <input style="display: none" name="pedido" type="text" class="cuadroform" id="pedido" size="8" maxlength="25"
            value="<?php echo trim($_POST["pedido"]); ?>" readonly />
        <input type="button" value="Volver al Menu" id="menu" name="menu" class=""
            onclick="document.form1.action = 'menu.php'; document.form1.submit()" />
    </form>
</body>

</html>

