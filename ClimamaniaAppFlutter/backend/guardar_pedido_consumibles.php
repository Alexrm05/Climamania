<?php
// Pedido de consumibles del instalador.
//
// No toca PrestaShop, GOTEL ni ClimaGEST: registra la solicitud en
// ClimaInstal_PedidosConsumibles (+ _Lineas) y avisa por correo a compras y
// al instalador. Si un correo falla, el pedido queda guardado igualmente y se
// devuelve el aviso para enseñarlo en pantalla.
//
// Los precios NO se toman del móvil: se vuelven a leer del catálogo y se
// guarda una copia en la línea, porque la tarifa cambia y el pedido tiene que
// conservar los precios del día en que se pidió.
//
// POST: api_key, usuario, equipo, email (confirmación), observaciones,
//       lineas = JSON [{id, cantidad_formatos}]

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once __DIR__ . "/presupuestos_api_common.php";
require_once __DIR__ . "/conexion.php";
require_once __DIR__ . "/pedidos_consumibles_common.php";

$API_KEY = "TEST123";
presup_require_api_key($API_KEY);

date_default_timezone_set("Europe/Madrid");

$usuario = presup_normalize_text(presup_request_value("usuario"), 100);
$equipo = presup_normalize_text(presup_request_value("equipo"), 100);
$emailPedido = presup_normalize_email((string)presup_request_value("email"));
$observaciones = trim((string)presup_request_value("observaciones"));
$lineasRaw = presup_request_value("lineas");

// Solo pueden pedir usuarios identificados en la app.
if ($usuario === "") {
    presup_json_exit(["success" => false, "message" => "Sesión no identificada"], 400);
}

$lineasIn = is_string($lineasRaw) ? json_decode($lineasRaw, true) : $lineasRaw;
if (!is_array($lineasIn) || empty($lineasIn)) {
    presup_json_exit(["success" => false, "message" => "Añade algún artículo al pedido"], 400);
}

// Cantidad por artículo: formatos completos, entero >= 1.
$pedidas = [];
foreach ($lineasIn as $item) {
    if (!is_array($item)) {
        continue;
    }
    $id = (int)($item["id"] ?? 0);
    $cant = (int)round(clm_num($item["cantidad_formatos"] ?? 0));
    if ($id <= 0 || $cant < 1) {
        continue;
    }
    $pedidas[$id] = ($pedidas[$id] ?? 0) + $cant;
}
if (empty($pedidas)) {
    presup_json_exit(["success" => false, "message" => "Indica cuántos formatos pides de cada artículo"], 400);
}

