<?php

require_once __DIR__ . "/visitas_api_common.php";

function presup_request_value(string $key): string
{
    if (isset($_POST[$key])) {
        return trim((string)$_POST[$key]);
    }
    if (isset($_GET[$key])) {
        return trim((string)$_GET[$key]);
    }
    return "";
}

function presup_json_exit(array $payload, int $status = 200): void
{
    http_response_code($status);
    while (ob_get_level() > 0) {
        @ob_end_clean();
    }
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

function presup_register_fatal_json_handler(string $fallbackMessage, int $status = 200): void
{
    register_shutdown_function(function () use ($fallbackMessage, $status): void {
        $error = error_get_last();
        if (!is_array($error)) {
            return;
        }

        $fatalTypes = [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR, E_USER_ERROR];
        if (!in_array((int)($error['type'] ?? 0), $fatalTypes, true)) {
            return;
        }

        if (headers_sent()) {
            return;
        }

        $message = trim((string)($error['message'] ?? ''));
        $file = trim((string)($error['file'] ?? ''));
        $line = (int)($error['line'] ?? 0);

        $parts = [];
        if ($message !== '') {
            $parts[] = $message;
        }
        if ($file !== '') {
            $parts[] = basename($file) . ($line > 0 ? ':' . $line : '');
        }

        $finalMessage = $fallbackMessage;
        if (!empty($parts)) {
            $finalMessage .= ': ' . implode(' | ', $parts);
        }

        while (ob_get_level() > 0) {
            @ob_end_clean();
        }
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'success' => false,
            'message' => $finalMessage
        ], JSON_UNESCAPED_UNICODE);
    });
}

function presup_require_api_key(string $expectedApiKey): void
{
    $apiKey = presup_request_value("api_key");
    if ($apiKey !== $expectedApiKey) {
        presup_json_exit(["success" => false, "message" => "API key invalida"], 401);
    }
}

function presup_is_admin_role(string $rol): bool
{
    return visitas_is_admin_role($rol);
}

function presup_normalize_text(string $value, int $maxLen = 1000): string
{
    $clean = trim(str_replace("\0", "", $value));
    if ($maxLen > 0 && mb_strlen($clean, "UTF-8") > $maxLen) {
        $clean = mb_substr($clean, 0, $maxLen, "UTF-8");
    }
    return $clean;
}

function presup_normalize_email(string $value): string
{
    $clean = trim((string)$value);
    return filter_var($clean, FILTER_VALIDATE_EMAIL) ? $clean : "";
}

function presup_parse_decimal($raw, float $default = 0.0): float
{
    $value = trim((string)$raw);
    if ($value === "") {
        return $default;
    }
    $value = str_replace(",", ".", $value);
    if (!is_numeric($value)) {
        return $default;
    }
    return (float)$value;
}

function presup_format_decimal(float $value, int $scale): string
{
    return number_format($value, $scale, ".", "");
}

function presup_parse_lineas(string $jsonRaw): array
{
    $decoded = json_decode($jsonRaw, true);
    if (!is_array($decoded)) {
        return [];
    }

    $lineas = [];
    foreach ($decoded as $row) {
        if (!is_array($row)) {
            continue;
        }

        $cantidad = presup_parse_decimal($row["cantidad"] ?? "0", 0.0);
        if ($cantidad <= 0.0) {
            continue;
        }

        $articulo = presup_normalize_text((string)($row["articulo"] ?? ($row["codigo"] ?? "")), 120);
        if ($articulo === "") {
            $articulo = "SIN-CODIGO";
        }

        $descripcion = presup_normalize_text((string)($row["descripcion"] ?? ""), 4000);
        if ($descripcion === "") {
            $descripcion = "Sin descripcion";
        }

        $precioUnitarioSinIva = presup_parse_decimal(
            $row["precio_unitario_sin_iva"] ?? ($row["precio_unitario"] ?? "0"),
            0.0
        );
        if ($precioUnitarioSinIva < 0.0) {
            $precioUnitarioSinIva = 0.0;
        }

        $precioTotalLinea = presup_parse_decimal(
            $row["precio_total_linea_sin_iva"] ?? ($row["precio_total_sin_iva"] ?? "0"),
            0.0
        );
        if ($precioTotalLinea <= 0.0) {
            $precioTotalLinea = $cantidad * $precioUnitarioSinIva;
        }

        $ivaPct = presup_parse_decimal($row["iva_pct"] ?? "21", 21.0);
        if ($ivaPct < 0.0) {
            $ivaPct = 0.0;
        }

        $precioTotalLineaConIva = presup_parse_decimal(
            $row["precio_total_linea_con_iva"] ?? ($row["precio_total_con_iva"] ?? "0"),
            0.0
        );
        if ($precioTotalLineaConIva <= 0.0) {
            $precioTotalLineaConIva = $precioTotalLinea * (1.0 + ($ivaPct / 100.0));
        }

        $ivaFallback = filter_var($row["iva_fallback"] ?? false, FILTER_VALIDATE_BOOLEAN);

        $lineas[] = [
            "cantidad" => round($cantidad, 2),
            "articulo" => $articulo,
            "descripcion" => $descripcion,
            "precio_unitario_sin_iva" => round($precioUnitarioSinIva, 6),
            "precio_total_linea" => round($precioTotalLinea, 2),
            "iva_pct" => round($ivaPct, 3),
            "precio_total_linea_con_iva" => round($precioTotalLineaConIva, 2),
            "iva_fallback" => $ivaFallback
        ];
    }

    return $lineas;
}

function presup_calculate_totals(array $lineas): array
{
    $sinIva = 0.0;
    $conIva = 0.0;
    foreach ($lineas as $linea) {
        $sinIva += (float)($linea["precio_total_linea"] ?? 0);
        $conIva += (float)($linea["precio_total_linea_con_iva"] ?? 0);
    }
    $sinIva = round($sinIva, 2);
    $conIva = round($conIva, 2);
    $iva = round($conIva - $sinIva, 2);

    return [
        "sin_iva" => $sinIva,
        "iva" => $iva,
        "con_iva" => $conIva
    ];
}

function presup_resolve_images_root(): string
{
    $candidates = [];

    $envDir = getenv("CLM_IMAGES_DIR");
    if (is_string($envDir) && trim($envDir) !== "") {
        $candidates[] = trim($envDir);
    }

    // Cobertura para despliegues con PHP en raíz y con PHP dentro de /api.
    $dirName = strtolower((string)basename(__DIR__));
    if ($dirName === "api") {
        $candidates[] = __DIR__ . "/../imagenes";
        $candidates[] = __DIR__ . "/imagenes";
    } else {
        $candidates[] = __DIR__ . "/imagenes";
        $candidates[] = __DIR__ . "/../imagenes";
    }
    $candidates[] = __DIR__ . "/../../imagenes";

    // 1) Preferir una carpeta existente.
    foreach ($candidates as $candidate) {
        $candidate = rtrim(str_replace("\\", "/", (string)$candidate), "/");
        if ($candidate === "") {
            continue;
        }
        if (is_dir($candidate)) {
            $real = realpath($candidate);
            return rtrim($real !== false ? $real : $candidate, "/");
        }
    }

    // 2) Si no existe ninguna, elegir la primera cuyo padre exista para poder crearla.
    foreach ($candidates as $candidate) {
        $candidate = rtrim(str_replace("\\", "/", (string)$candidate), "/");
        if ($candidate === "") {
            continue;
        }
        $parent = dirname($candidate);
        if (is_dir($parent)) {
            return $candidate;
        }
    }

    return rtrim(str_replace("\\", "/", (string)(__DIR__ . "/imagenes")), "/");
}

function presup_ensure_dir(string $dir): void
{
    if (is_dir($dir)) {
        return;
    }
    if (!mkdir($dir, 0775, true) && !is_dir($dir)) {
        throw new RuntimeException("No se pudo crear el directorio: " . $dir);
    }
}

function presup_normalize_media_path(string $ruta): string
{
    $clean = trim(str_replace("\\", "/", $ruta));
    if ($clean === "") {
        return "";
    }
    if (stripos($clean, "http://") === 0 || stripos($clean, "https://") === 0) {
        return $clean;
    }
    $clean = (string)preg_replace('#/+#', '/', $clean);
    return ltrim($clean, "/");
}

function presup_public_media_path(string $ruta): string
{
    $raw = trim(str_replace("\\", "/", $ruta));
    if ($raw === "") {
        return "";
    }
    if (stripos($raw, "http://") === 0 || stripos($raw, "https://") === 0) {
        return $raw;
    }

    $raw = (string)preg_replace('#/+#', '/', $raw);
    $imagesRoot = rtrim(str_replace("\\", "/", presup_resolve_images_root()), "/");
    $projectRoot = rtrim(str_replace("\\", "/", dirname($imagesRoot)), "/");

    if ($imagesRoot !== "" && strpos($raw, $imagesRoot . "/") === 0) {
        $suffix = ltrim(substr($raw, strlen($imagesRoot)), "/");
        return "imagenes/" . $suffix;
    }

    if ($projectRoot !== "" && strpos($raw, $projectRoot . "/imagenes/") === 0) {
        return ltrim(substr($raw, strlen($projectRoot) + 1), "/");
    }

    return presup_normalize_media_path($raw);
}

function presup_build_public_url(string $ruta): string
{
    $clean = presup_public_media_path($ruta);
    if ($clean === "") {
        return "";
    }
    if (stripos($clean, "http://") === 0 || stripos($clean, "https://") === 0) {
        return $clean;
    }
    if ($clean[0] === '/') {
        return "https://clminstal.es" . $clean;
    }
    return "https://clminstal.es/" . $clean;
}

function presup_resolve_absolute_path(string $storedPath): string
{
    $raw = trim(str_replace("\\", "/", $storedPath));
    if ($raw === "") {
        return "";
    }

    if ($raw[0] === '/') {
        $realAbsolute = realpath($raw);
        if ($realAbsolute !== false && is_file($realAbsolute)) {
            return $realAbsolute;
        }
    }

    $clean = presup_public_media_path($raw);
    if ($clean === "") {
        return "";
    }

    // Si viene como URL, usar su path para resolver el fichero local.
    if (stripos($clean, "http://") === 0 || stripos($clean, "https://") === 0) {
        $urlPath = parse_url($clean, PHP_URL_PATH);
        if (!is_string($urlPath) || trim($urlPath) === "") {
            return "";
        }
        $clean = ltrim((string)preg_replace('#/+#', '/', str_replace("\\", "/", $urlPath)), "/");
    }

    $imagesRoot = presup_resolve_images_root();
    $projectRoot = dirname($imagesRoot);

    $normalized = ltrim($clean, "/");
    $candidates = [];

    if (strpos($normalized, "imagenes/") === 0) {
        $candidates[] = $projectRoot . "/" . $normalized;
        $normalized = substr($normalized, strlen("imagenes/"));
    }

    $candidates[] = $imagesRoot . "/" . $normalized;
    $candidates[] = $projectRoot . "/" . $normalized;

    foreach ($candidates as $candidate) {
        if (is_file($candidate)) {
            return $candidate;
        }
    }

    // Último fallback razonable.
    return $candidates[0] ?? "";
}

