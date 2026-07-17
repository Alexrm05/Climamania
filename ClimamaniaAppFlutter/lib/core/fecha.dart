import 'package:intl/intl.dart';

import 'ui_text.dart';

/// Formato de fecha único de toda la app: "dd-MM-yyyy HH:mm"
/// (día-mes-año hora:minutos), y "dd-MM-yyyy" para fechas sin hora.
class Fecha {
  Fecha._();

  static final DateFormat _fechaHora = DateFormat('dd-MM-yyyy HH:mm', 'es');
  static final DateFormat _soloFecha = DateFormat('dd-MM-yyyy', 'es');
  static final DateFormat _soloHora = DateFormat('HH:mm', 'es');

  /// "dd-MM-yyyy HH:mm" a partir de un DateTime.
  static String hm(DateTime d) => _fechaHora.format(d);

  /// "dd-MM-yyyy" a partir de un DateTime.
  static String dma(DateTime d) => _soloFecha.format(d);

  /// "HH:mm" a partir de un DateTime.
  static String hora(DateTime d) => _soloHora.format(d);

  /// Parsea una fecha del backend/string y la devuelve como "dd-MM-yyyy HH:mm"
  /// (o "dd-MM-yyyy" si el dato original no incluye hora).
  /// Si no se puede parsear, devuelve el texto original ya saneado.
  static String parse(String raw) {
    final clean = UiText.sanitizeDbValue(raw);
    if (clean.isEmpty) return '';
    final d = DateTime.tryParse(clean.replaceFirst(' ', 'T'));
    if (d == null) return clean;
    // Incluye la hora solo si el original la trae.
    return clean.contains(':') ? _fechaHora.format(d) : _soloFecha.format(d);
  }
}
