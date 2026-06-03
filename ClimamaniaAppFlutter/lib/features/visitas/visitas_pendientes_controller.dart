import 'package:flutter/foundation.dart';

import '../../data/models/gestion_item.dart';
import '../../data/repositories/visita_repository.dart';
import '../../services/session_service.dart';

class VisitasPendientesController extends ChangeNotifier {
  final VisitaRepository _repo;
  final SessionService _session;

  VisitasPendientesController(this._repo, this._session);

  bool loading = true;
  String? errorMsg;
  List<GestionItem> visitas = [];
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
    final (ok, list) = await _repo.getPendientes(
      rol: _session.rol,
      equipo: _session.readEquipo(),
      usuario: _session.usuarioForRequests,
    );
    if (_disposed) return;
    if (ok) {
      visitas = list;
    } else {
      errorMsg = 'No se pudieron cargar las visitas';
      visitas = [];
    }
    loading = false;
    notifyListeners();
  }
}
