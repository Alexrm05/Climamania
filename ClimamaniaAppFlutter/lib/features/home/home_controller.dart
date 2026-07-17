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
  final String cuando; // "15:00 - 18:00" o "16 jul · 15:00" (puede ser "")
  final String equipo; // equipo que la realiza (puede ser "")

  const InstallationData({
    required this.referencia,
    required this.cliente,
    required this.direccionLimpia,
    required this.telefono,
    required this.whatsapp,
    required this.direccionParaMapa,
    this.cuando = '',
    this.equipo = '',
  });
}

/// Estado de una tarjeta: cargando, un mensaje simple (ninguna/error) o datos.
class CardState {
  final String? message;
  final InstallationData? data;
  final bool loading;

  const CardState.text(this.message)
      : data = null,
        loading = false;
  const CardState.withData(this.data)
      : message = null,
        loading = false;
  const CardState.loading()
      : message = null,
        data = null,
        loading = true;

  bool get hasData => data != null;
  bool get isLoading => loading;
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

  // Contadores para las tarjetas de resumen (-1 = cargando).
  int visitasCount = -1;
  int incidenciasCount = -1;
  bool visitasError = false;
  bool incidenciasError = false;

  // Puede haber varias instalaciones en curso en paralelo (sobre todo para el
  // admin, que ve todos los equipos): una tarjeta por cada una.
  List<CardState> enCurso = const [CardState.loading()];
  CardState proxima = const CardState.loading();

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
    enCurso = const [CardState.loading()];
    proxima = const CardState.loading();
    visitasText = 'Cargando visitas pendientes...';
    incidenciasText = 'Cargando incidencias pendientes...';
    visitasCount = -1;
    incidenciasCount = -1;
    visitasError = false;
    incidenciasError = false;
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
        enCurso = [CardState.text('Instalación en curso: $msg')];
        proxima = CardState.text('Próxima instalación: $msg');
        _safeNotify();
        return;
      }
      if (resp.eventos.isEmpty) {
        enCurso = const [CardState.text('Instalación en curso: ninguna')];
        proxima = const CardState.text('Próxima instalación: ninguna');
        _safeNotify();
        return;
      }

      final now = DateTime.now();
      // Todas las instalaciones en curso a la vez (pueden ser varias en
      // paralelo, de equipos distintos). Y la próxima más cercana.
      final enCursoEventos = <Evento>[];
      Evento? bestProxima;

      for (final e in resp.eventos) {
        final start = e.startDate;
        if (start == null) continue;
        final end = e.endDate ?? start.add(const Duration(hours: 1));

        final isEnCurso = !now.isBefore(start) && now.isBefore(end);
        final isFutura = start.isAfter(now);

        if (isEnCurso) {
          enCursoEventos.add(e);
        } else if (isFutura) {
          if (bestProxima == null || start.isBefore(bestProxima.startDate!)) {
            bestProxima = e;
          }
        }
      }

      // Orden estable: por hora de inicio y luego por equipo.
      enCursoEventos.sort((a, b) {
        final byStart = a.startDate!.compareTo(b.startDate!);
        if (byStart != 0) return byStart;
        return a.equipoInstaladores.compareTo(b.equipoInstaladores);
      });

      enCurso = enCursoEventos.isEmpty
          ? const [CardState.text('Instalación en curso: ninguna ahora mismo')]
          : [for (final e in enCursoEventos) CardState.withData(_dataOf(e))];
      proxima = _toCard(bestProxima, 'Próxima instalación: ninguna programada');
      _safeNotify();
    } on FormatException {
      enCurso =
          const [CardState.text('Instalación en curso: error al leer datos')];
      proxima =
          const CardState.text('Próxima instalación: error al leer datos');
      _safeNotify();
    } catch (_) {
      enCurso = const [
        CardState.text(
            'Instalación en curso: No se pudieron cargar las instalaciones'),
      ];
      proxima = const CardState.text(
        'Próxima instalación: No se pudieron cargar las instalaciones',
      );
      _safeNotify();
    }
  }

  CardState _toCard(Evento? e, String emptyMsg) =>
      e == null ? CardState.text(emptyMsg) : CardState.withData(_dataOf(e));

  InstallationData _dataOf(Evento e) {
    final dirLimpia =
        e.direccion.isNotEmpty ? _limpiarDireccion(e.direccion) : '';
    final tel = e.telefono.trim();
    return InstallationData(
      referencia: e.referencia.trim(),
      cliente: e.nombreCliente.trim(),
      direccionLimpia: dirLimpia,
      telefono: tel,
      whatsapp: e.whatsapp,
      direccionParaMapa: dirLimpia.isEmpty ? e.direccion : dirLimpia,
      cuando: _formatCuando(e.startDate, e.endDate),
      equipo: e.equipoInstaladores.trim(),
    );
  }

  /// Franja horaria de la instalación: "15:00 - 18:00" si es hoy,
  /// o "16 jul · 15:00" si es otro día. "" si no hay fecha.
  static String _formatCuando(DateTime? start, DateTime? end) {
    if (start == null) return '';
    String hhmm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final esHoy =
        start.year == now.year && start.month == now.month && start.day == now.day;
    final hora = end != null ? '${hhmm(start)} - ${hhmm(end)}' : hhmm(start);
    if (esHoy) return hora;
    const meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${start.day} ${meses[start.month - 1]} · $hora';
  }

  Future<void> _loadVisitas() async {
    try {
      final pc = await _repo.getVisitasPendientes(
        rol: _rol,
        equipo: _equipo,
        usuario: _usuario,
      );
      if (!pc.success || pc.pendientes <= 0) {
        visitasCount = 0;
        visitasText = 'No tienes visitas pendientes de gestionar';
      } else {
        final n = pc.pendientes;
        visitasCount = n;
        visitasText =
            'Tienes $n visita${n == 1 ? '' : 's'} pendientes de gestionar';
      }
    } catch (_) {
      visitasError = true;
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
        incidenciasCount = 0;
        incidenciasText = 'No tienes incidencias pendientes de gestionar';
      } else {
        final n = pc.pendientes;
        incidenciasCount = n;
        incidenciasText =
            'Tienes $n incidencia${n == 1 ? '' : 's'} pendientes de gestionar';
      }
    } catch (_) {
      incidenciasError = true;
      incidenciasText = 'Incidencias pendientes no disponibles';
    }
    _safeNotify();
  }

  /// Port de `limpiarDireccion` (ahora compartido en [UiText]).
  String _limpiarDireccion(String rawDireccion) =>
      UiText.limpiarDireccion(rawDireccion);
}
