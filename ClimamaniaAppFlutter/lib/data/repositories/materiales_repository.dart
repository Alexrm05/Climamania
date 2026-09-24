import 'dart:convert';

import '../../core/app_config.dart';
import '../../core/ui_text.dart';
import '../api/api_client.dart';
import '../models/parte_materiales.dart';

/// Escandallo: partes de trabajo con el material consumido en cada
/// instalación, y catálogo de materiales
/// (ClimaSinc_ClimaInstal_Consumibles, sincronizada desde PrestaShop).
class MaterialesRepository {
  final ApiClient _api;

  MaterialesRepository(this._api);

  String _s(dynamic v) => UiText.sanitizeDbValue(v?.toString());

  /// Busca materiales por referencia o descripción. Con [q] vacío devuelve
  /// los más usados. Lista vacía si el servidor falla.
  Future<List<MaterialCatalogo>> buscarMateriales(String q) async {
    try {
      final json = await _api.getJson(
        AppConfig.getMaterialesCatalogo,
        query: {'q': q, if (q.isEmpty) 'mas_usados': '1'},
        noCache: true,
      );
      if (json['success'] != true) return const [];
      final raw = json['materiales'];
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map) MaterialCatalogo.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Parte del pedido (líneas guardadas, horas y materiales por defecto).
  /// [padres] son las referencias del pedido con su cantidad ("INSTAL40:2"):
  /// el servidor cruza con ellas los materiales por defecto. Si no se pasan,
  /// las lee él de PrestaShop. Devuelve null si el servidor falla.
  Future<ParteMateriales?> getParte(String referencia,
      {List<String> padres = const []}) async {
    try {
      final json = await _api.getJson(
        AppConfig.getParteMateriales,
        query: {
          'referencia': referencia,
          if (padres.isNotEmpty) 'padres': padres.join(','),
        },
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
