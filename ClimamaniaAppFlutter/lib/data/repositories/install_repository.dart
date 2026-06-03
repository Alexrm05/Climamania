import 'dart:convert';

import '../../core/app_config.dart';
import '../../core/ui_text.dart';
import '../api/api_client.dart';

/// Línea de equipo para la revisión BOE.
class BoeLinea {
  String codigo;
  String numSerie;
  BoeLinea({this.codigo = '', this.numSerie = ''});
}

/// Endpoints del flujo de instalación (Fase 3).
class InstallRepository {
  final ApiClient _api;

  InstallRepository(this._api);

  String _s(dynamic v) => UiText.sanitizeDbValue(v?.toString());

  // --- BOE: equipos / revisión ---

  Future<({bool ok, String source, List<BoeLinea> lineas})> getBoeEquipos(
      String referencia) async {
    try {
      final json = await _api.getJson(
        AppConfig.getBoeEquipos,
        query: {'referencia': referencia},
        noCache: true,
      );
      final lineas = <BoeLinea>[];
      final raw = json['lineas'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            lineas.add(BoeLinea(
              codigo: _s(e['codigo']),
              numSerie: _s(e['num_serie']),
            ));
          }
        }
      }
      return (
        ok: json['success'] == true,
        source: _s(json['source']),
        lineas: lineas,
      );
    } catch (_) {
      return (ok: false, source: '', lineas: <BoeLinea>[]);
    }
  }

  Future<(bool, String)> guardarBoeEquipos({
    required String referencia,
    required String usuario,
    required List<BoeLinea> lineas,
  }) async {
    final arr = <Map<String, dynamic>>[];
    var orden = 1;
    for (final l in lineas) {
      if (l.codigo.trim().isEmpty) continue;
      arr.add({
        'orden_linea': orden++,
        'codigo': l.codigo.trim(),
        'num_serie': l.numSerie.trim(),
      });
    }
    if (arr.isEmpty) {
      return (false, 'Añade al menos un equipo con código');
    }
    try {
      final json = await _api.postForm(AppConfig.guardarBoeEquipos, {
        'referencia': referencia,
        'usuario': usuario,
        'lineas_json': jsonEncode(arr),
      });
      final ok = json['success'] == true;
      final msg = _s(json['message']);
      return (ok, ok ? (msg.isEmpty ? 'Revisión BOE guardada' : msg) : (msg.isEmpty ? 'No se pudo guardar' : msg));
    } catch (_) {
      return (false, 'Error de conexión al guardar la revisión BOE');
    }
  }

  // --- PDFs / documentación ---

  Future<({bool ok, String message, String pdfUrl, String token})>
      generarConformePdf(Map<String, String> payload) async {
    try {
      final json = await _api.postForm(AppConfig.generarConformePdf, payload);
      return (
        ok: json['success'] == true,
        message: _s(json['message']),
        pdfUrl: _s(json['pdf_url']),
        token: _s(json['submission_token']).isNotEmpty
            ? _s(json['submission_token'])
            : (payload['submission_token'] ?? ''),
      );
    } catch (_) {
      return (
        ok: false,
        message: 'Error de conexión al generar el PDF',
        pdfUrl: '',
        token: payload['submission_token'] ?? '',
      );
    }
  }

  Future<({bool ok, String message, String pdfUrl})> generarBoePdf(
      Map<String, String> payload) async {
    try {
      final json = await _api.postForm(AppConfig.generarBoePdf, payload);
      return (
        ok: json['success'] == true,
        message: _s(json['message']),
        pdfUrl: _s(json['pdf_url']),
      );
    } catch (_) {
      return (ok: false, message: 'Error al generar el PDF BOE', pdfUrl: '');
    }
  }

  Future<(bool, String)> enviarDocumentacion({
    required String referencia,
    required String token,
    required bool requiereBoe,
  }) async {
    try {
      final json = await _api.postForm(AppConfig.enviarDocumentacion, {
        'referencia': referencia,
        'submission_token': token,
        'requiere_boe': requiereBoe ? 'true' : 'false',
      });
      final ok = json['success'] == true;
      final msg = _s(json['message']);
      return (ok, msg.isEmpty ? (ok ? 'Documentación enviada' : 'No se pudo enviar') : msg);
    } catch (_) {
      return (false, 'Error al enviar la documentación');
    }
  }

  // --- Finalizar ---

  Future<(bool, String)> finalizar(Map<String, String> payload) async {
    try {
      final json = await _api.postForm(AppConfig.finalizarInstalacion, payload);
      final ok = json['success'] == true;
      final msg = _s(json['message']);
      return (ok, msg.isEmpty ? (ok ? 'Instalación finalizada' : 'No se pudo finalizar') : msg);
    } catch (_) {
      return (false, 'Error de conexión al finalizar');
    }
  }
}
