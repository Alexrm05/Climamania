import 'package:flutter/foundation.dart';

import '../../data/models/visita_detalle.dart';
import '../../data/repositories/visita_repository.dart';
import '../../services/session_service.dart';

class VisitaDetalleController extends ChangeNotifier {
  final VisitaRepository _repo;
  final SessionService _session;
  final String idVisita;

  VisitaDetalleController(this._repo, this._session, this.idVisita);

  bool loading = true;
  String? errorMsg;
  VisitaDetalle? detalle;
  bool _disposed = false;

  void init() => load();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    loading = true;
    errorMsg = null;
    if (!_disposed) notifyListeners();
    final res = await _repo.getDetalle(
      idVisita,
      rol: _session.rol,
      equipo: _session.readEquipo(),
      usuario: _session.usuarioForRequests,
    );
    if (_disposed) return;
    if (res.ok && res.detalle != null) {
      detalle = res.detalle;
    } else {
      errorMsg = res.message.isEmpty
          ? 'No se pudo cargar la visita'
          : res.message;
    }
    loading = false;
    notifyListeners();
  }
}
