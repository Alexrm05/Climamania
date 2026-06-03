import 'package:flutter/material.dart';
import '../../core/ui_text.dart';
import '../../data/models/evento.dart';

/// Días visibles (Lun–Vie) y franjas horarias (8:00–20:00), igual que Android.
const List<String> kDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie'];
const List<String> kHours = [
  '8:00', '9:00', '10:00', '11:00', '12:00', '13:00', '14:00',
  '15:00', '16:00', '17:00', '18:00', '19:00', '20:00',
];

/// Colores y reglas de los eventos del calendario (port de CalendarActivity).
class EventStyles {
  EventStyles._();

  /// Color por código de equipo.
  static Color forEquipo(String? code) {
    switch ((code ?? '').trim().toUpperCase()) {
      case 'FCB':
        return const Color(0xFF1976D2); // azul
      case 'FCB2':
        return const Color(0xFFE37D33); // naranja
      case 'JZ':
        return const Color(0xFF388E3C); // verde
      case 'JS':
        return const Color(0xFF7B1FA2); // morado
      case 'MA':
        return const Color(0xFF0097A7); // turquesa
      case 'CLM1':
        return const Color(0xFFFBC02D); // amarillo
      default:
        return const Color(0xFFB0BEC5); // gris (sin equipo)
    }
  }

  /// Color principal del evento: columna "color" si existe, si no, por equipo.
  static Color forEvento(Evento ev) {
    final hex = ev.color.trim();
    if (hex.isNotEmpty) {
      final parsed = _parseHex(hex);
      if (parsed != null) return parsed;
    }
    return forEquipo(ev.equipoInstaladores);
  }

  static Color bgForEvento(Evento ev, {int alpha = 80}) =>
      forEvento(ev).withAlpha(alpha);

  static Color? _parseHex(String hexRaw) {
    var hex = hexRaw.trim();
    if (!hex.startsWith('#')) hex = '#$hex';
    final value = hex.substring(1);
    String argb;
    if (value.length == 6) {
      argb = 'FF$value';
    } else if (value.length == 8) {
      argb = value;
    } else {
      return null;
    }
    final parsed = int.tryParse(argb, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  /// ¿La referencia parece un pedido real? (contiene al menos un dígito)
  static bool isPedidoValido(String? pedido) {
    final p = (pedido ?? '').trim();
    return p.isNotEmpty && RegExp(r'\d').hasMatch(p);
  }

  /// Regla del cliente: si el estado contiene "finalizado" → FINALIZADO.
  static bool esFinalizado(String? estado) =>
      UiText.sanitizeDbValue(estado).toLowerCase().contains('finalizado');

  static String estadoLabel(String? estado) =>
      esFinalizado(estado) ? 'FINALIZADO' : 'SIN FINALIZAR';

  static Color estadoColor(String? estado) => esFinalizado(estado)
      ? const Color(0xFF388E3C) // verde
      : const Color(0xFFFB8C00); // naranja

  /// ¿El evento es una "visita"? (texto contiene "visita")
  static bool esVisita(Evento ev) {
    final text = [
      ev.titulo,
      ev.detalles,
      ev.comentarios,
      ev.referencia,
      ev.nombreCliente,
    ].join(' ').toLowerCase();
    return text.contains('visita');
  }

  /// Limpia la dirección (quita <br> y etiquetas HTML).
  static String formatDireccion(String? raw) {
    var r = UiText.sanitizeDbValue(raw);
    r = r.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    r = r.replaceAll(RegExp(r'</br>', caseSensitive: false), '\n');
    r = r.replaceAll(RegExp(r'<[^>]+>'), '');
    return r.trim();
  }

  /// Franja horaria "8:00 - 11:00".
  static String horaPrevista(int startIndex, int duration) {
    final inicio = kHours[startIndex];
    final finIndex = startIndex + duration;
    final fin = finIndex < kHours.length ? kHours[finIndex] : 'Fin';
    return '$inicio - $fin';
  }
}
