import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../data/models/evento.dart';
import '../../data/repositories/home_repository.dart';
import '../../services/session_service.dart';
import 'event_styles.dart';

class CalendarController extends ChangeNotifier {
  final HomeRepository _repo;
  final SessionService _session;

  CalendarController(this._repo, this._session);

  // Caché en memoria compartida (como la estática de CalendarActivity): render
  // inmediato desde caché + recarga en segundo plano. La clave incluye el
  // usuario para no mezclar datos entre cuentas del mismo rol/equipo.
  static final Map<String, List<Evento>> _cache = {};

  /// Vacía la caché de eventos. Debe llamarse al cerrar sesión para no filtrar
  /// los eventos de un usuario a otro que inicie sesión en el mismo proceso.
  static void clearCache() => _cache.clear();

  static const estadoOptions = <String>[
    'Todos los estados',
    'Solo finalizados',
    'Solo sin finalizar',
    'Solo eventos excepcionales',
    'Solo visitas',
  ];
  static const equiposDisponibles = <String>[
    'FCB', 'FCB2', 'JZ', 'JS', 'MA', 'CLM1',
  ];

  late DateTime weekStart; // lunes 00:00 de la semana mostrada
  List<Evento> _eventos = [];
  bool loading = true;
  String? errorMsg;

  bool isAdmin = false;
  String equipoFijoLabel = 'Todos los equipos';
  final Set<String> filtrosEquipos = {};
  String filtroEstado = 'Todos los estados';

  bool _disposed = false;

