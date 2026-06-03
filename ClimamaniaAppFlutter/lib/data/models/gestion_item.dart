import '../../core/ui_text.dart';

/// Visita o incidencia (realizada) tal como aparece en la búsqueda.
class GestionItem {
  final String id;
  final String referencia;
  final String cliente;
  final String direccion;
  final String poblacion;
  final String telefono;
  final String email;
  final String equipoId;
  final String solicitante;
  final String prioridad;
  final String estado;
  final String fechaSolicitud;
  final String fechaResolucion;

  const GestionItem({
    required this.id,
    required this.referencia,
    required this.cliente,
    required this.direccion,
    required this.poblacion,
    required this.telefono,
    required this.email,
    required this.equipoId,
    required this.solicitante,
    required this.prioridad,
    required this.estado,
    required this.fechaSolicitud,
    required this.fechaResolucion,
  });

  factory GestionItem.fromVisita(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());
    return GestionItem(
      id: s('id_visita'),
      referencia: '',
      cliente: s('cliente'),
      direccion: s('direccion'),
      poblacion: s('poblacion'),
      telefono: s('telefono'),
      email: s('email'),
      equipoId: s('equipo_id'),
      solicitante: s('usuario_solicita'),
      prioridad: _first(s('prioridad_label'), s('prioridad')),
      estado: _first(s('estado_label'), s('estado')),
      fechaSolicitud: s('fecha_solicitud'),
      fechaResolucion: s('fecha_resolucion'),
    );
  }

  factory GestionItem.fromIncidencia(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());
    var id = s('id_incidencia');
    if (id.isEmpty || id == 'null') id = s('id_visita');
    return GestionItem(
      id: id,
      referencia: _first(s('referencia'), s('pedido')),
      cliente: s('cliente'),
      direccion: s('direccion'),
      poblacion: s('poblacion'),
      telefono: s('telefono'),
      email: s('email'),
      equipoId: s('equipo_id'),
      solicitante: s('usuario_solicita'),
      prioridad: _first(s('prioridad_label'), s('prioridad')),
      estado: _first(s('estado_label'), s('estado')),
      fechaSolicitud: s('fecha_solicitud'),
      fechaResolucion: s('fecha_resolucion'),
    );
  }

  static String _first(String a, String b) => a.isNotEmpty ? a : b;

  String get searchText => [
        id,
        referencia,
        cliente,
        direccion,
        poblacion,
        telefono,
        email,
        prioridad,
        estado,
        equipoId,
        solicitante,
        fechaSolicitud,
        fechaResolucion,
      ].join(' ').toLowerCase();
}
