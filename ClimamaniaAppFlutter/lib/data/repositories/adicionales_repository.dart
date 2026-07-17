import '../../core/app_config.dart';
import '../../core/ui_text.dart';
import '../api/api_client.dart';
import '../models/catalogo.dart';
import '../models/presupuesto_detalle.dart';

class AdicionalesRepository {
  final ApiClient _api;

  AdicionalesRepository(this._api);

  String _s(dynamic v) => UiText.sanitizeDbValue(v?.toString());

  Future<List<CatalogProduct>> getCatalogo(String q) async {
    try {
      final json = await _api.getJson(
        AppConfig.getAdicionalesCatalogo,
        query: {'q': q, 'limit': '0'},
        noCache: true,
      );
      return _parseProductos(json);
    } catch (_) {
      return [];
    }
  }

  /// Los 5 artículos más usados (para acceso rápido bajo el buscador).
  Future<List<CatalogProduct>> getMasUsados() async {
    try {
      final json = await _api.getJson(
        AppConfig.getAdicionalesMasUsados,
        noCache: true,
      );
      return _parseProductos(json);
    } catch (_) {
      return [];
    }
  }

  List<CatalogProduct> _parseProductos(Map<String, dynamic> json) {
    if (json['success'] != true) return [];
    final out = <CatalogProduct>[];
    final raw = json['productos'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final p = CatalogProduct.fromJson(Map<String, dynamic>.from(e));
          if (p.idProduct > 0) out.add(p);
        }
      }
    }
    return out;
  }

  Future<({bool ok, String message, String idPresupuesto, String pdfUrl})>
      guardar(Map<String, String> payload) async {
    try {
      final json = await _api.postForm(AppConfig.guardarPresupuesto, payload);
      return (
        ok: json['success'] == true,
        message: _s(json['message']),
        idPresupuesto: _s(json['id_presupuesto']),
        pdfUrl: _s(json['pdf_url'].toString().isNotEmpty ? json['pdf_url'] : json['pdf']),
      );
    } catch (_) {
      return (
        ok: false,
        message: 'Error de conexión al guardar el presupuesto',
        idPresupuesto: '',
        pdfUrl: '',
      );
    }
  }

  Future<({bool ok, List<PresupuestoResumen> items, bool hasMore, List<String> estados})>
      getPresupuestos({
    required String rol,
    required String usuario,
    required String equipo,
    required String q,
    required String estado,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getPresupuestos,
        query: {
          'rol': rol,
          'usuario': usuario,
          'equipo': equipo,
          'q': q,
          'estado': estado,
          'page': '$page',
          'page_size': '$pageSize',
        },
        noCache: true,
      );
      if (json['success'] != true) {
        return (ok: false, items: <PresupuestoResumen>[], hasMore: false, estados: <String>[]);
      }
      final items = <PresupuestoResumen>[];
      if (json['presupuestos'] is List) {
        for (final e in json['presupuestos'] as List) {
          if (e is Map) {
            items.add(PresupuestoResumen.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }
      final estados = <String>[];
      if (json['estados_disponibles'] is List) {
        for (final e in json['estados_disponibles'] as List) {
          estados.add(e.toString());
        }
      }
      return (
        ok: true,
        items: items,
        hasMore: json['has_more'] == true,
        estados: estados,
      );
    } catch (_) {
      return (ok: false, items: <PresupuestoResumen>[], hasMore: false, estados: <String>[]);
    }
  }

  Future<({bool ok, String message, PresupuestoDetalle? detalle})> getDetalle(
    String id, {
    required String rol,
    required String usuario,
    required String equipo,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getPresupuestoDetalle,
        query: {
          'id_presupuesto': id,
          'rol': rol,
          'usuario': usuario,
          'equipo': equipo,
        },
        noCache: true,
      );
      final ok = json['success'] == true;
      final p = json['presupuesto'];
      if (!ok || p is! Map) {
        return (ok: false, message: _s(json['message']), detalle: null);
      }
      return (
        ok: true,
        message: '',
        detalle: PresupuestoDetalle.fromJson(json, Map<String, dynamic>.from(p)),
      );
    } catch (_) {
      return (ok: false, message: 'Error de conexión', detalle: null);
    }
  }

  Future<(bool, String)> cancelar(
    String id, {
    required String rol,
    required String usuario,
    required String equipo,
  }) async {
    try {
      final json = await _api.postForm(AppConfig.cancelarPresupuesto, {
        'id_presupuesto': id,
        'rol': rol,
        'usuario': usuario,
        'equipo': equipo,
      });
      final ok = json['success'] == true;
      final msg = _s(json['message']);
      return (ok, msg.isEmpty ? (ok ? 'Presupuesto cancelado' : 'No se pudo cancelar') : msg);
    } catch (_) {
      return (false, 'Error al cancelar el presupuesto');
    }
  }
}