function presup_media_dir_variants(string $tipo): array
{
    if (strtolower(trim($tipo)) === "pdf") {
        return [
            "presupuestosAdicionales",
            "PresupuestosAdicionales",
            // Compatibilidad con rutas antiguas.
            "presupuestosConforme",
            "PresupuestosConforme"
        ];
    }
    return [
        "firmasConforme",
        "FirmasConforme",
        "FirmasVonforme",
        "firmasvonforme"
    ];
}

function presup_resolve_media_path(string $storedPath, int $idPresupuesto, string $tipo): string
{
    $raw = trim((string)$storedPath);
    if ($raw === "" && $idPresupuesto <= 0) {
        return "";
    }

    $normalized = presup_normalize_media_path($raw);
    $isUrl = stripos($normalized, "http://") === 0 || stripos($normalized, "https://") === 0;
    $urlPath = "";
    if ($isUrl) {
        $parsed = parse_url($normalized, PHP_URL_PATH);
        if (is_string($parsed) && trim($parsed) !== "") {
            $urlPath = ltrim((string)preg_replace('#/+#', '/', str_replace("\\", "/", $parsed)), "/");
        }
    }

    $variants = presup_media_dir_variants($tipo);
    $candidates = [];

    $pushCandidate = static function (string $candidate) use (&$candidates): void {
        $candidate = ltrim((string)preg_replace('#/+#', '/', str_replace("\\", "/", trim($candidate))), "/");
        if ($candidate === "") {
            return;
        }
        $candidates[$candidate] = true;
    };

    if ($normalized !== "" && !$isUrl) {
        $pushCandidate($normalized);
    }
    if ($urlPath !== "") {
        $pushCandidate($urlPath);
    }

    $baseForVariants = $urlPath !== "" ? $urlPath : ($isUrl ? "" : $normalized);
    if ($baseForVariants !== "") {
        $parts = explode("/", ltrim($baseForVariants, "/"), 3);
        if (count($parts) >= 3 && strtolower($parts[0]) === "imagenes") {
            $rest = $parts[2];
            foreach ($variants as $dir) {
                $pushCandidate("imagenes/" . $dir . "/" . $rest);
            }
        } else {
            foreach ($variants as $dir) {
                if (strpos($baseForVariants, $dir . "/") === 0) {
                    $rest = substr($baseForVariants, strlen($dir) + 1);
                    $pushCandidate("imagenes/" . $dir . "/" . $rest);
                }
            }
        }
    }

    $fileName = "";
    if ($baseForVariants !== "") {
        $fileName = basename($baseForVariants);
    }
    if ($fileName !== "" && $fileName !== "." && $fileName !== "..") {
        foreach ($variants as $dir) {
            $pushCandidate("imagenes/" . $dir . "/" . $fileName);
        }
    }

    if ($idPresupuesto > 0) {
        $prefix = "Pedido-" . $idPresupuesto . "-";
        $imagesRoot = presup_resolve_images_root();
        foreach ($variants as $dir) {
            $dirAbs = $imagesRoot . "/" . $dir;
            if (!is_dir($dirAbs)) {
                continue;
            }
            $matches = glob($dirAbs . "/" . $prefix . "*");
            if (!is_array($matches) || empty($matches)) {
                continue;
            }
            usort($matches, static function (string $a, string $b): int {
                $ta = @filemtime($a);
                $tb = @filemtime($b);
                if ($ta === $tb) {
                    return strcmp($b, $a);
                }
                return ($tb <=> $ta);
            });
            foreach ($matches as $abs) {
                if (!is_file($abs)) {
                    continue;
                }
                $name = basename($abs);
                if (strtolower(trim($tipo)) === "pdf" && strtolower(pathinfo($name, PATHINFO_EXTENSION)) !== "pdf") {
                    continue;
                }
                $pushCandidate("imagenes/" . $dir . "/" . $name);
            }
        }
    }

    foreach (array_keys($candidates) as $candidate) {
        $abs = presup_resolve_absolute_path($candidate);
        if ($abs !== "" && is_file($abs)) {
            return $candidate;
        }
    }

    if ($isUrl) {
        return $normalized;
    }
    return $normalized;
}

function presup_save_signature_image_from_base64(string $firmaBase64, int $idPresupuesto): array
{
    $raw = $firmaBase64;
    if (strpos($raw, "base64,") !== false) {
        $parts = explode("base64,", $raw, 2);
        $raw = $parts[1];
    }
    // Evita errores de decode por espacios o saltos de línea en payload URL-encoded.
    $raw = str_replace(" ", "+", $raw);
    $raw = preg_replace('/\s+/', '', (string)$raw);

    $binary = base64_decode($raw, true);
    if ($binary === false || $binary === "") {
        throw new RuntimeException("La firma recibida no es valida");
    }

    $mime = "image/png";
    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $detected = $finfo->buffer($binary);
    if (is_string($detected) && $detected !== "") {
        $mime = strtolower($detected);
    }

    $ext = "png";
    $map = [
        "image/png" => "png",
        "image/jpeg" => "jpg",
        "image/jpg" => "jpg",
        "image/webp" => "webp"
    ];
    if (isset($map[$mime])) {
        $ext = $map[$mime];
    }

    $fileName = "Pedido-" . $idPresupuesto . "-" . date("YmdHis") . "." . $ext;
    $baseDir = presup_resolve_images_root() . "/firmasConforme";
    presup_ensure_dir($baseDir);

    $absolutePath = $baseDir . "/" . $fileName;
    if (file_put_contents($absolutePath, $binary) === false) {
        throw new RuntimeException("No se pudo guardar la firma del cliente");
    }

    return [
        "absolute_path" => $absolutePath,
        "relative_path" => "imagenes/firmasConforme/" . $fileName
    ];
}

function presup_save_budget_pdf(
    int $idPresupuesto,
    string $numeroPedido,
    string $nombreCliente,
    string $direccionCliente,
    string $telefono,
    string $emailCliente,
    string $usuarioInstalador,
    string $equipoInstaladores,
    array $lineas,
    array $totals,
    string $firmaRelativePath,
    array $firmaMeta = []
): array {
    $pdfBinary = presup_build_nota_cargo_pdf(
        $idPresupuesto,
        $numeroPedido,
        $nombreCliente,
        $direccionCliente,
        $telefono,
        $emailCliente,
        $usuarioInstalador,
        $equipoInstaladores,
        $lineas,
        $totals,
        $firmaRelativePath,
        $firmaMeta
    );
    $pdfFileName = "Pedido-" . $idPresupuesto . "-" . date("YmdHis") . ".pdf";
    $pdfDir = presup_resolve_images_root() . "/presupuestosAdicionales";
    presup_ensure_dir($pdfDir);

    $pdfAbsolutePath = $pdfDir . "/" . $pdfFileName;
    if (file_put_contents($pdfAbsolutePath, $pdfBinary) === false) {
        throw new RuntimeException("No se pudo generar el PDF del presupuesto");
    }

    return [
        "absolute_path" => $pdfAbsolutePath,
        "relative_path" => "imagenes/presupuestosAdicionales/" . $pdfFileName
    ];
}

