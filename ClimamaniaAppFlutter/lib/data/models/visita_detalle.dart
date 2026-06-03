import '../../core/ui_text.dart';
import 'gestion_item.dart';

/// Mensaje del muro de una visita/incidencia.
class MuroMensaje {
  final String mensaje;
  final String autor;
  final String rol;
  final String origen;
  final String dateAdd;

  const MuroMensaje({
    required this.mensaje,
    required this.autor,
    required this.rol,
    required this.origen,
    required this.dateAdd,
  });

  factory MuroMensaje.fromJson(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());
    return MuroMensaje(
      mensaje: s('mensaje'),
      autor: s('autor'),
      rol: s('rol'),
      origen: s('origen'),
      dateAdd: s('date_add'),
    );
  }
}

const _imgExt = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif'};
const _vidExt = {'mp4', 'mov', 'm4v', '3gp', 'webm', 'avi', 'mkv', 'mpeg', 'mpg'};

/// Fichero adjunto a una visita/incidencia.
class Fichero {
  final String ruta;
  final String tipoFichero;
  final String usuario;
  final String dateAdd;

  const Fichero({
    required this.ruta,
    required this.tipoFichero,
    required this.usuario,
    required this.dateAdd,
  });

  factory Fichero.fromJson(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());
    return Fichero(
      ruta: s('ruta'),
      tipoFichero: s('tipo_fichero'),
      usuario: s('usuario'),
      dateAdd: s('date_add'),
    );
  }

  String get _ext {
    final t = tipoFichero.toLowerCase();
    if (_imgExt.contains(t) || _vidExt.contains(t)) return t;
    final clean = ruta.split('?').first.toLowerCase();
    return clean.contains('.') ? clean.split('.').last : '';
  }

  bool get isImage {
    final t = tipoFichero.toLowerCase();
    if (t.contains('image') || t.contains('foto')) return true;
    return _imgExt.contains(_ext);
  }

  bool get isVideo {
    if (tipoFichero.toLowerCase().contains('video')) return true;
    return _vidExt.contains(_ext);
  }

  String get nombre {
    final clean = ruta.split('?').first;
    final parts = clean.split('/');
    return parts.isEmpty ? ruta : parts.last;
  }
}

/// Respuesta de get_visita_detalle.php.
class VisitaDetalle {
  final GestionItem visita;
  final List<MuroMensaje> muro;
  final List<Fichero> ficheros;

  const VisitaDetalle({
    required this.visita,
    required this.muro,
    required this.ficheros,
  });
}
