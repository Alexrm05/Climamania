import '../../core/app_config.dart';
import '../../core/ui_text.dart';
import '../api/api_client.dart';
import '../models/gestion_item.dart';
import '../models/visita_detalle.dart';

/// Endpoints de incidencias (Fase 5). Espejo de VisitaRepository con
/// `id_incidencia` y las claves `incidencias`/`incidencia`.
class IncidenciaRepository {
  final ApiClient _api;

  IncidenciaRepository(this._api);

  String _s(dynamic v) => UiText.sanitizeDbValue(v?.toString());

  (bool, String) _result(Map<String, dynamic> json, String okMsg) {
    final ok = json['success'] == true;
    final msg = _s(json['message']);
    return (ok, msg.isEmpty ? (ok ? okMsg : 'No se pudo completar') : msg);
  }

  Future<({bool ok, String message, List<GestionItem> items})> getPendientes({
    required String rol,
    required String equipo,
    required String usuario,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getIncidenciasPendientesDetalle,
        query: {'rol': rol, 'equipo': equipo, 'usuario': usuario},
        noCache: true,
      );
      if (json['success'] != true) {
        final msg = _s(json['message']);
        return (
          ok: false,
          message: msg.isEmpty
              ? 'No se pudieron cargar las incidencias pendientes'
              : msg,
          items: <GestionItem>[],
        );
      }
      final list = <GestionItem>[];
      final raw = json['incidencias'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            list.add(GestionItem.fromIncidencia(Map<String, dynamic>.from(e)));
          }
        }
      }
      return (ok: true, message: '', items: list);
    } catch (_) {
      return (
        ok: false,
        message: 'Error de conexión al cargar incidencias pendientes',
        items: <GestionItem>[],
      );
    }
  }

  /// Incidencias previas asociadas a una referencia de pedido, mostradas en el
  /// detalle del pedido (`get_incidencias_previas_por_referencia.php`).
  Future<List<GestionItem>> getPreviasPorReferencia({
    required String referencia,
    required String rol,
    required String equipo,
    required String usuario,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getIncidenciasPreviasPorReferencia,
        query: {
          'referencia': referencia,
          'rol': rol,
          'equipo': equipo,
          'usuario': usuario,
        },
        noCache: true,
      );
      if (json['success'] != true) return <GestionItem>[];
      final list = <GestionItem>[];
      final raw = json['incidencias'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            list.add(GestionItem.fromIncidencia(Map<String, dynamic>.from(e)));
          }
        }
      }
      return list;
    } catch (_) {
      return <GestionItem>[];
    }
  }

  Future<({bool ok, String message, VisitaDetalle? detalle})> getDetalle(
    String idIncidencia, {
    required String rol,
    required String equipo,
    required String usuario,
    String referencia = '',
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getIncidenciaDetalle,
        query: {
          'id_incidencia': idIncidencia,
          'rol': rol,
          'equipo': equipo,
          'usuario': usuario,
          if (referencia.isNotEmpty) 'referencia': referencia,
        },
        noCache: true,
      );
      final ok = json['success'] == true;
      // Android acepta tanto `incidencia` como `visita` en el detalle.
      final raw = json['incidencia'] ?? json['visita'];
      if (!ok || raw is! Map) {
        return (ok: false, message: _s(json['message']), detalle: null);
      }
      final muro = <MuroMensaje>[];
      if (json['muro'] is List) {
        for (final e in json['muro'] as List) {
          if (e is Map) {
            muro.add(MuroMensaje.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }
      final ficheros = <Fichero>[];
      if (json['ficheros'] is List) {
        for (final e in json['ficheros'] as List) {
          if (e is Map) {
            ficheros.add(Fichero.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }
      return (
        ok: true,
        message: '',
        detalle: VisitaDetalle(
          visita: GestionItem.fromIncidencia(Map<String, dynamic>.from(raw)),
          muro: muro,
          ficheros: ficheros,
        ),
      );
    } catch (_) {
      return (ok: false, message: 'Error de conexión', detalle: null);
    }
  }

  Map<String, String> _base({
    required String idIncidencia,
    required String rol,
    required String usuario,
    required String equipo,
    required String autor,
  }) =>
      {
        'id_incidencia': idIncidencia,
        'rol': rol,
        'usuario': usuario,
        'equipo': equipo,
        'autor': autor,
      };

  Future<(bool, String)> enviarComentario({
    required String idIncidencia,
    required String rol,
    required String usuario,
    required String equipo,
    required String autor,
    required String mensaje,
  }) async {
    try {
      final json = await _api.postForm(AppConfig.incidenciaEnviarComentarios, {
        ..._base(idIncidencia: idIncidencia, rol: rol, usuario: usuario, equipo: equipo, autor: autor),
        'mensaje': mensaje,
      });
      return _result(json, 'Comentario enviado');
    } catch (_) {
      return (false, 'Error al enviar el comentario');
    }
  }

  Future<(bool, String)> enviarFotoBytes({
    required String idIncidencia,
    required String rol,
    required String usuario,
    required String equipo,
    required String autor,
    required String iniciales,
    required List<int> bytes,
    required String filename,
  }) async {
    try {
      final json = await _api.uploadBytes(
        AppConfig.incidenciaEnviarFotos,
        fields: {
          ..._base(idIncidencia: idIncidencia, rol: rol, usuario: usuario, equipo: equipo, autor: autor),
          'k_iniciales': iniciales,
        },
        bytes: bytes,
        filename: filename,
      );
      return _result(json, 'Archivo subido');
    } catch (_) {
      return (false, 'Error al subir el archivo');
    }
  }

  Future<(bool, String)> enviarFotoPath({
    required String idIncidencia,
    required String rol,
    required String usuario,
    required String equipo,
    required String autor,
    required String iniciales,
    required String path,
    required String filename,
  }) async {
    try {
      final json = await _api.uploadFile(
        AppConfig.incidenciaEnviarFotos,
        fields: {
          ..._base(idIncidencia: idIncidencia, rol: rol, usuario: usuario, equipo: equipo, autor: autor),
          'k_iniciales': iniciales,
        },
        filePath: path,
        filename: filename,
      );
      return _result(json, 'Archivo subido');
    } catch (_) {
      return (false, 'Error al subir el archivo');
    }
  }

  Future<(bool, String)> cambiarPrioridad({
    required String idIncidencia,
    required String rol,
    required String usuario,
    required String equipo,
    required String autor,
    required String prioridad,
  }) async {
    try {
      final json = await _api.postForm(AppConfig.incidenciaCambiarPrioridad, {
        ..._base(idIncidencia: idIncidencia, rol: rol, usuario: usuario, equipo: equipo, autor: autor),
        'prioridad': prioridad,
      });
      return _result(json, 'Prioridad actualizada');
    } catch (_) {
      return (false, 'Error al cambiar la prioridad');
    }
  }

  Future<(bool, String)> cerrar({
    required String idIncidencia,
    required String rol,
    required String usuario,
    required String equipo,
    required String autor,
    required String accion,
    String motivo = '',
    String resumen = '',
  }) async {
    try {
      // Como Android: `motivo` solo al cancelar; `resumen_actuacion` solo al
      // finalizar una incidencia.
      final fields = {
        ..._base(idIncidencia: idIncidencia, rol: rol, usuario: usuario, equipo: equipo, autor: autor),
        'accion': accion,
        if (accion == 'cancelar') 'motivo': motivo,
        if (accion == 'finalizar') 'resumen_actuacion': resumen,
      };
      final json = await _api.postForm(AppConfig.incidenciaCerrar, fields);
      return _result(json, accion == 'finalizar' ? 'Incidencia finalizada' : 'Incidencia cancelada');
    } catch (_) {
      return (false, 'Error al cerrar la incidencia');
    }
  }
}