function presup_build_nota_cargo_pdf(
    int $idPresupuesto,
    string $numeroPedido,
    string $nombreCliente,
    string $direccionCliente,
    string $telefono,
    string $emailCliente,
    string $usuarioInstalador,
    string $equipoInstaladores,
    array $lineas,
    array $totals,
    string $firmaRelativePath,
    array $firmaMeta = []
): string {
    $logoImage = presup_load_pdf_logo_image();
    $signatureImage = presup_load_pdf_signature_image($firmaRelativePath);
    $signatureResourceName = $signatureImage !== null ? (string)$signatureImage["name"] : "";

    $tableX = 42.0;
    $tableWidths = [55.0, 80.0, 230.0, 70.0, 76.0];
    $tableWidth = array_sum($tableWidths);
    $headerHeight = 24.0;
    $minRowHeight = 21.0;
    $rowLineHeight = 10.0;
    $rowVerticalPadding = 11.0;

    $rows = [];
    foreach ($lineas as $linea) {
        $cantidadLines = presup_pdf_prepare_table_cell_lines(
            presup_format_qty_pdf((float)($linea["cantidad"] ?? 0)),
            $tableWidths[0] - 8.0,
            9.0,
            "0"
        );
        $articuloLines = presup_pdf_prepare_table_cell_lines(
            (string)($linea["articulo"] ?? ""),
            $tableWidths[1] - 8.0,
            9.0,
            "-"
        );
        $descLines = presup_pdf_prepare_table_cell_lines(
            (string)($linea["descripcion"] ?? ""),
            $tableWidths[2] - 8.0,
            9.0,
            "Sin descripcion"
        );
        $unitLines = presup_pdf_prepare_table_cell_lines(
            presup_format_eur_pdf((float)($linea["precio_unitario_sin_iva"] ?? 0)),
            $tableWidths[3] - 8.0,
            9.0,
            "0,00 EUR"
        );
        $totalLines = presup_pdf_prepare_table_cell_lines(
            presup_format_eur_pdf((float)($linea["precio_total_linea"] ?? 0)),
            $tableWidths[4] - 8.0,
            9.0,
            "0,00 EUR"
        );

        $maxLineCount = max(
            count($cantidadLines),
            count($articuloLines),
            count($descLines),
            count($unitLines),
            count($totalLines)
        );
        $rowHeight = max($minRowHeight, ($maxLineCount * $rowLineHeight) + $rowVerticalPadding);
        $rows[] = [
            "cantidad_lineas" => $cantidadLines,
            "articulo_lineas" => $articuloLines,
            "descripcion_lineas" => $descLines,
            "precio_unitario_lineas" => $unitLines,
            "precio_total_linea_lineas" => $totalLines,
            "max_line_count" => $maxLineCount,
            "row_height" => $rowHeight
        ];
    }

    if (empty($rows)) {
        $rows[] = [
            "cantidad_lineas" => ["0"],
            "articulo_lineas" => ["-"],
            "descripcion_lineas" => ["Sin lineas"],
            "precio_unitario_lineas" => ["0,00 EUR"],
            "precio_total_linea_lineas" => ["0,00 EUR"],
            "max_line_count" => 1,
            "row_height" => $minRowHeight
        ];
    }

    $pages = [];
    $currentPage = "";
    $pageNo = 1;
    $continuacion = false;

    $y = presup_pdf_draw_nota_header(
        $currentPage,
        $idPresupuesto,
        $numeroPedido,
        $nombreCliente,
        $direccionCliente,
        $telefono,
        $emailCliente,
        $usuarioInstalador,
        $equipoInstaladores,
        $pageNo,
        $continuacion,
        $logoImage
    );
    $y = presup_pdf_draw_nota_table_header($currentPage, $tableX, $y, $tableWidths, $headerHeight);

    foreach ($rows as $row) {
        $rowHeight = (float)$row["row_height"];
        if ($y - $rowHeight < 130.0) {
            $pages[] = $currentPage;
            $currentPage = "";
            $pageNo++;
            $continuacion = true;

            $y = presup_pdf_draw_nota_header(
                $currentPage,
                $idPresupuesto,
                $numeroPedido,
                $nombreCliente,
                $direccionCliente,
                $telefono,
                $emailCliente,
                $usuarioInstalador,
                $equipoInstaladores,
                $pageNo,
                $continuacion,
                $logoImage
            );
            $y = presup_pdf_draw_nota_table_header($currentPage, $tableX, $y, $tableWidths, $headerHeight);
        }

        $y = presup_pdf_draw_nota_row($currentPage, $tableX, $y, $tableWidths, $row);
    }

    if ($y < 275.0) {
        $pages[] = $currentPage;
        $currentPage = "";
        $pageNo++;
        $continuacion = true;
        $y = presup_pdf_draw_nota_header(
            $currentPage,
            $idPresupuesto,
            $numeroPedido,
            $nombreCliente,
            $direccionCliente,
            $telefono,
            $emailCliente,
            $usuarioInstalador,
            $equipoInstaladores,
            $pageNo,
            $continuacion,
            $logoImage
        );
    }

    $summaryTop = $y - 18.0;
    $summaryX = $tableX + 20.0;
    $summaryCols = [145.0, 80.0, 120.0, 145.0];
    $summaryRowHeight = 20.0;

    $currentPage .= presup_pdf_rect_fill_stroke_cmd($summaryX, $summaryTop, array_sum($summaryCols), $summaryRowHeight, 0.93);
    $cursorX = $summaryX;
    for ($i = 0; $i < count($summaryCols) - 1; $i++) {
        $cursorX += $summaryCols[$i];
        $currentPage .= presup_pdf_line_cmd($cursorX, $summaryTop, $cursorX, $summaryTop - ($summaryRowHeight * 2.0));
    }
    $currentPage .= presup_pdf_rect_stroke_cmd($summaryX, $summaryTop - $summaryRowHeight, array_sum($summaryCols), $summaryRowHeight);

    $summaryHeaders = ["BASE IMPONIBLE", "IVA", "IMPORTE IVA", "TOTAL NOTA CARGO"];
    $cursorX = $summaryX;
    foreach ($summaryHeaders as $idx => $label) {
        $currentPage .= presup_pdf_text_cmd($cursorX + 4.0, $summaryTop - 13.0, $label, 9.0, true, "C", $summaryCols[$idx] - 8.0);
        $cursorX += $summaryCols[$idx];
    }

    $sinIva = (float)($totals["sin_iva"] ?? 0);
    $ivaAmt = (float)($totals["iva"] ?? 0);
    $conIva = (float)($totals["con_iva"] ?? 0);
    $ivaPct = $sinIva > 0.0 ? ($ivaAmt * 100.0 / $sinIva) : 0.0;
    $ivaPctLabel = rtrim(rtrim(number_format($ivaPct, 2, ",", "."), "0"), ",") . "%";

    $summaryValues = [
        presup_format_eur_pdf($sinIva),
        $ivaPctLabel,
        presup_format_eur_pdf($ivaAmt),
        presup_format_eur_pdf($conIva)
    ];
    $cursorX = $summaryX;
    foreach ($summaryValues as $idx => $value) {
        $currentPage .= presup_pdf_text_cmd($cursorX + 4.0, $summaryTop - 33.0, $value, 10.0, false, "C", $summaryCols[$idx] - 8.0);
        $cursorX += $summaryCols[$idx];
    }

    $sigTitleY = $summaryTop - 70.0;
    $currentPage .= presup_pdf_text_cmd(322.0, $sigTitleY, "Conforme Cliente", 10.0, true);
    $sigX = 322.0;
    $sigY = $sigTitleY - 10.0;
    $sigW = 220.0;
    $sigH = 88.0;
    $currentPage .= presup_pdf_rect_stroke_cmd($sigX, $sigY, $sigW, $sigH);

    if ($signatureResourceName !== "") {
        $pad = 4.0;
        $boxW = max(1.0, $sigW - ($pad * 2.0));
        $boxH = max(1.0, $sigH - ($pad * 2.0));
        $imgW = max(1.0, (float)($signatureImage["width"] ?? 1.0));
        $imgH = max(1.0, (float)($signatureImage["height"] ?? 1.0));
        $scale = min($boxW / $imgW, $boxH / $imgH);
        $drawW = $imgW * $scale;
        $drawH = $imgH * $scale;
        $drawX = $sigX + (($sigW - $drawW) / 2.0);
        $drawTopY = $sigY - (($sigH - $drawH) / 2.0);
        $currentPage .= presup_pdf_image_cmd($signatureResourceName, $drawX, $drawTopY, $drawW, $drawH);
    }

    // Trazabilidad de la firma: fecha/hora y ubicación (bajo la caja de firma).
    $fechaFirma = trim((string)($firmaMeta["fecha_hora"] ?? ""));
    if ($fechaFirma === "") {
        $fechaFirma = date("d-m-Y H:i:s");
    }
    $latFirma = trim((string)($firmaMeta["latitud"] ?? ""));
    $lngFirma = trim((string)($firmaMeta["longitud"] ?? ""));
    $metaY = $sigY - $sigH - 12.0;
    $currentPage .= presup_pdf_text_cmd($sigX, $metaY, "Firmado: " . $fechaFirma, 7.6);
    if ($latFirma !== "" && $lngFirma !== "") {
        $currentPage .= presup_pdf_text_cmd(
            $sigX,
            $metaY - 10.0,
            "Ubicación: lat " . $latFirma . ", long " . $lngFirma,
            7.6
        );
    }

    $currentPage .= presup_pdf_text_cmd(
        90.0,
        58.0,
        "Este documento no es una factura, la factura oficial se le enviará en breve por correo electrónico.",
        9.0
    );

    $pages[] = $currentPage;
    $images = [];
    if ($logoImage !== null) {
        $images[] = $logoImage;
    }
    if ($signatureImage !== null) {
        $images[] = $signatureImage;
    }
    return presup_build_pdf_document($pages, $images);
}

function presup_pdf_draw_nota_header(
    string &$content,
    int $idPresupuesto,
    string $numeroPedido,
    string $nombreCliente,
    string $direccionCliente,
    string $telefono,
    string $emailCliente,
    string $usuarioInstalador,
    string $equipoInstaladores,
    int $pageNo,
    bool $continuacion,
    ?array $logoImage = null
): float {
    $logoResourceName = preg_replace('/[^A-Za-z0-9_]/', '', (string)($logoImage["name"] ?? ""));
    $logoW = max(0.0, (float)($logoImage["width"] ?? 0.0));
    $logoH = max(0.0, (float)($logoImage["height"] ?? 0.0));
    if ($logoResourceName !== "" && $logoW > 0.0 && $logoH > 0.0) {
        // Ajusta el logo al contenedor sin deformarlo.
        $boxX = 80.0;
        $boxTop = 776.0;
        $boxW = 240.0;
        $boxH = 54.0;
        $scale = min($boxW / $logoW, $boxH / $logoH);
        $drawW = $logoW * $scale;
        $drawH = $logoH * $scale;
        $drawX = $boxX + (($boxW - $drawW) / 2.0);
        $drawTopY = $boxTop - (($boxH - $drawH) / 2.0);
        $content .= presup_pdf_image_cmd($logoResourceName, $drawX, $drawTopY, $drawW, $drawH);
    } else {
        $content .= presup_pdf_text_cmd(92.0, 804.0, "ClimaMania", 24.0, true);
    }

    $content .= presup_pdf_text_cmd(332.0, 780.0, "ClimaMania Sales Spain, S.L.", 10.0, true);
    $content .= presup_pdf_text_cmd(332.0, 768.0, "C/Honduras, 32-34 | 08027 Barcelona | Tel. 93 328 24 21", 7.0);
    $content .= presup_pdf_text_cmd(332.0, 758.0, "C/Electronica 14 (P.I. La Ferreria) | 08110 Montcada i Reixac", 7.0);
    $content .= presup_pdf_text_cmd(332.0, 748.0, "Avda. General Ricardos, 123 | 28019 Madrid | Tel. 91 821 63 15", 7.0);
    $content .= presup_pdf_text_cmd(332.0, 738.0, "C/Francisco de Llano, 9 | 46018 Valencia | Tel. 96 203 03 44", 7.0);

    $title = $continuacion ? "NOTA DE CARGO (Continuación)" : "NOTA DE CARGO";
    $content .= presup_pdf_text_cmd(92.0, 700.0, $title, 18.0, true);
    $pedidoVisible = presup_pdf_visible_pedido($numeroPedido);
    if ($pedidoVisible !== "") {
        $content .= presup_pdf_text_cmd(92.0, 676.0, "Pedido: " . $pedidoVisible, 14.0, true);
    }
    $content .= presup_pdf_text_cmd(92.0, 659.0, "Fecha: " . date("d/m/Y"), 10.0);
    $content .= presup_pdf_text_cmd(
        92.0,
        645.0,
        "Equipo: " . ($equipoInstaladores !== "" ? $equipoInstaladores : "N/D")
        . "   Página: " . $pageNo,
        9.0
    );

    if ($continuacion) {
        return 615.0;
    }

    $boxX = 320.0;
    $boxY = 708.0;
    $boxW = 230.0;
    $boxH = 74.0;
    $boxInnerW = $boxW - 18.0;
    $content .= presup_pdf_rect_stroke_cmd($boxX, $boxY, $boxW, $boxH);

    $nombre = presup_pdf_clean_for_document($nombreCliente);
    $direccion = presup_pdf_clean_for_document($direccionCliente);
    $tel = $telefono !== "" ? "Tel. " . presup_pdf_clean_for_document($telefono) : "";
    $mail = $emailCliente !== "" ? presup_pdf_clean_for_document($emailCliente) : "";

    $infoLines = [];
    foreach (presup_pdf_wrap_for_width($nombre, $boxInnerW, 9.0) as $line) {
        $infoLines[] = $line;
    }
    foreach (presup_pdf_wrap_for_width($direccion, $boxInnerW, 7.0) as $line) {
        $infoLines[] = $line;
    }
    if ($tel !== "") {
        foreach (presup_pdf_wrap_for_width($tel, $boxInnerW, 7.0) as $line) {
            $infoLines[] = $line;
        }
    }
    if ($mail !== "") {
        foreach (presup_pdf_wrap_for_width($mail, $boxInnerW, 7.0) as $line) {
            $infoLines[] = $line;
        }
    }

    $maxLines = max(1, (int)floor(($boxH - 10.0) / 9.0));
    if (count($infoLines) > $maxLines) {
        $infoLines = array_slice($infoLines, 0, $maxLines);
        $lastIdx = count($infoLines) - 1;
        if ($lastIdx >= 0) {
            $infoLines[$lastIdx] = rtrim($infoLines[$lastIdx], " .,;:") . "...";
        }
    }

    $textY = $boxY - 13.0;
    foreach ($infoLines as $line) {
        if ($textY < ($boxY - $boxH + 8.0)) {
            break;
        }
        $size = $textY > ($boxY - 26.0) ? 9.0 : 7.0;
        $content .= presup_pdf_text_cmd($boxX + 5.0, $textY, $line, $size, $size >= 9.0);
        $textY -= ($size >= 9.0 ? 10.0 : 8.0);
    }

    $content .= presup_pdf_text_cmd(
        92.0,
        613.0,
        "A continuación detallamos los adicionales correspondientes a la ejecución de su instalación:",
        10.0
    );

    return 595.0;
}

