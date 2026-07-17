import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/evento.dart';
import '../../data/repositories/home_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
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
    if (EventStyles.esIncidencia(ev)) {
      context.push('/incidencias');
      return;
    }
    if (EventStyles.esVisita(ev)) {
      context.push('/visitas');
      return;
    }
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
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      child: Row(
        children: [
          _navBtn(Icons.chevron_left_rounded, c.prevWeek, 'Semana anterior'),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              c.weekLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _navBtn(Icons.chevron_right_rounded, c.nextWeek, 'Semana siguiente'),
          const SizedBox(width: AppSpacing.sm),
          // Botón "Hoy" como píldora con tinte de marca.
          Material(
            color: AppColors.footerActiveBg,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.brPill,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.30)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: c.goToday,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                child: Text('Hoy',
                    style: t.labelLarge?.copyWith(color: AppColors.primary)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap, String tooltip) {
    return Material(
      color: AppColors.surfaceWarm,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, color: AppColors.primaryDark, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _filters(CalendarController c) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Row(
        children: [
          // Filtro de equipo (solo admin)
          Expanded(
            child: Opacity(
              opacity: c.isAdmin ? 1 : 0.55,
              child: _filterChip(
                icon: Icons.groups_outlined,
                label: c.equipoFilterLabel,
                onTap: c.isAdmin ? () => _showEquipoDialog(c) : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Filtro de estado
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.brPill,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        isDense: true,
                        value: c.filtroEstado,
                        icon: const Icon(Icons.expand_more,
                            size: 18, color: AppColors.textMuted),
                        style: t.labelLarge
                            ?.copyWith(color: AppColors.textPrimary),
                        // El valor cerrado en una sola línea con ellipsis.
                        selectedItemBuilder: (context) => [
                          for (final e in CalendarController.estadoOptions)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(e,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        items: [
                          for (final e in CalendarController.estadoOptions)
                            DropdownMenuItem(value: e, child: Text(e)),
                        ],
                        onChanged: (v) =>
                            c.setEstado(v ?? 'Todos los estados'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
      {required IconData icon, required String label, VoidCallback? onTap}) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brPill,
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        t.labelLarge?.copyWith(color: AppColors.textPrimary)),
              ),
              if (onTap != null)
                const Icon(Icons.expand_more,
                    size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(CalendarController c) {
    if (c.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // La rejilla se muestra siempre; los errores salen como aviso (SnackBar).
    // En móvil hay scroll horizontal; el swipe de semana lo gestiona WeekGrid
    // solo cuando los 7 días caben (tablet/iPad).
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
              style: TextButton.styleFrom(foregroundColor: AppColors.errorFg),
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
              style: AppDecorations.greenButton,
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }
}
