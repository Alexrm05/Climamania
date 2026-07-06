import 'package:flutter/foundation.dart';

import '../../data/models/visita_detalle.dart';
import '../../data/repositories/incidencia_repository.dart';
import '../../services/session_service.dart';

class IncidenciaDetalleController extends ChangeNotifier {
  final IncidenciaRepository _repo;
  final SessionService _session;
  final String idIncidencia;

  /// Referencia asociada (llega desde la lista/búsqueda y se actualiza con la
  /// que devuelve el servidor, para propagarla luego a "Gestionar incidencia").
  String referencia;

  IncidenciaDetalleController(
    this._repo,
    this._session,
    this.idIncidencia, {
    this.referencia = '',
  });

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
      idIncidencia,
      rol: _session.rol,
      equipo: _session.readEquipo(),
      usuario: _session.usuarioForRequests,
      referencia: referencia,
    );
    if (_disposed) return;
    if (res.ok && res.detalle != null) {
      detalle = res.detalle;
      final serverRef = res.detalle!.visita.referencia;
      if (serverRef.isNotEmpty) referencia = serverRef;
    } else {
      errorMsg =
          res.message.isEmpty ? 'No se pudo cargar la incidencia' : res.message;
    }
    loading = false;
    notifyListeners();
  }
}