function presup_pdf_draw_nota_table_header(
    string &$content,
    float $tableX,
    float $y,
    array $widths,
    float $headerHeight
): float {
    $tableWidth = array_sum($widths);
    $content .= presup_pdf_rect_fill_stroke_cmd($tableX, $y, $tableWidth, $headerHeight, 0.93);

    $cursorX = $tableX;
    for ($i = 0; $i < count($widths) - 1; $i++) {
        $cursorX += (float)$widths[$i];
        $content .= presup_pdf_line_cmd($cursorX, $y, $cursorX, $y - $headerHeight);
    }

    $content .= presup_pdf_text_cmd($tableX + 4.0, $y - 15.0, "Cantidad", 9.0, true, "C", $widths[0] - 8.0);
    $content .= presup_pdf_text_cmd($tableX + $widths[0] + 4.0, $y - 15.0, "Código", 9.0, true, "C", $widths[1] - 8.0);
    $content .= presup_pdf_text_cmd($tableX + $widths[0] + $widths[1] + 4.0, $y - 15.0, "Descripción", 9.0, true, "C", $widths[2] - 8.0);
    $content .= presup_pdf_text_cmd($tableX + $widths[0] + $widths[1] + $widths[2] + 4.0, $y - 11.0, "Neto ud", 9.0, true, "C", $widths[3] - 8.0);
    $content .= presup_pdf_text_cmd($tableX + $widths[0] + $widths[1] + $widths[2] + 4.0, $y - 20.0, "(Sin IVA)", 8.0, true, "C", $widths[3] - 8.0);
    $content .= presup_pdf_text_cmd($tableX + $widths[0] + $widths[1] + $widths[2] + $widths[3] + 4.0, $y - 11.0, "Neto Total", 9.0, true, "C", $widths[4] - 8.0);
    $content .= presup_pdf_text_cmd($tableX + $widths[0] + $widths[1] + $widths[2] + $widths[3] + 4.0, $y - 20.0, "(Sin IVA)", 8.0, true, "C", $widths[4] - 8.0);

    return $y - $headerHeight;
}

function presup_pdf_draw_nota_row(
    string &$content,
    float $tableX,
    float $y,
    array $widths,
    array $row
): float {
    $rowHeight = (float)($row["row_height"] ?? 21.0);
    $tableWidth = array_sum($widths);
    $content .= presup_pdf_rect_stroke_cmd($tableX, $y, $tableWidth, $rowHeight);

    $cursorX = $tableX;
    for ($i = 0; $i < count($widths) - 1; $i++) {
        $cursorX += (float)$widths[$i];
        $content .= presup_pdf_line_cmd($cursorX, $y, $cursorX, $y - $rowHeight);
    }

    presup_pdf_draw_table_cell_lines(
        $content,
        $tableX + 4.0,
        $y,
        $rowHeight,
        $widths[0] - 8.0,
        $row["cantidad_lineas"] ?? ["0"],
        9.0,
        "C"
    );
    presup_pdf_draw_table_cell_lines(
        $content,
        $tableX + $widths[0] + 4.0,
        $y,
        $rowHeight,
        $widths[1] - 8.0,
        $row["articulo_lineas"] ?? ["-"],
        9.0,
        "L"
    );
    presup_pdf_draw_table_cell_lines(
        $content,
        $tableX + $widths[0] + $widths[1] + 4.0,
        $y,
        $rowHeight,
        $widths[2] - 8.0,
        $row["descripcion_lineas"] ?? ["-"],
        9.0,
        "L"
    );
    presup_pdf_draw_table_cell_lines(
        $content,
        $tableX + $widths[0] + $widths[1] + $widths[2] + 4.0,
        $y,
        $rowHeight,
        $widths[3] - 8.0,
        $row["precio_unitario_lineas"] ?? ["0,00 EUR"],
        9.0,
        "R"
    );
    presup_pdf_draw_table_cell_lines(
        $content,
        $tableX + $widths[0] + $widths[1] + $widths[2] + $widths[3] + 4.0,
        $y,
        $rowHeight,
        $widths[4] - 8.0,
        $row["precio_total_linea_lineas"] ?? ["0,00 EUR"],
        9.0,
        "R"
    );

    return $y - $rowHeight;
}

function presup_build_pdf_document(array $pages, array $images = []): string
{
    $pageWidth = 595;
    $pageHeight = 842;
    if (empty($pages)) {
        $pages = [""];
    }

    $pageCount = count($pages);
    $objects = [];
    $objects[1] = "<< /Type /Catalog /Pages 2 0 R >>";

    $kids = [];
    for ($i = 0; $i < $pageCount; $i++) {
        $pageObj = 3 + ($i * 2);
        $kids[] = $pageObj . " 0 R";
    }
    $objects[2] = "<< /Type /Pages /Count " . $pageCount . " /Kids [" . implode(" ", $kids) . "] >>";

    $font1Obj = 3 + ($pageCount * 2);
    $font2Obj = $font1Obj + 1;
    $imageObjMap = [];
    $nextObj = $font2Obj + 1;
    foreach ($images as $img) {
        if (!is_array($img)) {
            continue;
        }
        $nameRaw = (string)($img["name"] ?? "");
        $name = preg_replace('/[^A-Za-z0-9_]/', '', $nameRaw);
        $binary = $img["binary"] ?? null;
        if ($name === "" || !is_string($binary) || $binary === "") {
            continue;
        }
        $imageObjMap[$name] = [
            "obj" => $nextObj,
            "image" => $img
        ];
        $nextObj++;
    }

    for ($i = 0; $i < $pageCount; $i++) {
        $pageObj = 3 + ($i * 2);
        $contentObj = $pageObj + 1;
        $stream = (string)$pages[$i];

        $xObjResources = "";
        if (!empty($imageObjMap)) {
            $pairs = [];
            foreach ($imageObjMap as $name => $meta) {
                $pairs[] = "/" . $name . " " . (int)$meta["obj"] . " 0 R";
            }
            $xObjResources = " /XObject << " . implode(" ", $pairs) . " >>";
        }

        $objects[$pageObj] = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 "
            . $pageWidth . " " . $pageHeight . "] "
            . "/Resources << /Font << /F1 " . $font1Obj . " 0 R /F2 " . $font2Obj . " 0 R >>"
            . $xObjResources . " >> "
            . "/Contents " . $contentObj . " 0 R >>";

        $objects[$contentObj] = "<< /Length " . strlen($stream) . " >>\nstream\n"
            . $stream . "endstream";
    }

    $objects[$font1Obj] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>";
    $objects[$font2Obj] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>";

    foreach ($imageObjMap as $meta) {
        $objId = (int)$meta["obj"];
        $img = $meta["image"];
        $binary = (string)$img["binary"];
        $width = max(1, (int)($img["width"] ?? 1));
        $height = max(1, (int)($img["height"] ?? 1));
        $bits = max(1, (int)($img["bits"] ?? 8));
        $colorSpace = (string)($img["color_space"] ?? "DeviceRGB");
        $filter = (string)($img["filter"] ?? "DCTDecode");
        $decode = isset($img["decode"]) && is_string($img["decode"]) && trim($img["decode"]) !== ""
            ? " /Decode " . trim($img["decode"])
            : "";

        $objects[$objId] = "<< /Type /XObject /Subtype /Image"
            . " /Width " . $width
            . " /Height " . $height
            . " /ColorSpace /" . $colorSpace
            . " /BitsPerComponent " . $bits
            . $decode
            . " /Filter /" . $filter
            . " /Length " . strlen($binary) . " >>\nstream\n"
            . $binary . "\nendstream";
    }

    $maxObj = $font2Obj + count($imageObjMap);
    $pdf = "%PDF-1.4\n";
    $offsets = [];
    $offsets[0] = 0;

    for ($i = 1; $i <= $maxObj; $i++) {
        $offsets[$i] = strlen($pdf);
        $pdf .= $i . " 0 obj\n" . $objects[$i] . "\nendobj\n";
    }

    $xrefOffset = strlen($pdf);
    $pdf .= "xref\n0 " . ($maxObj + 1) . "\n";
    $pdf .= "0000000000 65535 f \n";
    for ($i = 1; $i <= $maxObj; $i++) {
        $pdf .= sprintf("%010d 00000 n \n", $offsets[$i]);
    }
    $pdf .= "trailer\n<< /Size " . ($maxObj + 1) . " /Root 1 0 R >>\n";
    $pdf .= "startxref\n" . $xrefOffset . "\n%%EOF";

    return $pdf;
}

function presup_pdf_text_cmd(
    float $x,
    float $y,
    string $text,
    float $size = 10.0,
    bool $bold = false,
    string $align = "L",
    float $width = 0.0
): string
{
    $clean = trim((string)$text);
    if ($clean === "") {
        return "";
    }
    $font = $bold ? "F2" : "F1";

    $drawX = $x;
    if ($width > 0.0) {
        $estimated = presup_pdf_estimate_text_width($clean, $size);
        $align = strtoupper(trim($align));
        if ($align === "R") {
            $drawX = $x + max(0.0, $width - $estimated);
        } elseif ($align === "C") {
            $drawX = $x + max(0.0, ($width - $estimated) / 2.0);
        }
    }

    return "BT /" . $font . " " . presup_pdf_num($size) . " Tf 1 0 0 1 "
        . presup_pdf_num($drawX) . " " . presup_pdf_num($y)
        . " Tm (" . presup_pdf_escape_text($clean) . ") Tj ET\n";
}

