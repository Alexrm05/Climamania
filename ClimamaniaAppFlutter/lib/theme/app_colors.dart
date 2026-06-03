import 'package:flutter/material.dart';

/// Paleta corporativa ClimaMania (naranja + negro + blanco).
/// Réplica exacta de `res/values/colors.xml` y de los colores embebidos
/// en los layouts XML de la app Android.
class AppColors {
  AppColors._();

  // --- Paleta principal (colors.xml) ---
  static const Color primary = Color(0xFFF28C3A); // naranja suave principal
  static const Color primaryLight = Color(0xFFF1F1F1); // fondo gris muy claro
  static const Color primaryDark = Color(0xFF212121); // casi negro (textos/barras)
  static const Color accent = Color(0xFFF28C3A);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  static const Color footerBarBg = Color(0xFFFAFAFA);
  static const Color footerBarStroke = Color(0xFFE6E6E6);
  static const Color footerActiveBg = Color(0xFFFFF1E3);
  static const Color footerInactive = Color(0xFF7A7A7A);

  static const Color buttonLightBlue = Color(0xFF67C7F8);

  // --- Icono/cabecera ---
  static const Color iconHeader = Color(0xFF424242);

  // --- Texto auxiliar ---
  static const Color placeholder = Color(0xFF8E8E8E); // UiText.placeholderSpan
  static const Color textSecondary = Color(0xFF6F6F6F);
  static const Color hintGray = Color(0xFF777777);
  static const Color drawerItem = Color(0xFF424242);
  static const Color logoutRed = Color(0xFFB00020);
  static const Color checkboxLabel = Color(0xFF555555);

  // --- Tarjetas / contenedores (layouts) ---
  static const Color cardStroke = Color(0xFFEFE2D6);

  // bg_detail_hero (saludo)
  static const Color heroGradientStart = Color(0xFFFFF9F2);
  static const Color heroGradientEnd = Color(0xFFFFFFFF);
  static const Color heroStroke = Color(0xFFF2E6DA);

  // bg_address_highlight
  static const Color addressBg = Color(0xFFFFFDF9);
  static const Color addressStroke = Color(0xFFF2D9C2);
  static const Color addressText = Color(0xFF37474F);

  // bg_chip_light (meta)
  static const Color chipBg = Color(0xFFFFF8F1);
  static const Color chipStroke = Color(0xFFE7C6A6);
  static const Color chipText = Color(0xFF6D4C41);

  // bg_section_label_green ("Instalación en curso")
  static const Color sectionGreenBg = Color(0xFFE9F7EC);
  static const Color sectionGreenStroke = Color(0xFF4CAF50);

  // Botón "visitas pendientes" (verde)
  static const Color pendingGreenBg = Color(0xFFEEF8F0);
  static const Color pendingGreenText = Color(0xFF2D613A);
  static const Color pendingGreenIcon = Color(0xFF3A8750);
  static const Color pendingGreenStroke = Color(0xFF70AE7D);

  // Botón "incidencias pendientes" (rojo)
  static const Color pendingRedBg = Color(0xFFFFF1F1);
  static const Color pendingRedText = Color(0xFF7A2F2F);
  static const Color pendingRedIcon = Color(0xFFCC4B4B);
  static const Color pendingRedStroke = Color(0xFFE28C8C);
}
