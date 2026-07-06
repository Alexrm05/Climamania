import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../data/models/evento.dart';
import '../../../theme/app_colors.dart';
import '../calendar_controller.dart';
import '../event_styles.dart';

const double _hourColW = 34;
const double _rowH = 70;
const double _headerH = 46;
// Ancho mínimo cómodo por día: evita que el texto se amontone en móvil.
// Si los 5 días no caben, la rejilla se desplaza horizontalmente.
const double _minDayColW = 120;
const Color _gridLine = Color(0xFFE0E0E0);

/// Rejilla semanal del calendario: cabecera de días + filas horarias y los
/// eventos posicionados encima (tarjeta individual o bloque agrupado).
class WeekGrid extends StatelessWidget {
  final CalendarController controller;
  final void Function(Evento) onEventTap;
  final void Function(List<Evento> group, String hora) onGroupTap;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;

  const WeekGrid({
    super.key,
    required this.controller,
    required this.onEventTap,
    required this.onGroupTap,
    required this.onPrevWeek,
    required this.onNextWeek,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fitW = (constraints.maxWidth - _hourColW) / kDays.length;
        final dayColW = math.max(fitW, _minDayColW);
        final gridW = _hourColW + dayColW * kDays.length;
        final totalH = _headerH + _rowH * kHours.length;
        final needsHScroll = gridW > constraints.maxWidth + 0.5;

        final grid = SizedBox(
          width: gridW,
          height: totalH,
          child: Stack(
            children: [
              _buildBackground(dayColW),
              ..._buildEvents(dayColW),
            ],
          ),
        );

        final verticalScroll = SingleChildScrollView(child: grid);

        // Cabe a lo ancho (tablet/iPad): swipe lateral cambia de semana.
        if (!needsHScroll) {
          return GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -120) {
                onNextWeek();
              } else if (v > 120) {
                onPrevWeek();
              }
            },
            child: verticalScroll,
          );
        }

        // Pantalla estrecha (móvil): scroll horizontal para ver los 5 días.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: gridW,
            height: constraints.maxHeight,
            child: verticalScroll,
          ),
        );
      },
    );
  }

  Widget _buildBackground(double dayColW) {
    return Column(
      children: [
        // Cabecera de días
        SizedBox(
          height: _headerH,
          child: Row(
            children: [
              _headerCell('', _hourColW, hourCol: true),
              for (var i = 0; i < kDays.length; i++)
                _headerCell(
                  controller.dayHeaderLabel(i),
                  dayColW,
                  today: controller.isToday(controller.dayDate(i)),
                ),
            ],
          ),
        ),
        // Filas horarias
        for (final h in kHours)
          SizedBox(
            height: _rowH,
            child: Row(
              children: [
                _hourCell(h),
                for (var i = 0; i < kDays.length; i++)
                  _bodyCell(dayColW),
              ],
            ),
          ),
      ],
    );
  }

  Widget _headerCell(String text, double width,
      {bool hourCol = false, bool today = false}) {
    return Container(
      width: width,
      height: _headerH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: today
            ? const Color(0xFFFFF3E0)
            : (hourCol ? const Color(0xFFFAFAFA) : AppColors.primaryLight),
        border: Border.all(color: _gridLine, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: today ? const Color(0xFFBF360C) : AppColors.primaryDark,
        ),
      ),
    );
  }

  Widget _hourCell(String text) {
    return Container(
      width: _hourColW,
      height: _rowH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        border: Border.all(color: _gridLine, width: 0.5),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
      ),
    );
  }

  Widget _bodyCell(double width) {
    return Container(
      width: width,
      height: _rowH,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: _gridLine, width: 0.5),
      ),
    );
  }

  List<Widget> _buildEvents(double dayColW) {
    // Agrupar por (columna de día, franja de inicio)
    final groups = <String, List<Evento>>{};
    final groupDayCol = <String, int>{};
    final groupStart = <String, int>{};

    for (final ev in controller.visibleEvents) {
      final si = _startIndex(ev);
      final dc = _dayCol(ev);
      if (si == null || dc == null) continue;
      final key = '${dc}_$si';
      groups.putIfAbsent(key, () => []).add(ev);
      groupDayCol[key] = dc;
      groupStart[key] = si;
    }

    final widgets = <Widget>[];
    groups.forEach((key, list) {
      if (list.isEmpty) return;
      final dayCol = groupDayCol[key]!;
      final startIndex = groupStart[key]!;
      var duration = 1;
      for (final ev in list) {
        final d = _duration(ev);
        if (d > duration) duration = d;
      }

      final left = _hourColW + (dayCol - 1) * dayColW + 6;
      final top = _headerH + startIndex * _rowH + 4;
      final width = dayColW - 12;
      final height = duration * _rowH - 8;

      widgets.add(Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: list.length == 1
            ? _EventCard(
                ev: list.first,
                startIndex: startIndex,
                duration: duration,
                today: controller.isToday(_dayOnly(list.first.startDate!)),
                onTap: () => onEventTap(list.first),
              )
            : _GroupCard(
                group: list,
                startIndex: startIndex,
                duration: duration,
                today: controller.isToday(_dayOnly(list.first.startDate!)),
                onTap: () => onGroupTap(
                  list,
                  EventStyles.horaPrevista(startIndex, duration),
                ),
              ),
      ));
    });

    return widgets;
  }

  // --- Helpers de geometría ---

  int? _startIndex(Evento ev) {
    final s = ev.startDate;
    if (s == null) return null;
    final idx = s.hour - 8;
    if (idx < 0 || idx >= kHours.length) return null;
    return idx;
  }

  int _duration(Evento ev) {
    final s = ev.startDate!;
    final e = ev.endDate ?? s.add(const Duration(hours: 1));
    var d = e.hour - s.hour;
    if (d < 1) d = 1;
    final idx = s.hour - 8;
    if (idx + d > kHours.length) d = kHours.length - idx;
    return d;
  }

  int? _dayCol(Evento ev) {
    final s = ev.startDate;
    if (s == null) return null;
    final day = _dayOnly(s);
    final start = DateTime(
        controller.weekStart.year, controller.weekStart.month, controller.weekStart.day);
    final diff = day.difference(start).inDays;
    if (diff < 0 || diff > 4) return null;
    return diff + 1;
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// Tarjeta de un evento individual.
class _EventCard extends StatelessWidget {
  final Evento ev;
  final int startIndex;
  final int duration;
  final bool today;
  final VoidCallback onTap;

  const _EventCard({
    required this.ev,
    required this.startIndex,
    required this.duration,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = EventStyles.forEvento(ev);
    final hora = EventStyles.horaPrevista(startIndex, duration);
    final dir = EventStyles.formatDireccion(ev.direccion);
    final pedidoValido = EventStyles.isPedidoValido(ev.referencia);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: EventStyles.bgForEvento(ev, alpha: 80),
          borderRadius: BorderRadius.circular(8),
          border: today
              ? Border.all(color: const Color(0xFF1976D2), width: 2)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: color),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pedidoValido) _estadoChip(ev.estado),
                    Text(hora,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    if (ev.referencia.trim().isNotEmpty)
                      Text(ev.referencia.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                    if (ev.nombreCliente.trim().isNotEmpty)
                      Text(ev.nombreCliente.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black)),
                    Text(
                      ev.equipoInstaladores.isNotEmpty
                          ? 'Equipo ${ev.equipoInstaladores}'
                          : 'Equipo n/d',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: EventStyles.forEquipo(ev.equipoInstaladores)),
                    ),
                    if (dir.isNotEmpty)
                      Text(dir,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF263238))),
                    if (ev.telefono.trim().isNotEmpty)
                      Text('Tel. ${ev.telefono.trim()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF263238))),
                    if (ev.whatsapp.trim().isNotEmpty)
                      Text('WhatsApp: ${ev.whatsapp.trim()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF263238))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _estadoChip(String? estado) {
  return Container(
    margin: const EdgeInsets.only(bottom: 2),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: EventStyles.estadoColor(estado),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      EventStyles.estadoLabel(estado),
      style: const TextStyle(
          fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
    ),
  );
}

/// Bloque que agrupa varios eventos en la misma franja.
class _GroupCard extends StatelessWidget {
  final List<Evento> group;
  final int startIndex;
  final int duration;
  final bool today;
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.startIndex,
    required this.duration,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final first = group.first;
    final color = EventStyles.forEvento(first);
    final hora = EventStyles.horaPrevista(startIndex, duration);
    const maxVisible = 2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: EventStyles.bgForEvento(first, alpha: 140),
          borderRadius: BorderRadius.circular(8),
          border: today
              ? Border.all(color: const Color(0xFF1976D2), width: 2)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: color),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hora,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E))),
                    Text('${group.length} eventos',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF455A64))),
                    for (final ev in group.take(maxVisible))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ${ev.referencia.trim()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF212121))),
                            if (ev.nombreCliente.trim().isNotEmpty)
                              Text(ev.nombreCliente.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF212121))),
                            Text(
                              ev.equipoInstaladores.isNotEmpty
                                  ? 'Equipo ${ev.equipoInstaladores}'
                                  : 'Equipo n/d',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: EventStyles.forEquipo(
                                      ev.equipoInstaladores)),
                            ),
                          ],
                        ),
                      ),
                    if (group.length > maxVisible)
                      Text('+ ${group.length - maxVisible} eventos más',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF455A64))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
