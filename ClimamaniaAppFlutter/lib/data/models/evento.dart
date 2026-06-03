import '../../core/ui_text.dart';

/// Evento de calendario devuelto por `get_events.php`. Modelo defensivo:
/// todos los campos pasan por `sanitizeDbValue` y las fechas se parsean
/// de forma tolerante (formato servidor `yyyy-MM-dd HH:mm:ss`).
class Evento {
  final String start;
  final String end;
  final String referencia;
  final String titulo;
  final String nombreCliente;
  final String direccion;
  final String telefono;
  final String whatsapp;
  final String equipoInstaladores;
  final String estado;
  final String detalles;
  final String comentarios;
  final String concertada;
  final String emailEquipo;
  final String color;

  final DateTime? startDate;
  final DateTime? endDate;

  Evento({
    required this.start,
    required this.end,
    required this.referencia,
    required this.titulo,
    required this.nombreCliente,
    required this.direccion,
    required this.telefono,
    required this.whatsapp,
    required this.equipoInstaladores,
    required this.estado,
    required this.detalles,
    required this.comentarios,
    required this.concertada,
    required this.emailEquipo,
    required this.color,
    required this.startDate,
    required this.endDate,
  });

  factory Evento.fromJson(Map<String, dynamic> j) {
    String s(String key) => UiText.sanitizeDbValue(j[key]?.toString());

    final start = s('start');
    final end = s('end');
    final startDate = _parseServerDate(start);
    DateTime? endDate = _parseServerDate(end);
    // Si falta el fin, se asume 1h después del inicio (igual que Android).
    if (endDate == null && startDate != null) {
      endDate = startDate.add(const Duration(hours: 1));
    }

    return Evento(
      start: start,
      end: end,
      referencia: s('referencia'),
      titulo: s('title'),
      nombreCliente: s('nombrecliente'),
      direccion: s('direccion'),
      telefono: s('telefono'),
      whatsapp: s('whatsapp'),
      equipoInstaladores: s('equipo_instaladores'),
      estado: s('estado'),
      detalles: s('detalles'),
      comentarios: s('comentarios'),
      concertada: s('concertada'),
      emailEquipo: s('EmailEquipo'),
      color: s('color'),
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Parsea "yyyy-MM-dd HH:mm:ss" de forma tolerante.
  static DateTime? _parseServerDate(String value) {
    if (value.isEmpty) return null;
    // DateTime.tryParse acepta separador espacio o 'T'.
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }
}
