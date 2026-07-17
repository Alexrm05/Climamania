import 'package:flutter/material.dart';

/// Paleta corporativa ClimaMania.
///
/// PRINCIPALES (congelados): naranja de marca, negro de texto/barras y el
/// fondo gris claro. NO se modifican.
/// SECUNDARIOS: neutros con matiz cálido suavizado + semánticos, consolidados
/// para dar coherencia estética. Muchos nombres antiguos se conservan (ahora
/// apuntando a los valores nuevos) para no romper las llamadas existentes.
class AppColors {
  AppColors._();

  // --- Paleta PRINCIPAL (congelada) ---
  static const Color primary = Color(0xFFF28C3A); // naranja suave principal
  static const Color primaryLight = Color(0xFFF1F1F1); // fondo gris muy claro
  static const Color primaryDark = Color(0xFF212121); // casi negro (textos/barras)
  static const Color accent = Color(0xFFF28C3A);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // --- Barra inferior ---
  static const Color footerBarBg = Color(0xFFFAFAFA);
  static const Color footerBarStroke = Color(0xFFE9E1D8); // = border
  static const Color footerActiveBg = Color(0xFFFFF1E3);
  static const Color footerInactive = Color(0xFF6E6C68); // gris cálido, buen contraste

  static const Color buttonLightBlue = Color(0xFF67C7F8);

  // Botones de confirmar / aceptar / continuar / guardar / enviar / añadir.
  static const Color confirm = Color(0xFF2E7D32); // verde (= successFg)

  // =========================================================================
  // REFRESH: colores SECUNDARIOS (neutros cálidos) + semánticos.
  // =========================================================================

  // Superficies y bordes (neutro cálido suavizado).
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceWarm = Color(0xFFFBFAF8); // tinte crema muy suave
  static const Color border = Color(0xFFE9E1D8); // borde cálido sutil
  static const Color borderStrong = Color(0xFFD6CFC6);
  static const Color scrim = Color(0x66000000); // overlay de carga

  // Texto (principal = primaryDark, no cambia).
  static const Color textPrimary = primaryDark; // #212121
  static const Color textSecondary = Color(0xFF5E5A54); // gris cálido
  static const Color textMuted = Color(0xFF8C8A86); // gris cálido claro

  // Semánticos: cada rol con primer plano (fg) + tinte de fondo.
  static const Color successFg = Color(0xFF2E7D32);
  static const Color successTint = Color(0xFFE7F1E8);
  static const Color warningFg = Color(0xFFB45309);
  static const Color warningTint = Color(0xFFFBEEDD);
  static const Color errorFg = Color(0xFFC62828);
  static const Color errorTint = Color(0xFFFBEAE7);
  static const Color infoFg = Color(0xFF1565C0);
  static const Color infoTint = Color(0xFFE9F0FA);

  // --- Icono/cabecera ---
  static const Color iconHeader = Color(0xFF424242);

  // --- Texto auxiliar (nombres antiguos → neutros nuevos) ---
  static const Color placeholder = textMuted; // #8C8A86
  static const Color hintGray = textMuted;
  static const Color drawerItem = Color(0xFF424242);
  static const Color logoutRed = Color(0xFFB00020);
  static const Color checkboxLabel = textSecondary;

  // --- Tarjetas / contenedores ---
  static const Color cardStroke = border;

  // Hero: antes degradado cálido; ahora plano cálido.
  static const Color heroGradientStart = surfaceWarm;
  static const Color heroGradientEnd = white;
  static const Color heroStroke = border;

  // Resaltado de dirección.
  static const Color addressBg = surfaceWarm;
  static const Color addressStroke = border;
  static const Color addressText = textSecondary;

  // Chip claro (meta).
  static const Color chipBg = surfaceWarm;
  static const Color chipStroke = border;
  static const Color chipText = textSecondary;

  // Etiqueta verde ("Instalación en curso").
  static const Color sectionGreenBg = successTint;
  static const Color sectionGreenStroke = successFg;

  // Botón "visitas pendientes" (verde).
  static const Color pendingGreenBg = successTint;
  static const Color pendingGreenText = Color(0xFF2D613A);
  static const Color pendingGreenIcon = successFg;
  static const Color pendingGreenStroke = Color(0xFF9BC3A2);

  // Botón "incidencias pendientes" (rojo).
  static const Color pendingRedBg = errorTint;
  static const Color pendingRedText = Color(0xFF8A2F2F);
  static const Color pendingRedIcon = errorFg;
  static const Color pendingRedStroke = Color(0xFFE7B0AC);
}
