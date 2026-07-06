import 'package:flutter/material.dart';
import 'ui_text.dart';

/// Normalización y colores de prioridad (Alta/Media/Baja/Sin prioridad).
class Prioridad {
  Prioridad._();

  static const opciones = ['Alta', 'Media', 'Baja'];

  /// Normaliza la prioridad. Usa igualdad exacta (no `contains`, que producía
  /// falsos positivos como "anormal" → "normal" → Media). Los valores numéricos
  /// se mapean 3+/2/≤1. Un valor desconocido se muestra tal cual (con estilo de
  /// prioridad baja), igual que `parsePrioridad` en Android.
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
        return const Color(0xFFD32F2F);
      case 'Media':
        return const Color(0xFFF9A825);
      case 'Baja':
        return const Color(0xFFCFD8DC);
      default:
        return const Color(0xFFE0E0E0);
    }
  }

  // Texto blanco solo sobre los fondos intensos (Alta/Media); el resto (Baja,
  // Sin prioridad y literales desconocidos) usa texto oscuro sobre fondo claro.
  static Color fg(String label) =>
      label == 'Alta' || label == 'Media'
          ? Colors.white
          : const Color(0xFF1F2937);

  static Color stroke(String label) {
    switch (label) {
      case 'Alta':
        return const Color(0xFFF4B0A9);
      case 'Media':
        return const Color(0xFFF3D09B);
      case 'Baja':
        return const Color(0xFFCFD8DC);
      default:
        return const Color(0xFFE9DCCF);
    }
  }
}
