import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'ui_text.dart';

/// Normalización y colores de prioridad (Alta/Media/Baja/Sin prioridad).
class Prioridad {
  Prioridad._();

  static const opciones = ['Alta', 'Media', 'Baja'];

  /// Normaliza la prioridad. Usa igualdad exacta (no `contains`, que producía
  /// falsos positivos como "anormal" → "normal" → Media). Los valores numéricos
  /// se mapean 3+/2/≤1. Un valor desconocido se muestra tal cual, igual que
  /// `parsePrioridad` en Android. (Fix traído de la rama main del Jul-6.)
  static String parse(String? raw) {
    final clean = UiText.sanitizeDbValue(raw);
    if (clean.isEmpty) return 'Sin prioridad';
    switch (clean.toLowerCase()) {
      case 'alta':
      case 'high':
      case 'urgente':
        return 'Alta';
      case 'media':
      case 'medio':
      case 'normal':
        return 'Media';
      case 'baja':
      case 'low':
        return 'Baja';
    }
    final n = int.tryParse(clean);
    if (n != null) {
      if (n >= 3) return 'Alta';
      if (n == 2) return 'Media';
      return 'Baja';
    }
    return clean; // literal desconocido, preservado
  }

  static Color bg(String label) {
    switch (label) {
      case 'Alta':
        return AppColors.errorFg;
      case 'Media':
        return const Color(0xFFE1912B); // ámbar (contraste con texto blanco)
      case 'Baja':
        return const Color(0xFFE4E0DA); // neutro cálido
      default:
        return const Color(0xFFEDEAE5);
    }
  }

  static Color fg(String label) =>
      label == 'Baja' || label == 'Sin prioridad'
          ? AppColors.textSecondary
          : Colors.white;

  static Color stroke(String label) {
    switch (label) {
      case 'Alta':
        return const Color(0xFFE7B0AC);
      case 'Media':
        return const Color(0xFFF1D4A6);
      default:
        return AppColors.border;
    }
  }
}
