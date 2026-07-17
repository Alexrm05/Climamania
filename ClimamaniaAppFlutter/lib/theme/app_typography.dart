import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Escala tipográfica de la app (fuente del sistema — Roboto/SF).
/// El cambio clave frente al estado anterior es la DISCIPLINA DE PESOS:
/// títulos w600/w700, cuerpo w400, etiquetas w600 — en vez de "todo bold".
/// Los tamaños se mantienen ≈ a los actuales (con el textScaler 0.9 global
/// de main.dart, el tamaño visible apenas cambia).
class AppTypography {
  AppTypography._();

  static const TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.5,
        color: AppColors.textPrimary),
    headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.3,
        color: AppColors.textPrimary),
    titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.2,
        color: AppColors.textPrimary),
    titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.textPrimary),
    titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: AppColors.textPrimary),
    bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textPrimary),
    bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textPrimary),
    bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: AppColors.textSecondary),
    labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: 0.2),
    labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: 0.3),
    labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: 0.4),
  );
}