function presup_pdf_rect_stroke_cmd(float $x, float $topY, float $width, float $height): string
{
    return presup_pdf_num($x) . " " . presup_pdf_num($topY - $height) . " "
        . presup_pdf_num($width) . " " . presup_pdf_num($height) . " re S\n";
}

function presup_pdf_rect_fill_stroke_cmd(
    float $x,
    float $topY,
    float $width,
    float $height,
    float $gray
): string
{
    return presup_pdf_num($gray) . " g " . presup_pdf_num($gray) . " G "
        . presup_pdf_num($x) . " " . presup_pdf_num($topY - $height) . " "
        . presup_pdf_num($width) . " " . presup_pdf_num($height) . " re B\n"
        . "0 g 0 G\n";
}

function presup_pdf_line_cmd(float $x1, float $y1, float $x2, float $y2): string
{
    return presup_pdf_num($x1) . " " . presup_pdf_num($y1) . " m "
        . presup_pdf_num($x2) . " " . presup_pdf_num($y2) . " l S\n";
}

function presup_pdf_image_cmd(
    string $resourceName,
    float $x,
    float $topY,
    float $width,
    float $height
): string {
    $name = preg_replace('/[^A-Za-z0-9_]/', '', trim($resourceName));
    if ($name === "" || $width <= 0 || $height <= 0) {
        return "";
    }
    return "q "
        . presup_pdf_num($width) . " 0 0 " . presup_pdf_num($height) . " "
        . presup_pdf_num($x) . " " . presup_pdf_num($topY - $height)
        . " cm /" . $name . " Do Q\n";
}

function presup_pdf_num(float $value): string
{
    $formatted = number_format($value, 2, ".", "");
    $formatted = rtrim(rtrim($formatted, "0"), ".");
    return $formatted === "" ? "0" : $formatted;
}

function presup_pdf_wrap_for_width(string $text, float $maxWidth, float $fontSize): array
{
    $clean = presup_pdf_clean_for_document($text);
    if ($clean === "") {
        return [];
    }
    $maxChars = (int)floor($maxWidth / max(3.0, $fontSize * 0.52));
    if ($maxChars < 4) {
        $maxChars = 4;
    }
    return presup_wrap_text($clean, $maxChars);
}

function presup_pdf_prepare_table_cell_lines(
    string $text,
    float $maxWidth,
    float $fontSize,
    string $fallback = "-"
): array {
    $clean = presup_pdf_clean_for_document($text);
    if ($clean === "") {
        $clean = presup_pdf_clean_for_document($fallback);
    }
    if ($clean === "") {
        return ["-"];
    }

    $lines = presup_pdf_wrap_for_width($clean, $maxWidth, $fontSize);
    if (empty($lines)) {
        return [$clean];
    }
    return $lines;
}

function presup_pdf_draw_table_cell_lines(
    string &$content,
    float $x,
    float $rowTopY,
    float $rowHeight,
    float $width,
    array $lines,
    float $fontSize,
    string $align = "L"
): void {
    if (empty($lines)) {
        return;
    }

    $lineHeight = 10.0;
    $middleY = $rowTopY - ($rowHeight / 2.0) - 2.0;
    $firstBaselineY = $middleY + (((count($lines) - 1) * $lineHeight) / 2.0);

    foreach (array_values($lines) as $idx => $line) {
        $content .= presup_pdf_text_cmd(
            $x,
            $firstBaselineY - ($idx * $lineHeight),
            (string)$line,
            $fontSize,
            false,
            $align,
            $width
        );
    }
}

function presup_pdf_estimate_text_width(string $text, float $fontSize): float
{
    $chars = mb_strlen($text, "UTF-8");
    return $chars * ($fontSize * 0.50);
}

function presup_pdf_clean_for_document(string $value): string
{
    $clean = str_replace(["\r", "\n"], " ", (string)$value);
    $clean = preg_replace('/<br\s*\/?>/i', ', ', $clean);
    $clean = strip_tags($clean);
    $clean = preg_replace('/\s+/', ' ', (string)$clean);
    return trim((string)$clean);
}

function presup_wrap_text(string $text, int $maxChars): array
{
    $text = trim($text);
    if ($text === "") {
        return [""];
    }

    $words = preg_split('/\s+/', $text);
    $lines = [];
    $current = "";

    foreach ($words as $word) {
        if ($current === "") {
            if (mb_strlen($word, "UTF-8") <= $maxChars) {
                $current = $word;
            } else {
                $chunks = presup_split_multibyte_word($word, $maxChars);
                foreach ($chunks as $chunk) {
                    if ($chunk !== "") {
                        $lines[] = $chunk;
                    }
                }
                $current = "";
            }
            continue;
        }

        $candidate = $current . " " . $word;
        if (mb_strlen($candidate, "UTF-8") <= $maxChars) {
            $current = $candidate;
            continue;
        }

        $lines[] = $current;
        if (mb_strlen($word, "UTF-8") <= $maxChars) {
            $current = $word;
        } else {
            $chunks = presup_split_multibyte_word($word, $maxChars);
            foreach ($chunks as $chunk) {
                if ($chunk !== "") {
                    $lines[] = $chunk;
                }
            }
            $current = "";
        }
    }

    if ($current !== "") {
        $lines[] = $current;
    }

    return $lines;
}

function presup_pdf_escape_text(string $text): string
{
    $converted = iconv("UTF-8", "windows-1252//IGNORE", $text);
    if ($converted === false) {
        $converted = preg_replace('/[^\x20-\x7E]/', '', $text);
    }
    $converted = str_replace("\\", "\\\\", $converted);
    $converted = str_replace("(", "\\(", $converted);
    $converted = str_replace(")", "\\)", $converted);
    return $converted;
}

function presup_pdf_visible_pedido(string $numeroPedido): string
{
    $pedido = trim((string)$numeroPedido);
    if ($pedido === "") {
        return "";
    }
    if (stripos($pedido, "MANUAL-") === 0) {
        return "";
    }
    return $pedido;
}

function presup_load_pdf_logo_image(): ?array
{
    static $loaded = false;
    static $cached = null;
    if ($loaded) {
        return $cached;
    }
    $loaded = true;

    // Probar primero las URLs oficiales del logo; si no son válidas, caer a copias locales.
    $logoUrls = [
        "https://clminstal.es/img/LogoCLM.png",
        "https://clminstal.es/img/LogoCLMcom.jpg"
    ];

    $localCandidates = [
        __DIR__ . "/LogoCLM.png",
        __DIR__ . "/LogoCLMcom.jpg"
    ];

    $imagesRoot = presup_resolve_images_root();
    if ($imagesRoot !== "") {
        $localCandidates[] = rtrim($imagesRoot, "/") . "/LogoCLM.png";
        $localCandidates[] = rtrim($imagesRoot, "/") . "/LogoCLMcom.jpg";
    }

    foreach ($logoUrls as $logoUrl) {
        $download = presup_fetch_remote_binary($logoUrl);
        if (!is_string($download) || $download === "") {
            continue;
        }
        $image = presup_build_pdf_image_from_binary($download, "IMLOGO");
        if ($image === null) {
            continue;
        }
        if ($imagesRoot !== "" && is_dir($imagesRoot) && is_writable($imagesRoot)) {
            $target = rtrim($imagesRoot, "/") . "/" . basename(parse_url($logoUrl, PHP_URL_PATH) ?: "LogoCLM.png");
            @file_put_contents($target, $download);
        }
        $cached = $image;
        return $cached;
    }

    foreach ($localCandidates as $candidate) {
        if (!is_file($candidate) || !is_readable($candidate)) {
            continue;
        }
        $raw = @file_get_contents($candidate);
        if (!is_string($raw) || $raw === "") {
            continue;
        }
        $image = presup_build_pdf_image_from_binary($raw, "IMLOGO");
        if ($image !== null) {
            $cached = $image;
            return $cached;
        }
    }

    $cached = null;
    return $cached;
}

function presup_fetch_remote_binary(string $url): string
{
    if ($url === "") {
        return "";
    }

    $ctx = stream_context_create([
        "http" => ["timeout" => 5],
        "ssl" => ["verify_peer" => true, "verify_peer_name" => true]
    ]);
    $download = @file_get_contents($url, false, $ctx);

    if ((!is_string($download) || $download === "") && stripos($url, "https://") === 0) {
        $ctxInsecure = stream_context_create([
            "http" => ["timeout" => 5],
            "ssl" => ["verify_peer" => false, "verify_peer_name" => false]
        ]);
        $download = @file_get_contents($url, false, $ctxInsecure);
    }

    if ((!is_string($download) || $download === "") && function_exists("curl_init")) {
        $ch = curl_init($url);
        if ($ch !== false) {
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
            curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 5);
            curl_setopt($ch, CURLOPT_TIMEOUT, 8);
            curl_setopt($ch, CURLOPT_USERAGENT, "Mozilla/5.0 (compatible; ClimaMania-PDF/1.0)");
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
            $curlData = curl_exec($ch);
            curl_close($ch);
            if (is_string($curlData) && $curlData !== "") {
                $download = $curlData;
            }
        }
    }

    if (!is_string($download)) {
        return "";
    }
    return $download;
}

function presup_load_pdf_signature_image(string $firmaRelativePath): ?array
{
    $path = presup_resolve_absolute_path($firmaRelativePath);
    if ($path === "" || !is_file($path) || !is_readable($path)) {
        return null;
    }
    $binary = @file_get_contents($path);
    if (!is_string($binary) || $binary === "") {
        return null;
    }
    return presup_build_pdf_image_from_binary($binary, "IMSIGN");
}