  void init() {
    isAdmin = _session.rol.toLowerCase() == 'adminclm';
    if (!isAdmin) {
      final eq = _session.readEquipo();
      equipoFijoLabel = (eq.isNotEmpty && eq != '0')
          ? 'Equipo $eq'
          : 'Equipo no asignado';
    }
    weekStart = _mondayOf(DateTime.now());
    load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  DateTime _mondayOf(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  Future<void> load() async {
    final key =
        '${_session.rol}|${_session.readEquipo()}|${_session.usuarioForRequests}';
    final cached = _cache[key];
    if (cached != null) {
      // Pintado inmediato desde caché; la recarga sigue en segundo plano.
      _eventos = cached;
      loading = false;
      errorMsg = null;
    } else {
      loading = true;
    }
    errorMsg = null;
    _notify();
    try {
      final resp = await _repo.getEvents(
        rol: _session.rol,
        equipo: _session.readEquipo(),
        usuario: _session.usuarioForRequests,
      );
      if (!resp.success) {
        // Si teníamos caché válida la conservamos; si no, mostramos el error.
        if (cached == null) {
          errorMsg =
              resp.message.isEmpty ? 'Error al cargar eventos' : resp.message;
          _eventos = [];
        }
      } else {
        _eventos = resp.eventos;
        _cache[key] = resp.eventos;
      }
    } catch (_) {
      if (cached == null) {
        errorMsg = 'Error de conexión al cargar eventos';
        _eventos = [];
      }
    }
    // Solo desarrollo: datos de muestra para previsualizar sin backend.
    if (_eventos.isEmpty && const bool.fromEnvironment('DEMO_EVENTS')) {
      _eventos = _demoEventos();
      errorMsg = null;
    }
    loading = false;
    _notify();
  }

  List<Evento> _demoEventos() {
    String p2(int n) => n.toString().padLeft(2, '0');
    String at(int dayOffset, int hour) {
      final d = weekStart.add(Duration(days: dayOffset));
      return '${d.year}-${p2(d.month)}-${p2(d.day)} ${p2(hour)}:00:00';
    }

    final raw = <Map<String, dynamic>>[
      {
        'start': at(0, 9), 'end': at(0, 12), 'referencia': 'PED-1001',
        'nombrecliente': 'Juan Pérez', 'equipo_instaladores': 'FCB',
        'direccion': 'Calle Mayor 1, Madrid', 'telefono': '600111222',
        'estado': 'Pendiente',
      },
      {
        'start': at(1, 10), 'end': at(1, 11), 'referencia': 'PED-1002',
        'nombrecliente': 'Ana López', 'equipo_instaladores': 'JZ',
        'direccion': 'Av. del Sol 22', 'telefono': '600333444',
        'estado': 'Finalizado',
      },
      {
        'start': at(2, 8), 'end': at(2, 9), 'referencia': 'PED-1003',
        'nombrecliente': 'Luis García', 'equipo_instaladores': 'FCB2',
        'direccion': 'C/ Luna 5', 'estado': 'Pendiente',
      },
      {
        'start': at(2, 8), 'end': at(2, 9), 'referencia': 'PED-1004',
        'nombrecliente': 'Marta Ruiz', 'equipo_instaladores': 'MA',
        'direccion': 'C/ Sol 9', 'estado': 'Pendiente',
      },
      {
        'start': at(2, 16), 'end': at(2, 18), 'referencia': 'VIS-22',
        'title': 'Visita técnica', 'nombrecliente': 'Pedro Sanz',
        'equipo_instaladores': 'JS', 'direccion': 'Plaza España 3',
        'telefono': '600555666', 'estado': 'Pendiente',
      },
    ];
    return raw.map(Evento.fromJson).toList();
  }

  void prevWeek() {
    weekStart = weekStart.subtract(const Duration(days: 7));
    _notify();
  }

  void nextWeek() {
    weekStart = weekStart.add(const Duration(days: 7));
    _notify();
  }

  void goToday() {
    weekStart = _mondayOf(DateTime.now());
    _notify();
  }

  void setEstado(String estado) {
    filtroEstado = estado;
    _notify();
  }

  void toggleEquipo(String code, bool on) {
    if (on) {
      filtrosEquipos.add(code);
    } else {
      filtrosEquipos.remove(code);
    }
    _notify();
  }

  void clearEquipos() {
    filtrosEquipos.clear();
    _notify();
  }

  String get equipoFilterLabel {
    if (!isAdmin) return equipoFijoLabel;
    if (filtrosEquipos.isEmpty) return 'Todos los equipos';
    return filtrosEquipos.join(', ');
  }

  String get weekLabel {
    final fmt = DateFormat('dd MMM yyyy', 'es');
    final end = weekStart.add(const Duration(days: 6));
    return '${fmt.format(weekStart)} - ${fmt.format(end)}';
  }

  DateTime dayDate(int index) => weekStart.add(Duration(days: index));

  /// Etiqueta de cabecera de día: "Lun - 8 jun".
  String dayHeaderLabel(int index) {
    final fmt = DateFormat('d MMM', 'es');
    return '${kDays[index]} - ${fmt.format(dayDate(index))}';
  }

  bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Eventos que pasan filtros y caen en la semana mostrada (Lun–Vie).
  List<Evento> get visibleEvents {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 5)); // exclusivo (Lun..Vie)
    return _eventos.where((ev) {
      final s = ev.startDate;
      if (s == null) return false;
      final day = DateTime(s.year, s.month, s.day);
      if (day.isBefore(start) || !day.isBefore(end)) return false;
      return _passesFilters(ev);
    }).toList();
  }

  bool _passesFilters(Evento ev) {
    // Filtro por equipo
    if (filtrosEquipos.isNotEmpty) {
      final eq = ev.equipoInstaladores.trim().toUpperCase();
      if (eq.isEmpty || !filtrosEquipos.contains(eq)) return false;
    }

    if (filtroEstado != 'Todos los estados') {
      final fin = EventStyles.esFinalizado(ev.estado);
      final pedidoValido = EventStyles.isPedidoValido(ev.referencia);
      final visita = EventStyles.esVisita(ev);

      switch (filtroEstado) {
        case 'Solo finalizados':
          if (!pedidoValido || !fin) return false;
          break;
        case 'Solo sin finalizar':
          if (!pedidoValido || fin) return false;
          break;
        case 'Solo eventos excepcionales':
          if (pedidoValido || visita) return false;
          break;
        case 'Solo visitas':
          if (!visita) return false;
          break;
      }
    }
    return true;
  }
}
