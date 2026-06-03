import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/evento.dart';
import '../../data/repositories/home_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../shell/refresh_signal.dart';
import 'calendar_controller.dart';
import 'event_styles.dart';
import 'widgets/event_group_dialog.dart';
import 'widgets/week_grid.dart';

/// Pantalla de Calendario semanal. Réplica de CalendarActivity + content_calendar.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CalendarController(
        ctx.read<HomeRepository>(),
        ctx.read<SessionService>(),
      )..init(),
      child: const _CalendarView(),
    );
  }
}

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  RefreshSignal? _signal;
  CalendarController? _controller;
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    _signal = context.read<RefreshSignal>();
    _signal?.addListener(_onRefresh);
    _controller = context.read<CalendarController>();
    _controller?.addListener(_onControllerChange);
  }

  void _onRefresh() {
    if (mounted) context.read<CalendarController>().load();
  }

  // Muestra los errores de carga como aviso, sin ocultar la rejilla (como Android).
  void _onControllerChange() {
    final c = _controller;
    if (c == null) return;
    if (c.errorMsg != null && c.errorMsg != _lastShownError) {
      _lastShownError = c.errorMsg;
      final msg = c.errorMsg!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(msg)));
        }
      });
    } else if (c.errorMsg == null) {
      _lastShownError = null;
    }
  }

  @override
  void dispose() {
    _signal?.removeListener(_onRefresh);
    _controller?.removeListener(_onControllerChange);
    super.dispose();
  }

  void _openDetalle(Evento ev) {
    if (!EventStyles.isPedidoValido(ev.referencia)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Este evento no tiene pedido asociado')));
      return;
    }
    context.push('/pedido',
        extra: {'ref': ev.referencia, 'cliente': ev.nombreCliente});
  }

  void _openGrupo(List<Evento> group, String hora) {
    showEventGroupDialog(
      context,
      group: group,
      hora: hora,
      // El diálogo se cierra solo (en el navigator raíz); aquí solo navegamos.
      onDetail: _openDetalle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
      child: Consumer<CalendarController>(
        builder: (context, c, _) {
          return Column(
            children: [
              _header(c),
              _filters(c),
              Expanded(child: _body(c)),
            ],
          );
        },
      ),
    );
  }

  Widget _header(CalendarController c) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.primaryDark),
            onPressed: c.prevWeek,
            tooltip: 'Semana anterior',
          ),
          Expanded(
            child: Text(
              c.weekLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          GestureDetector(
            onTap: c.goToday,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.primaryDark),
              ),
              child: const Text('Hoy',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.primaryDark)),
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.chevron_right, color: AppColors.primaryDark),
            onPressed: c.nextWeek,
            tooltip: 'Semana siguiente',
          ),
        ],
      ),
    );
  }

  Widget _filters(CalendarController c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        children: [
          const Text('Filtros:',
              style: TextStyle(fontSize: 12, color: AppColors.primaryDark)),
          const SizedBox(width: 4),
          // Filtro de equipo
          Expanded(
            child: Opacity(
              opacity: c.isAdmin ? 1 : 0.7,
              child: GestureDetector(
                onTap: c.isAdmin ? () => _showEquipoDialog(c) : null,
                child: Container(
                  height: 32,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: AppDecorations.editText,
                  child: Text(
                    c.equipoFilterLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Filtro de estado
          Expanded(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: AppDecorations.editText,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  isDense: true,
                  value: c.filtroEstado,
                  style: const TextStyle(fontSize: 12, color: Colors.black),
                  items: [
                    for (final e in CalendarController.estadoOptions)
                      DropdownMenuItem(value: e, child: Text(e)),
                  ],
                  onChanged: (v) => c.setEstado(v ?? 'Todos los estados'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(CalendarController c) {
    if (c.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // La rejilla se muestra siempre; los errores salen como aviso (SnackBar).
    // En móvil hay scroll horizontal; el swipe de semana lo gestiona WeekGrid
    // solo cuando los 5 días caben (tablet/iPad).
    return WeekGrid(
      controller: c,
      onEventTap: _openDetalle,
      onGroupTap: _openGrupo,
      onPrevWeek: c.prevWeek,
      onNextWeek: c.nextWeek,
    );
  }

  void _showEquipoDialog(CalendarController c) {
    final temp = Set<String>.from(c.filtrosEquipos);
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Filtrar por equipos'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final code in CalendarController.equiposDisponibles)
                  CheckboxListTile(
                    dense: true,
                    title: Text(code),
                    value: temp.contains(code),
                    onChanged: (v) => setStateDialog(() {
                      if (v == true) {
                        temp.add(code);
                      } else {
                        temp.remove(code);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                c.clearEquipos();
                Navigator.of(ctx).pop();
              },
              child: const Text('Todos'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                c.filtrosEquipos
                  ..clear()
                  ..addAll(temp);
                c.setEstado(c.filtroEstado); // fuerza notify/redibujo
                Navigator.of(ctx).pop();
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }
}