function presup_build_pdf_image_from_binary(string $binary, string $name): ?array
{
    $imgName = preg_replace('/[^A-Za-z0-9_]/', '', $name);
    if ($imgName === "") {
        return null;
    }

    $info = @getimagesizefromstring($binary);
    if (!is_array($info) || !isset($info[0], $info[1])) {
        // Formato no reconocido por getimagesize: intenta con GD.
        return presup_gd_image_to_jpeg_dict($binary, $imgName);
    }

    $mime = strtolower((string)($info["mime"] ?? ""));

    if ($mime === "image/jpeg" || $mime === "image/jpg") {
        $channels = (int)($info["channels"] ?? 3);
        $colorSpace = $channels === 4 ? "DeviceCMYK" : ($channels === 1 ? "DeviceGray" : "DeviceRGB");
        $decode = null;
        if ($colorSpace === "DeviceCMYK") {
            // Corrige colores en JPG CMYK/YCCK típicos de impresión.
            $decode = "[1 0 1 0 1 0 1 0]";
        }
        return [
            "name" => $imgName,
            "binary" => $binary,
            "width" => (int)$info[0],
            "height" => (int)$info[1],
            "bits" => 8,
            "color_space" => $colorSpace,
            "filter" => "DCTDecode",
            "decode" => $decode
        ];
    }

    if ($mime === "image/png") {
        $pngData = presup_png_to_rgb_flate($binary);
        if ($pngData === null) {
            // El parser propio no soporta este PNG (p. ej. el que genera Skia/
            // Flutter): fallback robusto con GD.
            return presup_gd_image_to_jpeg_dict($binary, $imgName);
        }
        return [
            "name" => $imgName,
            "binary" => $pngData["binary"],
            "width" => (int)$pngData["width"],
            "height" => (int)$pngData["height"],
            "bits" => 8,
            "color_space" => "DeviceRGB",
            "filter" => "FlateDecode"
        ];
    }

    // Otros formatos (webp, gif…): intenta con GD.
    return presup_gd_image_to_jpeg_dict($binary, $imgName);
}

/// Decodifica una imagen con GD, la aplana sobre blanco y la devuelve como JPEG
/// listo para incrustar en el PDF (DCTDecode). Sirve de fallback cuando el
/// parser PNG propio no soporta el formato de entrada.
function presup_gd_image_to_jpeg_dict(string $binary, string $imgName): ?array
{
    if (!function_exists("imagecreatefromstring")) {
        return null;
    }
    $src = @imagecreatefromstring($binary);
    if ($src === false) {
        return null;
    }
    $w = imagesx($src);
    $h = imagesy($src);
    if ($w <= 0 || $h <= 0) {
        imagedestroy($src);
        return null;
    }
    $canvas = imagecreatetruecolor($w, $h);
    imagealphablending($canvas, true);
    $white = imagecolorallocate($canvas, 255, 255, 255);
    imagefilledrectangle($canvas, 0, 0, $w, $h, $white);
    imagecopy($canvas, $src, 0, 0, 0, 0, $w, $h);

    ob_start();
    $ok = imagejpeg($canvas, null, 92);
    $jpeg = ob_get_clean();

    // @ para no ensuciar el JSON con el deprecation de imagedestroy en PHP 8.5+.
    @imagedestroy($src);
    @imagedestroy($canvas);

    if (!$ok || !is_string($jpeg) || $jpeg === "") {
        return null;
    }
    return [
        "name" => $imgName,
        "binary" => $jpeg,
        "width" => $w,
        "height" => $h,
        "bits" => 8,
        "color_space" => "DeviceRGB",
        "filter" => "DCTDecode",
        "decode" => null
    ];
}

function presup_png_to_rgb_flate(string $binary): ?array
{
    if (strlen($binary) < 33 || substr($binary, 0, 8) !== "\x89PNG\x0D\x0A\x1A\x0A") {
        return null;
    }

    $offset = 8;
    $width = 0;
    $height = 0;
    $bitDepth = 0;
    $colorType = 0;
    $idat = "";

    while ($offset + 8 <= strlen($binary)) {
        $lenArr = unpack("Nlen", substr($binary, $offset, 4));
        if (!is_array($lenArr)) {
            return null;
        }
        $length = (int)$lenArr["len"];
        $type = substr($binary, $offset + 4, 4);
        $dataStart = $offset + 8;
        $dataEnd = $dataStart + $length;
        if ($dataEnd + 4 > strlen($binary)) {
            return null;
        }
        $chunk = substr($binary, $dataStart, $length);

        if ($type === "IHDR") {
            if ($length < 13) {
                return null;
            }
            $ihdr = unpack("Nw/Nh/Cbit/Ccolor/Ccompression/Cfilter/Cinterlace", substr($chunk, 0, 13));
            if (!is_array($ihdr)) {
                return null;
            }
            $width = (int)$ihdr["w"];
            $height = (int)$ihdr["h"];
            $bitDepth = (int)$ihdr["bit"];
            $colorType = (int)$ihdr["color"];
            $compression = (int)$ihdr["compression"];
            $filterMethod = (int)$ihdr["filter"];
            $interlace = (int)$ihdr["interlace"];
            if ($width <= 0 || $height <= 0 || $bitDepth !== 8 || $compression !== 0 || $filterMethod !== 0 || $interlace !== 0) {
                return null;
            }
        } elseif ($type === "IDAT") {
            $idat .= $chunk;
        } elseif ($type === "IEND") {
            break;
        }

        $offset = $dataEnd + 4;
    }

    if ($width <= 0 || $height <= 0 || $idat === "") {
        return null;
    }

    $decoded = @gzuncompress($idat);
    if (!is_string($decoded) || $decoded === "") {
        if (function_exists("zlib_decode")) {
            $decoded = @zlib_decode($idat);
        }
    }
    if (!is_string($decoded) || $decoded === "") {
        return null;
    }

    $bytesPerPixelMap = [
        0 => 1, // grayscale
        2 => 3, // RGB
        4 => 2, // grayscale + alpha
        6 => 4  // RGBA
    ];
    if (!isset($bytesPerPixelMap[$colorType])) {
        return null;
    }
    $bpp = $bytesPerPixelMap[$colorType];
    $rowLen = $width * $bpp;
    $scanlineLen = $rowLen + 1;
    if (strlen($decoded) < ($scanlineLen * $height)) {
        return null;
    }

    $prevRow = str_repeat("\0", $rowLen);
    $rgb = "";
    $pos = 0;
    for ($y = 0; $y < $height; $y++) {
        $filter = ord($decoded[$pos]);
        $row = substr($decoded, $pos + 1, $rowLen);
        if (strlen($row) !== $rowLen) {
            return null;
        }
        $unfiltered = presup_png_unfilter_row($row, $prevRow, $filter, $bpp);
        if ($unfiltered === null) {
            return null;
        }

        if ($colorType === 2) {
            $rgb .= $unfiltered;
        } elseif ($colorType === 6) {
            for ($i = 0; $i < $rowLen; $i += 4) {
                $r = ord($unfiltered[$i]);
                $g = ord($unfiltered[$i + 1]);
                $b = ord($unfiltered[$i + 2]);
                $a = ord($unfiltered[$i + 3]); // 0 = transparente, 255 = opaco
                $invA = 255 - $a;
                $rOut = (int)round((($r * $a) + (255 * $invA)) / 255);
                $gOut = (int)round((($g * $a) + (255 * $invA)) / 255);
                $bOut = (int)round((($b * $a) + (255 * $invA)) / 255);
                $rgb .= chr($rOut) . chr($gOut) . chr($bOut);
            }
        } elseif ($colorType === 0) {
            for ($i = 0; $i < $rowLen; $i++) {
                $g = $unfiltered[$i];
                $rgb .= $g . $g . $g;
            }
        } else { // colorType 4
            for ($i = 0; $i < $rowLen; $i += 2) {
                $g = ord($unfiltered[$i]);
                $a = ord($unfiltered[$i + 1]);
                $invA = 255 - $a;
                $gOut = (int)round((($g * $a) + (255 * $invA)) / 255);
                $gray = chr($gOut);
                $rgb .= $gray . $gray . $gray;
            }
        }

        $prevRow = $unfiltered;
        $pos += $scanlineLen;
    }

    $compressed = gzcompress($rgb, 9);
    if (!is_string($compressed) || $compressed === "") {
        return null;
    }

    return [
        "binary" => $compressed,
        "width" => $width,
        "height" => $height
    ];
}

function presup_png_unfilter_row(string $row, string $prevRow, int $filter, int $bpp): ?string
{
    $len = strlen($row);
    $out = "";

    for ($i = 0; $i < $len; $i++) {
        $raw = ord($row[$i]);
        $left = $i >= $bpp ? ord($out[$i - $bpp]) : 0;
        $up = ord($prevRow[$i] ?? "\0");
        $upLeft = $i >= $bpp ? ord($prevRow[$i - $bpp] ?? "\0") : 0;

        if ($filter === 0) {
            $val = $raw;
        } elseif ($filter === 1) {
            $val = ($raw + $left) & 0xFF;
        } elseif ($filter === 2) {
            $val = ($raw + $up) & 0xFF;
        } elseif ($filter === 3) {
            $val = ($raw + intdiv($left + $up, 2)) & 0xFF;
        } elseif ($filter === 4) {
            $val = ($raw + presup_png_paeth_predictor($left, $up, $upLeft)) & 0xFF;
        } else {
            return null;
        }
        $out .= chr($val);
    }

    return $out;
}

function presup_png_paeth_predictor(int $a, int $b, int $c): int
{
    $p = $a + $b - $c;
    $pa = abs($p - $a);
    $pb = abs($p - $b);
    $pc = abs($p - $c);
    if ($pa <= $pb && $pa <= $pc) {
        return $a;
    }
    if ($pb <= $pc) {
        return $b;
    }
    return $c;
}

function presup_split_multibyte_word(string $word, int $chunkLength): array
{
    $chunks = [];
    $len = mb_strlen($word, "UTF-8");
    if ($chunkLength <= 0) {
        $chunkLength = 1;
    }
    for ($i = 0; $i < $len; $i += $chunkLength) {
        $chunks[] = mb_substr($word, $i, $chunkLength, "UTF-8");
    }
    return $chunks;
}

function presup_format_qty_pdf(float $amount): string
{
    if (abs($amount - round($amount)) < 0.0001) {
        return (string)intval(round($amount));
    }
    return rtrim(rtrim(number_format($amount, 2, ",", "."), "0"), ",");
}

function presup_format_eur_pdf(float $amount): string
{
    return number_format($amount, 2, ",", ".") . " €";
}

function presup_format_eur(float $amount): string
{
    return number_format($amount, 2, ",", ".") . " EUR";
}

function presup_parse_email_values(string $raw): array
{
    $normalized = str_replace(["\r", "\n"], ";", (string)$raw);
    $chunks = preg_split('/[;,]+/', $normalized);
    if (!is_array($chunks)) {
        return [];
    }

    $emails = [];
    foreach ($chunks as $chunk) {
        $mail = presup_normalize_email((string)$chunk);
        if ($mail !== "") {
            $emails[$mail] = true;
        }
    }
    return array_keys($emails);
}

