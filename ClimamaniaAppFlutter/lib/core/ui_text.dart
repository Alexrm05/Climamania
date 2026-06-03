import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Port de `UiText.java`. Limpia valores que llegan de la BD y ofrece
/// el estilo de "placeholder" (gris itálica) para datos ausentes.
class UiText {
  UiText._();

  /// Equivalente a `sanitizeDbValue`: NBSP→espacio, trim, y la lista negra
  /// `-/null/undefined/n/a/na` (sin distinguir mayúsculas) se vuelve "".
  static String sanitizeDbValue(String? value) {
    if (value == null) return '';
    // Reemplaza el espacio duro (NBSP, U+00A0) por un espacio normal.
    final clean = value.replaceAll(' ', ' ').trim();
    if (clean.isEmpty) return '';
    final lower = clean.toLowerCase();
    if (lower == '-' ||
        lower == 'null' ||
        lower == 'undefined' ||
        lower == 'n/a' ||
        lower == 'na') {
      return '';
    }
    return clean;
  }

  static bool isMissingDbValue(String? value) =>
      sanitizeDbValue(value).isEmpty;

  /// Port de `limpiarDireccion`: quita las variantes de `<br>`, el resto de
  /// etiquetas HTML y los teléfonos incrustados, y normaliza espacios/saltos.
  static String limpiarDireccion(String? rawDireccion) {
    var raw = sanitizeDbValue(rawDireccion);
    raw = raw
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll('<br>', '\n')
        .replaceAll('</br>', '\n')
        .replaceAll('<BR/>', '\n')
        .replaceAll('<BR />', '\n')
        .replaceAll('<BR>', '\n')
        .replaceAll('</BR>', '\n');
    raw = raw.replaceAll(RegExp(r'<[^>]+>'), '');
    raw = raw.replaceAll(
      RegExp(r'tel\.?\s*:?[ \t]*\d[\d \t]+', caseSensitive: false),
      '',
    );
    raw = raw.replaceAll(RegExp(r'[ \t]+'), ' ');
    raw = raw.replaceAll(RegExp(r' *\n *'), '\n');
    return raw.trim();
  }

  static String displayValue(String? value, String placeholder) {
    final clean = sanitizeDbValue(value);
    return clean.isEmpty ? _safePlaceholder(placeholder) : clean;
  }

  static String _safePlaceholder(String? placeholder) {
    final clean = sanitizeDbValue(placeholder);
    return clean.isEmpty ? 'Dato no disponible' : clean;
  }

  /// Estilo del placeholder: gris #8E8E8E e itálica (UiText.placeholderSpan).
  static const TextStyle placeholderStyle = TextStyle(
    color: AppColors.placeholder,
    fontStyle: FontStyle.italic,
  );
}
