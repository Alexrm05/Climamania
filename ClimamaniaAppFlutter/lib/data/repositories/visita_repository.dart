import '../../core/app_config.dart';
import '../../core/ui_text.dart';
import '../api/api_client.dart';
import '../models/gestion_item.dart';
import '../models/visita_detalle.dart';

class VisitaRepository {
  final ApiClient _api;

  VisitaRepository(this._api);

  String _s(dynamic v) => UiText.sanitizeDbValue(v?.toString());

  (bool, String) _result(Map<String, dynamic> json, String okMsg) {
    final ok = json['success'] == true;
    final msg = _s(json['message']);
    return (ok, msg.isEmpty ? (ok ? okMsg : 'No se pudo completar') : msg);
  }

  Future<(bool, List<GestionItem>)> getPendientes({
    required String rol,
    required String equipo,
    required String usuario,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getVisitasPendientesDetalle,
        query: {'rol': rol, 'equipo': equipo, 'usuario': usuario},
        noCache: true,
      );
      if (json['success'] != true) return (false, <GestionItem>[]);
      final list = <GestionItem>[];
      final raw = json['visitas'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            list.add(GestionItem.fromVisita(Map<String, dynamic>.from(e)));
          }
        }
      }
      return (true, list);
    } catch (_) {
      return (false, <GestionItem>[]);
    }
  }

  Future<({bool ok, String message, VisitaDetalle? detalle})> getDetalle(
    String idVisita, {
    required String rol,
    required String equipo,
    required String usuario,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getVisitaDetalle,
        query: {
          'id_visita': idVisita,
          'rol': rol,
          'equipo': equipo,
          'usuario': usuario,
        },
        noCache: true,
      );
      final ok = json['success'] == true;
      final visitaRaw = json['visita'];
      if (!ok || visitaRaw is! Map) {
        return (
          ok: false,
          message: _s(json['message']),
          detalle: null,
        );
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
          visita: GestionItem.fromVisita(Map<String, dynamic>.from(visitaRaw)),
          muro: muro,
          ficheros: ficheros,
        ),
      );
    } catch (_) {
      return (ok: false, message: 'Error de conexión', detalle: null);
    }
  }

  Map<String, String> _base({
    required String idVisita,
    required String rol,
    required String usuario,
    required String equipo,
    required String autor,
  }) =>
      {
        'id_visita': idVisita,
        'rol': rol,
        'usuario': usuario,
        'equipo': equipo,
        'autor': autor,
      };

  Future<(bool, String)> enviarComentario({
    required String idVisita,
    required String rol,
    required String usuario,
    required String equipo,
    required String autor,
    required String mensaje,
  }) async {
    try {
      final json = await _api.postForm(AppConfig.visitaEnviarComentarios, {
        ..._base(idVisita: idVisita, rol: rol, usuario: usuario, equipo: equipo, autor: autor),
        'mensaje': mensaje,
      });
      return _result(json, 'Comentario enviado');
    } catch (_) {
      return (false, 'Error al enviar el comentario');
    }
  }

  Future<(bool, String)> enviarFotoBytes({
    required String idVisita,
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
        AppConfig.visitaEnviarFotos,
        fields: {
          ..._base(idVisita: idVisita, rol: rol, usuario: usuario, equipo: equipo, autor: autor),
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
    required String idVisita,
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
        AppConfig.visitaEnviarFotos,
        fields: {
          ..._base(idVisita: idVisita, rol: rol, usuario: usuario, equipo: equipo, autor: autor),
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
    required String idVisita,
    required String rol,
    required String usuario,
    required String equipo,
    required String autor,
    required String prioridad,
  }) async {
    try {
      final json = await _api.postForm(AppConfig.visitaCambiarPrioridad, {
        ..._base(idVisita: idVisita, rol: rol, usuario: usuario, equipo: equipo, autor: autor),
        'prioridad': prioridad,
      });
      return _result(json, 'Prioridad actualizada');
    } catch (_) {
      return (false, 'Error al cambiar la prioridad');
    }
  }

  Future<(bool, String)> cerrar({
    required String idVisita,
    required String rol,
    required String usuario,
    required String equipo,
    required String autor,
    required String accion, // 'finalizar' | 'cancelar'
    String motivo = '',
    String resumen = '',
  }) async {
    try {
      final json = await _api.postForm(AppConfig.visitaCerrar, {
        ..._base(idVisita: idVisita, rol: rol, usuario: usuario, equipo: equipo, autor: autor),
        'accion': accion,
        'motivo': motivo,
        'resumen_actuacion': resumen,
      });
      return _result(json, accion == 'finalizar' ? 'Visita finalizada' : 'Visita cancelada');
    } catch (_) {
      return (false, 'Error al cerrar la visita');
    }
  }
}
