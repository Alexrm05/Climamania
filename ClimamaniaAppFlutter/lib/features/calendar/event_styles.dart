import 'package:flutter/material.dart';
import '../../core/ui_text.dart';
import '../../data/models/evento.dart';

/// Días visibles (Lun–Dom) y franjas horarias (08h–20h).
const List<String> kDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const List<String> kHours = [
  '08h', '09h', '10h', '11h', '12h', '13h', '14h',
  '15h', '16h', '17h', '18h', '19h', '20h',
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

  /// Versión legible de un color de equipo para usarlo como texto, franja o
  /// borde sobre el fondo claro de la tarjeta: oscurece los colores demasiado
  /// claros (amarillo, cian, verde claro…) para que siempre contrasten.
  static Color readable(Color c) {
    final hsl = HSLColor.fromColor(c);
    // Oscurece los colores claros para que contrasten sobre fondo claro.
    final lightness = hsl.lightness > 0.40 ? 0.36 : hsl.lightness;
    // Sube la saturación de colores lavados para que el color se distinga bien.
    final saturation = hsl.saturation < 0.55 ? 0.65 : hsl.saturation;
    return hsl.withLightness(lightness).withSaturation(saturation).toColor();
  }

  /// Color legible del equipo (para texto/franja/borde de la tarjeta).
  static Color readableForEquipo(String? equipo) =>
      readable(forEquipo(equipo));

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

  /// ¿El evento es una "incidencia"? (texto contiene "incidencia")
  static bool esIncidencia(Evento ev) {
    final text = [
      ev.titulo,
      ev.detalles,
      ev.comentarios,
      ev.referencia,
      ev.nombreCliente,
    ].join(' ').toLowerCase();
    return text.contains('incidencia');
  }

  /// Limpia la dirección (quita <br> y etiquetas HTML).
  static String formatDireccion(String? raw) {
    var r = UiText.sanitizeDbValue(raw);
    r = r.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    r = r.replaceAll(RegExp(r'</br>', caseSensitive: false), '\n');
    r = r.replaceAll(RegExp(r'<[^>]+>'), '');
    return r.trim();
  }

  /// Franja horaria del evento "8:00 - 11:00" (formato independiente del eje de
  /// horas del calendario, que usa "08h"). startIndex 0 = 8:00.
  static String horaPrevista(int startIndex, int duration) {
    final inicio = '${8 + startIndex}:00';
    final finIndex = startIndex + duration;
    final fin = finIndex < kHours.length ? '${8 + finIndex}:00' : 'Fin';
    return '$inicio - $fin';
  }
}
