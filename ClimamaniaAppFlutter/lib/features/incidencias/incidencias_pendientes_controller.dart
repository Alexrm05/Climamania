import 'package:flutter/foundation.dart';

import '../../data/models/gestion_item.dart';
import '../../data/repositories/incidencia_repository.dart';
import '../../services/session_service.dart';

class IncidenciasPendientesController extends ChangeNotifier {
  final IncidenciaRepository _repo;
  final SessionService _session;

  IncidenciasPendientesController(this._repo, this._session);

  bool loading = true;
  String? errorMsg;
  List<GestionItem> incidencias = [];
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
    final res = await _repo.getPendientes(
      rol: _session.rol,
      equipo: _session.readEquipo(),
      usuario: _session.usuarioForRequests,
    );
    if (_disposed) return;
    if (res.ok) {
      incidencias = res.items;
    } else {
      errorMsg = res.message;
      incidencias = [];
    }
    loading = false;
    notifyListeners();
  }
}
