import 'package:flutter/material.dart';
import 'ui_text.dart';

/// Normalización y colores de prioridad (Alta/Media/Baja/Sin prioridad).
class Prioridad {
  Prioridad._();

  static const opciones = ['Alta', 'Media', 'Baja'];

  static String parse(String? raw) {
    final clean = UiText.sanitizeDbValue(raw);
    if (clean.isEmpty) return 'Sin prioridad';
    final lower = clean.toLowerCase();
    if (lower.contains('alta') || lower.contains('high') || lower.contains('urgente')) {
      return 'Alta';
    }
    if (lower.contains('media') || lower.contains('medio') || lower.contains('normal')) {
      return 'Media';
    }
    if (lower.contains('baja') || lower.contains('low')) {
      return 'Baja';
    }
    final n = int.tryParse(clean);
    if (n != null) {
      if (n >= 3) return 'Alta';
      if (n == 2) return 'Media';
      return 'Baja';
    }
    return 'Sin prioridad';
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

  static Color fg(String label) =>
      label == 'Baja' || label == 'Sin prioridad'
          ? const Color(0xFF1F2937)
          : Colors.white;

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
