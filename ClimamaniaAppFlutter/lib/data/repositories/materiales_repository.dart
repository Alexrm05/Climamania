import 'dart:convert';

import '../../core/app_config.dart';
import '../../core/ui_text.dart';
import '../api/api_client.dart';
import '../models/parte_materiales.dart';

/// Escandallo: partes de trabajo con el material consumido en cada
/// instalación. El catálogo de artículos (categoría 711) se consulta con
/// [AdicionalesRepository.getCatalogo] pasando [AppConfig.categoriaMateriales].
class MaterialesRepository {
  final ApiClient _api;

  MaterialesRepository(this._api);

  String _s(dynamic v) => UiText.sanitizeDbValue(v?.toString());

  /// Parte del pedido (líneas guardadas, horas y materiales por defecto).
  /// Devuelve null si el servidor no responde o falla.
  Future<ParteMateriales?> getParte(String referencia) async {
    try {
      final json = await _api.getJson(
        AppConfig.getParteMateriales,
        query: {'referencia': referencia},
        noCache: true,
      );
      if (json['success'] != true) return null;
      return ParteMateriales.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Guarda el parte completo. Las coordenadas son opcionales: si la app no
  /// pudo obtenerlas, el parte se guarda igual y no se registra ubicación.
  Future<({bool ok, String message})> guardar({
    required String referencia,
    required String usuario,
    required String equipo,
    required String horaInicio,
    required String horaFinal,
    required List<MaterialLinea> lineas,
    String latitud = '',
    String longitud = '',
  }) async {
    try {
      final json = await _api.postForm(AppConfig.guardarParteMateriales, {
        'referencia': referencia,
        'usuario': usuario,
        'equipo': equipo,
        'hora_inicio': horaInicio,
        'hora_final': horaFinal,
        'latitud': latitud,
        'longitud': longitud,
        'lineas': jsonEncode([for (final l in lineas) l.toJson()]),
      });
      return (ok: json['success'] == true, message: _s(json['message']));
    } catch (_) {
      return (ok: false, message: 'Error de conexión al guardar el parte');
    }
  }

  /// Histórico y totales entre fechas (YYYY-MM-DD). El servidor limita al
  /// usuario salvo rol administrador.
  Future<PartesMateriales?> getPartes({
    required String usuario,
    required String rol,
    required String desde,
    required String hasta,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getPartesMateriales,
        query: {'usuario': usuario, 'rol': rol, 'desde': desde, 'hasta': hasta},
        noCache: true,
      );
      if (json['success'] != true) return null;
      return PartesMateriales.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
