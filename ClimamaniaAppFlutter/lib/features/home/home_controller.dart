import 'package:flutter/foundation.dart';

import '../../core/ui_text.dart';
import '../../data/models/evento.dart';
import '../../data/repositories/home_repository.dart';
import '../../services/session_service.dart';

/// Datos de una tarjeta de instalación (en curso / próxima) con datos reales.
class InstallationData {
  final String referencia;
  final String cliente;
  final String direccionLimpia; // puede ser ""
  final String telefono; // puede ser ""
  final String whatsapp; // crudo
  final String direccionParaMapa;

  const InstallationData({
    required this.referencia,
    required this.cliente,
    required this.direccionLimpia,
    required this.telefono,
    required this.whatsapp,
    required this.direccionParaMapa,
  });
}

/// Estado de una tarjeta: o un mensaje simple (cargando/ninguna/error) o datos.
class CardState {
  final String? message;
  final InstallationData? data;

  const CardState.text(this.message) : data = null;
  const CardState.withData(this.data) : message = null;

  bool get hasData => data != null;
}

/// Controlador de la pantalla de Inicio. Porta la lógica de `MainActivity`:
/// las 3 llamadas (eventos, visitas, incidencias) y la selección
/// "en curso / próxima" en cliente.
class HomeController extends ChangeNotifier {
  final HomeRepository _repo;
  final SessionService _session;

  HomeController(this._repo, this._session);

  String greeting = 'instalador';

  String visitasText = 'Cargando visitas pendientes...';
  String incidenciasText = 'Cargando incidencias pendientes...';

  CardState enCurso = const CardState.text('Instalación en curso: cargando...');
  CardState proxima = const CardState.text('Próxima instalación: cargando...');

  bool _disposed = false;

  void init() {
    greeting = _session.displayName(fallback: 'instalador');
    load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    enCurso = const CardState.text('Instalación en curso: cargando...');
    proxima = const CardState.text('Próxima instalación: cargando...');
    visitasText = 'Cargando visitas pendientes...';
    incidenciasText = 'Cargando incidencias pendientes...';
    _safeNotify();

    await Future.wait([
      _loadEventos(),
      _loadVisitas(),
      _loadIncidencias(),
    ]);
  }

  String get _rol => _session.rol;
  String get _equipo => _session.readEquipo();
  String get _usuario => _session.usuarioForRequests;

  Future<void> _loadEventos() async {
    try {
      final resp = await _repo.getEvents(
        rol: _rol,
        equipo: _equipo,
        usuario: _usuario,
      );

      if (!resp.success) {
        final msg = resp.message.isEmpty ? 'sin datos' : resp.message;
        enCurso = CardState.text('Instalación en curso: $msg');
        proxima = CardState.text('Próxima instalación: $msg');
        _safeNotify();
        return;
      }
      if (resp.eventos.isEmpty) {
        enCurso = const CardState.text('Instalación en curso: ninguna');
        proxima = const CardState.text('Próxima instalación: ninguna');
        _safeNotify();
        return;
      }

      final now = DateTime.now();
      Evento? bestCurso;
      Evento? bestProxima;

      for (final e in resp.eventos) {
        final start = e.startDate;
        if (start == null) continue;
        final end = e.endDate ?? start.add(const Duration(hours: 1));

        final isEnCurso = !now.isBefore(start) && now.isBefore(end);
        final isFutura = start.isAfter(now);

        if (isEnCurso) {
          if (bestCurso == null || start.isBefore(bestCurso.startDate!)) {
            bestCurso = e;
          }
        } else if (isFutura) {
          if (bestProxima == null || start.isBefore(bestProxima.startDate!)) {
            bestProxima = e;
          }
        }
      }

      enCurso = _toCard(bestCurso, 'Instalación en curso: ninguna ahora mismo');
      proxima = _toCard(bestProxima, 'Próxima instalación: ninguna programada');
      _safeNotify();
    } on FormatException {
      enCurso =
          const CardState.text('Instalación en curso: error al leer datos');
      proxima =
          const CardState.text('Próxima instalación: error al leer datos');
      _safeNotify();
    } catch (_) {
      enCurso = const CardState.text(
        'Instalación en curso: No se pudieron cargar las instalaciones',
      );
      proxima = const CardState.text(
        'Próxima instalación: No se pudieron cargar las instalaciones',
      );
      _safeNotify();
    }
  }

  CardState _toCard(Evento? e, String emptyMsg) {
    if (e == null) return CardState.text(emptyMsg);
    final dirLimpia =
        e.direccion.isNotEmpty ? _limpiarDireccion(e.direccion) : '';
    final tel = e.telefono.trim();
    return CardState.withData(InstallationData(
      referencia: e.referencia.trim(),
      cliente: e.nombreCliente.trim(),
      direccionLimpia: dirLimpia,
      telefono: tel,
      whatsapp: e.whatsapp,
      direccionParaMapa: dirLimpia.isEmpty ? e.direccion : dirLimpia,
    ));
  }

  Future<void> _loadVisitas() async {
    try {
      final pc = await _repo.getVisitasPendientes(
        rol: _rol,
        equipo: _equipo,
        usuario: _usuario,
      );
      if (!pc.success || pc.pendientes <= 0) {
        visitasText = 'No tienes visitas pendientes de gestionar';
      } else {
        final n = pc.pendientes;
        visitasText =
            'Tienes $n visita${n == 1 ? '' : 's'} pendientes de gestionar';
      }
    } catch (_) {
      visitasText = 'Visitas pendientes no disponibles';
    }
    _safeNotify();
  }

  Future<void> _loadIncidencias() async {
    try {
      final pc = await _repo.getIncidenciasPendientes(
        rol: _rol,
        equipo: _equipo,
        usuario: _usuario,
      );
      if (!pc.success || pc.pendientes <= 0) {
        incidenciasText = 'No tienes incidencias pendientes de gestionar';
      } else {
        final n = pc.pendientes;
        incidenciasText =
            'Tienes $n incidencia${n == 1 ? '' : 's'} pendientes de gestionar';
      }
    } catch (_) {
      incidenciasText = 'Incidencias pendientes no disponibles';
    }
    _safeNotify();
  }

  /// Port de `limpiarDireccion` (ahora compartido en [UiText]).
  String _limpiarDireccion(String rawDireccion) =>
      UiText.limpiarDireccion(rawDireccion);
}