function presup_fetch_bcc_destinations(PDO $pdo): array
{
    $ordered = ["emailCompras", "emailGenerico", "emailFacturacion"];
    $stmt = $pdo->query(
        "SELECT nombreVariable, valorVariable
         FROM variables_generales
         WHERE nombreVariable IN ('emailFacturacion', 'emailCompras', 'emailGenerico')"
    );

    $map = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $name = trim((string)($row["nombreVariable"] ?? ""));
        $value = (string)($row["valorVariable"] ?? "");
        if ($name !== "" && $value !== "") {
            $map[$name] = $value;
        }
    }

    $emails = [];
    foreach ($ordered as $name) {
        if (!isset($map[$name])) {
            continue;
        }
        foreach (presup_parse_email_values((string)$map[$name]) as $mail) {
            $emails[$mail] = true;
        }
    }
    return array_keys($emails);
}

/// Formatea la dirección para el correo en dos líneas: la calle en la primera
/// y "código postal - población" en la segunda. Devuelve HTML seguro (<br>).
function presup_email_direccion_html(string $direccionCliente): string
{
    $clean = presup_clean_text_for_mail($direccionCliente); // una línea, "calle, CP Ciudad"
    if ($clean === "") {
        return "";
    }
    $safe = static function (string $s): string {
        return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
    };

    $pos = mb_strrpos($clean, ", ", 0, "UTF-8");
    if ($pos === false) {
        return $safe($clean);
    }
    $calle = trim(mb_substr($clean, 0, $pos, "UTF-8"));
    $cpPoblacion = trim(mb_substr($clean, $pos + 2, null, "UTF-8"));

    // "CP Población" -> "CP - Población".
    $sp = mb_strpos($cpPoblacion, " ", 0, "UTF-8");
    if ($sp !== false) {
        $cp = trim(mb_substr($cpPoblacion, 0, $sp, "UTF-8"));
        $poblacion = trim(mb_substr($cpPoblacion, $sp + 1, null, "UTF-8"));
        if ($poblacion !== "") {
            $cpPoblacion = $cp . " - " . $poblacion;
        }
    }

    if ($calle === "") {
        return $safe($cpPoblacion);
    }
    return $safe($calle) . "<br>" . $safe($cpPoblacion);
}

