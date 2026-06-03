import '../../core/app_config.dart';
import '../../core/ui_text.dart';
import '../api/api_client.dart';
import '../models/pedido.dart';

class PedidoRepository {
  final ApiClient _api;

  PedidoRepository(this._api);

  /// Carga la ficha del pedido por referencia (get_pedido.php).
  Future<({bool ok, String message, Pedido? pedido})> getPedido(
      String referencia) async {
    final json = await _api.getJson(
      AppConfig.getPedido,
      query: {'referencia': referencia},
    );
    final ok = json['success'] == true;
    final message = UiText.sanitizeDbValue(json['message']?.toString());
    Pedido? pedido;
    final raw = json['pedido'];
    if (raw is Map) {
      pedido = Pedido.fromJson(Map<String, dynamic>.from(raw));
    }
    return (ok: ok, message: message, pedido: pedido);
  }

  /// Añade un comentario del instalador (add_comentario.php).
  Future<(bool, String)> addComentario({
    required String referencia,
    required String usuario,
    required String texto,
  }) async {
    try {
      final json = await _api.postForm(AppConfig.addComentario, {
        'referencia': referencia,
        'usuario': usuario,
        'texto': texto,
      });
      final ok = json['success'] == true;
      final msg = UiText.sanitizeDbValue(json['message']?.toString());
      return (ok, msg);
    } catch (_) {
      return (false, 'Error de conexión al guardar el comentario');
    }
  }
}