$pdo = null;
try {
    $pdo = getDBConnection();

    // 1) Precios y disponibilidad, releídos del catálogo.
    $ph = implode(",", array_fill(0, count($pedidas), "?"));
    $stmt = $pdo->prepare(
        "SELECT Id, IdGotel, Codigo, Nombre, Descripcion, TextoFormato, UnidadVenta,
                PVFormato, PVUnidad, Formato, Factor, FotoUrl, FechaPrecios
         FROM " . CLM_CONSUMIBLES_TABLA . "
         WHERE Id IN ($ph) AND ListarTarifa = 1
           AND PVFormato IS NOT NULL AND PVFormato > 0"
    );
    $stmt->execute(array_keys($pedidas));
    $catalogo = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
        $catalogo[(int)$r["Id"]] = clm_consumible_tarifa_salida($r);
    }

    $lineas = [];
    $descartados = [];
    $total = 0.0;
    $n = 0;
    foreach ($pedidas as $id => $cant) {
        $art = $catalogo[$id] ?? null;
        if ($art === null) {
            $descartados[] = $id;
            continue;
        }
        $precioFormato = (float)$art["precio_formato"];
        $porFormato = (float)$art["unidades_por_formato"];
        $importe = round($cant * $precioFormato, 2);
        $total += $importe;
        $lineas[] = [
            "linea" => ++$n,
            "id_consumible" => $art["id"],
            "id_gotel" => $art["id_gotel"],
            "codigo" => $art["codigo"],
            "descripcion" => $art["descripcion"],
            "texto_formato" => $art["texto_formato"],
            "unidad_venta" => $art["unidad_venta"],
            "unidades_por_formato" => $porFormato,
            "cantidad_formatos" => $cant,
            "cantidad_unidades" => round($cant * $porFormato, 4),
            "precio_formato" => $precioFormato,
            "precio_unidad" => (float)$art["precio_unidad"],
            "importe_linea" => $importe
        ];
    }
    if (empty($lineas)) {
        presup_json_exit([
            "success" => false,
            "message" => "Los artículos del pedido ya no están en la tarifa. Vuelve a abrirla."
        ], 200);
    }
    $total = round($total, 2);

    // Nombre y correo salen de la ficha, no del móvil.
    $solicitante = clm_pedidos_solicitante($pdo, $usuario, $equipo);
    $equipo = $solicitante["equipo"];
    if ($emailPedido === "") {
        $emailPedido = $solicitante["email"];
    }

    // 2) Cabecera y líneas, en una transacción.
    $ahora = date("Y-m-d H:i:s");
    $pdo->beginTransaction();

    $insCab = $pdo->prepare(
        "INSERT INTO ClimaInstal_PedidosConsumibles
            (Referencia, FechaSolicitud, Usuario, NombreSolicitante, EmailSolicitante,
             Equipo, Observaciones, NumLineas, TotalSinIVA, Estado,
             FechaCreacion, FechaModificacion)
         VALUES ('', :fecha, :usuario, :nombre, :email, :equipo, :obs, :n, :total,
                 'SOLICITADO', :fecha2, :fecha3)"
    );
    $insCab->execute([
        ":fecha" => $ahora,
        ":usuario" => $usuario,
        ":nombre" => $solicitante["nombre"],
        ":email" => $emailPedido,
        ":equipo" => $equipo,
        ":obs" => $observaciones !== "" ? $observaciones : null,
        ":n" => count($lineas),
        ":total" => number_format($total, 2, ".", ""),
        ":fecha2" => $ahora,
        ":fecha3" => $ahora
    ]);
    $idPedido = (int)$pdo->lastInsertId();
    $referencia = "PC-" . str_pad((string)$idPedido, 6, "0", STR_PAD_LEFT);
    $pdo->prepare("UPDATE ClimaInstal_PedidosConsumibles SET Referencia = :r WHERE Id = :id")
        ->execute([":r" => $referencia, ":id" => $idPedido]);

    $insLin = $pdo->prepare(
        "INSERT INTO ClimaInstal_PedidosConsumibles_Lineas
            (IdPedido, Linea, IdConsumible, IdGotel, Codigo, Descripcion, TextoFormato,
             UnidadVenta, UnidadesPorFormato, CantidadFormatos, CantidadUnidades,
             PrecioFormato, PrecioUnidad, ImporteLinea)
         VALUES (:pedido, :linea, :idc, :idg, :codigo, :descripcion, :formato,
                 :unidad, :porformato, :cant, :unidades, :pformato, :punidad, :importe)"
    );
    foreach ($lineas as $l) {
        $insLin->execute([
            ":pedido" => $idPedido,
            ":linea" => $l["linea"],
            ":idc" => $l["id_consumible"],
            ":idg" => $l["id_gotel"],
            ":codigo" => $l["codigo"],
            ":descripcion" => $l["descripcion"],
            ":formato" => $l["texto_formato"],
            ":unidad" => $l["unidad_venta"],
            ":porformato" => number_format($l["unidades_por_formato"], 4, ".", ""),
            ":cant" => number_format($l["cantidad_formatos"], 2, ".", ""),
            ":unidades" => number_format($l["cantidad_unidades"], 4, ".", ""),
            ":pformato" => number_format($l["precio_formato"], 2, ".", ""),
            ":punidad" => number_format($l["precio_unidad"], 4, ".", ""),
            ":importe" => number_format($l["importe_linea"], 2, ".", "")
        ]);
    }
    $pdo->commit();

    // 3) y 4) Correos. El pedido ya está grabado: un fallo aquí no lo deshace.
    $cab = [
        "referencia" => $referencia,
        "fecha" => date("d/m/Y H:i"),
        "usuario" => $usuario,
        "nombre" => $solicitante["nombre"],
        "equipo" => $equipo,
        "email" => $emailPedido,
        "observaciones" => $observaciones,
        "total" => $total
    ];
    $quien = clm_pedidos_equipo_descripcion($pdo, $equipo);
    $asunto = "Pedido consumibles " . $referencia
        . ($equipo !== "" ? " · Equipo " . $equipo : "")
        . ($quien !== "" ? " · " . $quien : "");

    $errores = [];
    $errCompras = "";
    $okCompras = clm_pedidos_enviar_mail(
        clm_pedidos_destino($pdo),
        $asunto,
        clm_pedidos_cuerpo($cab, $lineas, "Nuevo pedido de consumibles desde la app de instaladores."),
        $emailPedido,
        $errCompras
    );
    if (!$okCompras) {
        $errores[] = "compras: " . $errCompras;
    }

    $okConfirmacion = false;
    if ($emailPedido !== "") {
        $errConf = "";
        $okConfirmacion = clm_pedidos_enviar_mail(
            $emailPedido,
            "Hemos recibido tu pedido de consumibles " . $referencia,
            clm_pedidos_cuerpo(
                $cab,
                $lineas,
                "Tu pedido de consumibles se ha solicitado correctamente y se tramitará en breve."
            ),
            "",
            $errConf
        );
        if (!$okConfirmacion) {
            $errores[] = "confirmación: " . $errConf;
        }
    } else {
        $errores[] = "confirmación: el instalador no tiene correo";
    }

    // 5) Marcas de envío.
    $pdo->prepare(
        "UPDATE ClimaInstal_PedidosConsumibles
            SET EmailComprasEnviado = :c, FechaEmailCompras = :fc,
                EmailConfirmacionEnviado = :k, FechaEmailConfirmacion = :fk,
                ErrorEmail = :err, FechaModificacion = :mod
          WHERE Id = :id"
    )->execute([
        ":c" => $okCompras ? 1 : 0,
        ":fc" => $okCompras ? date("Y-m-d H:i:s") : null,
        ":k" => $okConfirmacion ? 1 : 0,
        ":fk" => $okConfirmacion ? date("Y-m-d H:i:s") : null,
        ":err" => empty($errores) ? null : mb_substr(implode(" | ", $errores), 0, 500),
        ":mod" => date("Y-m-d H:i:s"),
        ":id" => $idPedido
    ]);

    presup_json_exit([
        "success" => true,
        "referencia" => $referencia,
        "id" => $idPedido,
        "num_lineas" => count($lineas),
        "total_sin_iva" => number_format($total, 2, ".", ""),
        "email_compras_enviado" => $okCompras,
        "email_confirmacion_enviado" => $okConfirmacion,
        "articulos_descartados" => $descartados,
        "message" => empty($errores)
            ? "Pedido " . $referencia . " enviado"
            : "Pedido " . $referencia . " registrado, pero no se pudo enviar el correo ("
                . implode(" | ", $errores) . ")"
    ]);
} catch (PDOException $e) {
    if ($pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    if ($e->getCode() === "42S02") {
        presup_json_exit([
            "success" => false,
            "message" => "Faltan las tablas de pedidos de consumibles. Ejecuta el SQL pendiente."
        ], 200);
    }
    presup_json_exit(["success" => false, "message" => "ERROR: " . $e->getMessage()], 200);
} catch (Throwable $e) {
    if ($pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    presup_json_exit(["success" => false, "message" => "ERROR: " . $e->getMessage()], 200);
}