function presup_build_email_body(
    int $idPresupuesto,
    string $numeroPedido,
    string $nombreCliente,
    string $direccionCliente,
    array $totals,
    array $lineas = []
): string {
    $pedido = htmlspecialchars(presup_normalize_text($numeroPedido, 120), ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
    $cliente = htmlspecialchars(presup_normalize_text($nombreCliente, 255), ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
    // Dirección en dos líneas: "Calle ...\nCP - Población".
    $direccion = presup_email_direccion_html($direccionCliente);

    $rows = "";
    foreach ($lineas as $linea) {
        $cantidad = presup_format_decimal((float)($linea["cantidad"] ?? 0), 2);
        $articulo = htmlspecialchars((string)($linea["articulo"] ?? ""), ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
        $descripcion = htmlspecialchars((string)($linea["descripcion"] ?? ""), ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
        $pUnit = presup_format_eur((float)($linea["precio_unitario_sin_iva"] ?? 0));
        $pTotal = presup_format_eur((float)($linea["precio_total_linea"] ?? 0));

        $rows .= "<tr>"
            . "<td style=\"border:1px solid #444;padding:6px;text-align:center;\">" . $cantidad . "</td>"
            . "<td style=\"border:1px solid #444;padding:6px;\">" . $articulo . "</td>"
            . "<td style=\"border:1px solid #444;padding:6px;\">" . $descripcion . "</td>"
            . "<td style=\"border:1px solid #444;padding:6px;text-align:right;white-space:nowrap;\">" . $pUnit . "</td>"
            . "<td style=\"border:1px solid #444;padding:6px;text-align:right;white-space:nowrap;\">" . $pTotal . "</td>"
            . "</tr>";
    }
    if ($rows === "") {
        $rows = "<tr><td colspan=\"5\" style=\"border:1px solid #444;padding:6px;text-align:center;\">Sin líneas</td></tr>";
    }

    $sinIva = (float)($totals["sin_iva"] ?? 0);
    $ivaAmt = (float)($totals["iva"] ?? 0);
    $conIva = (float)($totals["con_iva"] ?? 0);
    $ivaPct = $sinIva > 0 ? round(($ivaAmt * 100) / $sinIva, 2) : 0.0;
    $ivaPctLabel = rtrim(rtrim(number_format($ivaPct, 2, ".", ""), "0"), ".") . " %";

    return "<!doctype html><html><body style=\"font-family:Arial,Helvetica,sans-serif;color:#111;\">"
        . "<p>Adjuntamos la nota de cargo de adicionales generada por el instalador:</p>"
        . "<p style=\"margin:0 0 6px 0;\">Pedido: " . $pedido . "<br>"
        . "Cliente: " . $cliente . "<br>"
        . "Dirección: " . $direccion . "</p>"
        . "<p style=\"margin:6px 0 0 0;\"><em>Importante: los precios unitarios y totales de línea se muestran sin IVA.</em></p>"
        . "<table style=\"border-collapse:collapse;width:100%;max-width:860px;margin-top:10px;\">"
        . "<thead><tr>"
        . "<th style=\"border:1px solid #444;padding:6px;background:#efefef;\">Uds</th>"
        . "<th style=\"border:1px solid #444;padding:6px;background:#efefef;\">Código</th>"
        . "<th style=\"border:1px solid #444;padding:6px;background:#efefef;\">Articulo</th>"
        . "<th style=\"border:1px solid #444;padding:6px;background:#efefef;\">P.unit (Sin IVA)</th>"
        . "<th style=\"border:1px solid #444;padding:6px;background:#efefef;\">P.total (Sin IVA)</th>"
        . "</tr></thead><tbody>"
        . $rows
        . "</tbody></table>"
        . "<table style=\"border-collapse:collapse;width:100%;max-width:860px;margin-top:14px;\">"
        . "<tr>"
        . "<th style=\"border:1px solid #444;padding:6px;background:#efefef;\">BASE IMPONIBLE</th>"
        . "<th style=\"border:1px solid #444;padding:6px;background:#efefef;\">IVA</th>"
        . "<th style=\"border:1px solid #444;padding:6px;background:#efefef;\">IMPORTE IVA</th>"
        . "<th style=\"border:1px solid #444;padding:6px;background:#efefef;\">TOTAL</th>"
        . "</tr><tr>"
        . "<td style=\"border:1px solid #444;padding:6px;text-align:center;\">" . presup_format_eur($sinIva) . "</td>"
        . "<td style=\"border:1px solid #444;padding:6px;text-align:center;\">" . htmlspecialchars($ivaPctLabel, ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8") . "</td>"
        . "<td style=\"border:1px solid #444;padding:6px;text-align:center;\">" . presup_format_eur($ivaAmt) . "</td>"
        . "<td style=\"border:1px solid #444;padding:6px;text-align:center;\">" . presup_format_eur($conIva) . "</td>"
        . "</tr></table>"
        . "<p style=\"margin-top:18px;\">Atentamente,<br><br>El equipo de ClimaMania</p>"
        . "</body></html>";
}

function presup_send_mail_with_attachment(
    string $to,
    array $bcc,
    string $subject,
    string $body,
    string $attachmentPath,
    string $attachmentName,
    string $attachmentPublicUrl = "",
    string &$mailError = ""
): bool {
    $mailError = "";
    $fromAddress = "climamania@climamania.com";
    $replyTo = "climamania@climamania.com";
    $encodedSubject = "=?UTF-8?B?" . base64_encode($subject) . "?=";

    $recipients = [];
    foreach (presup_parse_email_values($to) as $email) {
        $recipients[$email] = true;
    }
    foreach ($bcc as $emailRaw) {
        foreach (presup_parse_email_values((string)$emailRaw) as $email) {
            $recipients[$email] = true;
        }
    }

    if (empty($recipients)) {
        $mailError = "No hay destinatarios de correo validos";
        return false;
    }

    $commonHeaders = [];
    $commonHeaders[] = "From: ClimaMania Instalaciones <" . $fromAddress . ">";
    $commonHeaders[] = "Reply-To: " . $replyTo;
    $commonHeaders[] = "X-Mailer: PHP/" . PHP_VERSION;

    $encodedHtmlBody = presup_encode_mail_html_body($body);

    $multipartReady = false;
    $multipartMessage = "";
    $multipartHeadersString = "";
    if (is_file($attachmentPath) && is_readable($attachmentPath)) {
        $attachmentData = @file_get_contents($attachmentPath);
        if (is_string($attachmentData) && $attachmentData !== "") {
            $boundary = "=_Part_" . md5(uniqid((string)mt_rand(), true));
            $attachmentB64 = chunk_split(base64_encode($attachmentData));

            $multipartHeaders = $commonHeaders;
            $multipartHeaders[] = "MIME-Version: 1.0";
            $multipartHeaders[] = "Content-Type: multipart/mixed; boundary=\"" . $boundary . "\"";
            $multipartHeadersString = implode("\r\n", $multipartHeaders);

            $multipartMessage = "";
            $multipartMessage .= "--" . $boundary . "\r\n";
            $multipartMessage .= "Content-Type: text/html; charset=UTF-8\r\n";
            $multipartMessage .= "Content-Transfer-Encoding: quoted-printable\r\n\r\n";
            $multipartMessage .= $encodedHtmlBody . "\r\n\r\n";
            $multipartMessage .= "--" . $boundary . "\r\n";
            $multipartMessage .= "Content-Type: application/pdf; name=\"" . $attachmentName . "\"\r\n";
            $multipartMessage .= "Content-Transfer-Encoding: base64\r\n";
            $multipartMessage .= "Content-Disposition: attachment; filename=\"" . $attachmentName . "\"\r\n\r\n";
            $multipartMessage .= $attachmentB64 . "\r\n";
            $multipartMessage .= "--" . $boundary . "--\r\n";
            $multipartReady = true;
        }
    }

    // Fallback: enviar sin adjunto y con enlace publico al PDF.
    $fallbackBody = $body;
    if ($attachmentPublicUrl !== "") {
        $safeUrl = htmlspecialchars($attachmentPublicUrl, ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
        $notice = "<p><strong>Nota:</strong> El PDF no pudo adjuntarse en este envio.</p>"
            . "<p>Puedes descargarlo aqui: <a href=\"" . $safeUrl . "\">" . $safeUrl . "</a></p>";
        if (stripos($fallbackBody, "</body>") !== false) {
            $fallbackBody = preg_replace('/<\/body>/i', $notice . "</body>", $fallbackBody, 1);
        } else {
            $fallbackBody .= $notice;
        }
    }

    $fallbackHeaders = $commonHeaders;
    $fallbackHeaders[] = "MIME-Version: 1.0";
    $fallbackHeaders[] = "Content-Type: text/html; charset=UTF-8";
    $fallbackHeaders[] = "Content-Transfer-Encoding: quoted-printable";
    $fallbackHeadersString = implode("\r\n", $fallbackHeaders);
    $fallbackBodyEncoded = presup_encode_mail_html_body($fallbackBody);

    $sent = 0;
    $totalRecipients = count($recipients);
    $okRecipients = [];
    $errors = [];
    foreach (array_keys($recipients) as $recipient) {
        $recipientAttempts = [];
        $delivered = false;

        if ($multipartReady) {
            $attempt = presup_try_mail_call(
                $recipient,
                $encodedSubject,
                $multipartMessage,
                $multipartHeadersString,
                "-f " . $fromAddress
            );
            if ($attempt["ok"]) {
                $delivered = true;
            } elseif ($attempt["error"] !== "") {
                $recipientAttempts[] = "adjunto/-f: " . $attempt["error"];
            }

            if (!$delivered) {
                $attempt = presup_try_mail_call(
                    $recipient,
                    $encodedSubject,
                    $multipartMessage,
                    $multipartHeadersString,
                    ""
                );
                if ($attempt["ok"]) {
                    $delivered = true;
                } elseif ($attempt["error"] !== "") {
                    $recipientAttempts[] = "adjunto/sin-f: " . $attempt["error"];
                }
            }
        }

        if (!$delivered) {
            $attempt = presup_try_mail_call(
                $recipient,
                $encodedSubject,
                $fallbackBodyEncoded,
                $fallbackHeadersString,
                "-f " . $fromAddress
            );
            if ($attempt["ok"]) {
                $delivered = true;
            } elseif ($attempt["error"] !== "") {
                $recipientAttempts[] = "sin-adjunto/-f: " . $attempt["error"];
            }
        }

        if (!$delivered) {
            $attempt = presup_try_mail_call(
                $recipient,
                $encodedSubject,
                $fallbackBodyEncoded,
                $fallbackHeadersString,
                ""
            );
            if ($attempt["ok"]) {
                $delivered = true;
            } elseif ($attempt["error"] !== "") {
                $recipientAttempts[] = "sin-adjunto/sin-f: " . $attempt["error"];
            }
        }

        if ($delivered) {
            $sent++;
            $okRecipients[] = $recipient;
            continue;
        }

        $errors[] = $recipient . " => "
            . (empty($recipientAttempts) ? "mail() devolvio false en todos los intentos" : implode(" | ", $recipientAttempts));
    }

    if ($sent === $totalRecipients) {
        return true;
    }

    if ($sent > 0) {
        $okList = empty($okRecipients) ? "-" : implode(", ", $okRecipients);
        $mailError = "Parcial (" . $sent . "/" . $totalRecipients . ") OK=[" . $okList . "]"
            . (empty($errors) ? "" : " FAIL=" . implode(" || ", $errors));
        error_log("[presup_mail] envio parcial: " . $mailError);
        return false;
    }

    $mailError = empty($errors)
        ? "mail() devolvio false en todos los intentos"
        : implode(" || ", $errors);
    error_log("[presup_mail] fallo total (0/" . $totalRecipients . "): " . $mailError);
    return false;
}

function presup_encode_mail_html_body(string $html): string
{
    $clean = (string)$html;
    if ($clean === "") {
        return "";
    }

    if (function_exists("quoted_printable_encode")) {
        return quoted_printable_encode($clean);
    }

    // Fallback sin quoted_printable_encode: normalizar saltos y evitar líneas gigantes.
    $normalized = preg_replace("/\r\n|\r|\n/", "\r\n", $clean);
    return wordwrap((string)$normalized, 73, "=\r\n", true);
}

function presup_try_mail_call(
    string $to,
    string $subject,
    string $message,
    string $headers,
    string $additionalParams
): array {
    if (function_exists("error_clear_last")) {
        error_clear_last();
    }

    if ($additionalParams !== "") {
        $ok = @mail($to, $subject, $message, $headers, $additionalParams);
    } else {
        $ok = @mail($to, $subject, $message, $headers);
    }

    $err = "";
    $last = error_get_last();
    if (is_array($last) && isset($last["message"])) {
        $err = trim((string)$last["message"]);
    }

    return [
        "ok" => (bool)$ok,
        "error" => $err
    ];
}

function presup_clean_text_for_mail(string $value): string
{
    $clean = str_replace(["\r", "\n"], " ", (string)$value);
    $clean = preg_replace('/<br\s*\/?>/i', ', ', $clean);
    $clean = strip_tags($clean);
    $clean = preg_replace('/\s+/', ' ', (string)$clean);
    return trim((string)$clean);
}

function presup_split_tokens(string $raw): array
{
    $parts = preg_split('/[,\s;|]+/', strtolower(trim($raw)));
    $tokens = [];
    foreach ($parts as $part) {
        $tk = trim((string)$part);
        if ($tk !== "" && $tk !== "0") {
            $tokens[$tk] = true;
        }
    }
    return array_keys($tokens);
}

function presup_resolve_equipo_raw(PDO $pdo, string $equipoRaw, string $usuario): string
{
    $equipo = trim($equipoRaw);
    if ($equipo !== "" && $equipo !== "0") {
        return $equipo;
    }
    if ($usuario === "") {
        return "";
    }

    try {
        $stmt = $pdo->prepare(
            "SELECT EquipoInstaladores
             FROM ClimaInstal_Usuarios
             WHERE usuario = :usuario
             LIMIT 1"
        );
        $stmt->execute([":usuario" => $usuario]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($row && isset($row["EquipoInstaladores"])) {
            return trim((string)$row["EquipoInstaladores"]);
        }
    } catch (Exception $ignored) {
        // Si falla la lectura de equipo por usuario, devolvemos vacío.
    }

    return "";
}

function presup_build_scope_clause_sql(
    PDO $pdo,
    string $equipoRaw,
    string $usuario,
    bool $isAdmin,
    array &$params,
    string $equipoCol = "EquipoInstaladores",
    string $usuarioCol = "UsuarioInstalador"
): string {
    if ($isAdmin) {
        return "1=1";
    }

    $scopeParts = [];
    $usuarioNorm = strtolower(trim($usuario));
    $equipoResolved = presup_resolve_equipo_raw($pdo, $equipoRaw, $usuario);
    $tokens = presup_split_tokens($equipoResolved);

    if (!empty($tokens)) {
        $tokenMatches = [];
        foreach ($tokens as $i => $tk) {
            $kEq = ":scope_eq_" . $i;
            $kFind = ":scope_find_" . $i;
            $params[$kEq] = $tk;
            $params[$kFind] = $tk;
            $tokenMatches[] = "(LOWER(TRIM($equipoCol)) = $kEq"
                . " OR FIND_IN_SET($kFind, LOWER(REPLACE(REPLACE(REPLACE(REPLACE(TRIM($equipoCol), ';', ','), '|', ','), ' ', ''), ',,', ','))) > 0)";
        }
        $scopeParts[] = "(($equipoCol IS NOT NULL AND TRIM($equipoCol) <> '') AND (" . implode(" OR ", $tokenMatches) . "))";
    }

    if ($usuarioNorm !== "") {
        $params[":scope_usuario"] = $usuarioNorm;
        $scopeParts[] = "(($equipoCol IS NULL OR TRIM($equipoCol) = '') AND LOWER(TRIM($usuarioCol)) = :scope_usuario)";
    }

    if (empty($scopeParts)) {
        return "0=1";
    }

    return "(" . implode(" OR ", $scopeParts) . ")";
}

function presup_row_visible_for_scope(
    string $rowEquipo,
    string $rowUsuario,
    bool $isAdmin,
    array $scopeTokens,
    string $usuarioNorm
): bool {
    if ($isAdmin) {
        return true;
    }

    $equipoClean = strtolower(trim($rowEquipo));
    if ($equipoClean !== "") {
        return presup_equipo_matches_tokens($equipoClean, $scopeTokens);
    }

    if ($usuarioNorm !== "") {
        return strtolower(trim($rowUsuario)) === $usuarioNorm;
    }

    return false;
}

function presup_equipo_matches_tokens(string $rowEquipoLower, array $scopeTokens): bool
{
    if (empty($scopeTokens)) {
        return false;
    }

    if (in_array($rowEquipoLower, $scopeTokens, true)) {
        return true;
    }

    $rowTokens = presup_split_tokens($rowEquipoLower);
    foreach ($rowTokens as $rowToken) {
        if (in_array($rowToken, $scopeTokens, true)) {
            return true;
        }
    }

    return false;
}

function presup_can_edit(bool $isAdmin, string $rowUsuario, string $usuarioActual): bool
{
    if ($isAdmin) {
        return true;
    }
    $row = strtolower(trim($rowUsuario));
    $current = strtolower(trim($usuarioActual));
    if ($row === "" || $current === "") {
        return false;
    }
    return $row === $current;
}

function presup_table_exists(PDO $pdo, string $table): bool
{
    $stmt = $pdo->prepare("SHOW TABLES LIKE ?");
    $stmt->execute([$table]);
    return $stmt->fetchColumn() !== false;
}

function presup_resolve_ps_prefix(PDO $pdo, string $preferred): string
{
    $preferred = trim($preferred);
    if ($preferred !== "" && presup_table_exists($pdo, $preferred . "orders")) {
        return $preferred;
    }

    $fallbacks = ["ps_", ""];
    foreach ($fallbacks as $prefix) {
        if ($prefix === $preferred) {
            continue;
        }
        if (presup_table_exists($pdo, $prefix . "orders")) {
            return $prefix;
        }
    }

    return $preferred;
}

function presup_is_manual_reference(string $value): bool
{
    return stripos(trim($value), "MANUAL-") === 0;
}

function presup_resolve_reference_customer_email(PDO $psPdo, string $psPrefix, string $referencia): string
{
    $ref = presup_normalize_text($referencia, 64);
    if ($ref === "" || presup_is_manual_reference($ref)) {
        return "";
    }

    try {
        $sql = "SELECT c.email
                FROM " . $psPrefix . "orders o
                INNER JOIN " . $psPrefix . "customer c
                    ON o.id_customer = c.id_customer
                WHERE o.reference = :ref
                ORDER BY o.id_order DESC
                LIMIT 1";
        $stmt = $psPdo->prepare($sql);
        $stmt->execute([":ref" => $ref]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($row && isset($row["email"])) {
            return presup_normalize_email((string)$row["email"]);
        }
    } catch (Exception $ignored) {
        // Si falla la consulta de Prestashop, se devuelve vacío.
    }

    return "";
}
