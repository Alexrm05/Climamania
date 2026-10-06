import 'dart:convert';

import '../../core/app_config.dart';
import '../api/api_client.dart';
import '../models/consumible_tarifa.dart';

/// Tarifa de consumibles y pedidos del instalador. La tarifa es solo lectura
/// (la mantienen ClimaGEST y ClimaSINC) y se consulta cada vez: los precios
/// cambian y no se guardan en la app.
class ConsumiblesRepository {
  final ApiClient _api;

  ConsumiblesRepository(this._api);

  /// Artículos de la tarifa, ya ordenados por código. Lista vacía si falla.
  Future<List<ConsumibleTarifa>> getTarifa() async {
    try {
      final json = await _api.getJson(AppConfig.getTarifaConsumibles,
          noCache: true);
      if (json['success'] != true) return const [];
      final raw = json['articulos'];
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map) ConsumibleTarifa.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Pedidos que ya ha enviado el instalador. Solo consulta: una vez
  /// enviado, el pedido no se modifica desde la app.
  Future<List<PedidoEnviado>> getMisPedidos({
    required String usuario,
    required String rol,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getPedidosConsumibles,
        query: {'usuario': usuario, 'rol': rol},
        noCache: true,
      );
      if (json['success'] != true) return const [];
      final raw = json['pedidos'];
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map) PedidoEnviado.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Envía el pedido. El servidor recalcula los precios y responde con la
  /// referencia (PC-000123).
  Future<ResultadoPedidoConsumibles> pedir({
    required String usuario,
    required String equipo,
    required String email,
    required String observaciones,
    required List<LineaPedidoConsumible> lineas,
  }) async {
    try {
      final json = await _api.postForm(AppConfig.guardarPedidoConsumibles, {
        'usuario': usuario,
        'equipo': equipo,
        'email': email,
        'observaciones': observaciones,
        'lineas': jsonEncode([for (final l in lineas) l.toJson()]),
      });
      return ResultadoPedidoConsumibles.fromJson(json);
    } catch (_) {
      return const ResultadoPedidoConsumibles(
        ok: false,
        referencia: '',
        message: 'Error de conexión al enviar el pedido',
      );
    }
  }
}
