import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_config.dart';
import '../../../core/fecha.dart';
import '../../../core/priority.dart';
import '../../../core/widgets/meta_line.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/gestion_item.dart';
import '../../../data/models/visita_detalle.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_decorations.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';

/// Cuerpo compartido del detalle de una visita/incidencia: datos + historial
/// (muro) + ficheros. Mismo lenguaje visual que la tarjeta de instalación.
class GestionDetalleBody extends StatelessWidget {
  final GestionItem item;
  final List<MuroMensaje> muro;
  final List<Fichero> ficheros;
  final bool esIncidencia;
  final String gestionarLabel;
  final VoidCallback onGestionar;
  final Future<void> Function()? onRefresh;

  const GestionDetalleBody({
    super.key,
    required this.item,
    required this.muro,
    required this.ficheros,
    required this.esIncidencia,
    required this.gestionarLabel,
    required this.onGestionar,
    this.onRefresh,
  });

  IconData get _typeIcon =>
      esIncidencia ? Icons.report_problem_rounded : Icons.event_available_rounded;

  static String _titleCase(String s) => s
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  Color _tileTint(String p) => switch (p) {
        'Alta' => AppColors.errorTint,
        'Media' => AppColors.warningTint,
        _ => AppColors.surfaceWarm,
      };

  Color _tileFg(String p) => switch (p) {
        'Alta' => AppColors.errorFg,
        'Media' => AppColors.warningFg,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _datosCard(context),
        const SizedBox(height: AppSpacing.md),
        _muroCard(context),
        const SizedBox(height: AppSpacing.md),
        _ficherosCard(context),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(
        onRefresh: onRefresh!, color: AppColors.primary, child: list);
  }

  // ---- Datos ----
  Widget _datosCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = item;
    final prio = Prioridad.parse(v.prioridad);
    final dir = [
      if (v.direccion.isNotEmpty) v.direccion,
      if (v.poblacion.isNotEmpty) v.poblacion,
    ].join(', ');
    final ref = esIncidencia
        ? (v.referencia.isNotEmpty ? v.referencia : 'Incidencia #${v.id}')
        : 'Visita #${v.id}';
    final nombre = v.cliente.isNotEmpty ? _titleCase(v.cliente) : ref;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                esIncidencia ? 'Incidencia' : 'Visita',
                tone: esIncidencia ? BadgeTone.danger : BadgeTone.brand,
                icon: _typeIcon,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: AppDecorations.chipLight,
                child: Text(ref,
                    style:
                        t.labelMedium?.copyWith(color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tileTint(prio),
                  borderRadius: AppRadius.brMd,
                  border: Border.all(
                      color: _tileFg(prio).withValues(alpha: 0.22),
                      width: 1.5),
                ),
                child: Icon(_typeIcon, color: _tileFg(prio), size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleLarge),
                    if (prio != 'Sin prioridad') ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: PriorityBadge(prio)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(height: 1, width: double.infinity, color: AppColors.border),
          const SizedBox(height: AppSpacing.md),
          if (dir.isNotEmpty) _info(context, Icons.place_outlined, dir),
          if (v.telefono.isNotEmpty)
            _info(context, Icons.call_outlined, v.telefono),
          if (v.equipoId.isNotEmpty)
            _info(context, Icons.groups_outlined, 'Equipo ${v.equipoId}'),
          if (v.fechaSolicitud.isNotEmpty)
            _info(context, Icons.event_outlined,
                'Solicitada ${Fecha.parse(v.fechaSolicitud)}'),
          if (v.solicitante.isNotEmpty)
            _info(context, Icons.person_outline, 'Solicita ${v.solicitante}'),
          const SizedBox(height: AppSpacing.md),
          _gestionarButton(context),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String value) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(value,
                style: t.bodyMedium?.copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _gestionarButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: AppColors.primary,
        borderRadius: AppRadius.brPill,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onGestionar,
          borderRadius: AppRadius.brPill,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.handyman_outlined,
                    size: 18, color: AppColors.white),
                const SizedBox(width: AppSpacing.sm),
                Text(gestionarLabel,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: AppColors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Historial (muro) ----
  Widget _muroCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              esIncidencia
                  ? 'Historial de la incidencia'
                  : 'Historial de la visita',
              style: t.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (muro.isEmpty)
            _emptyRow(context, Icons.forum_outlined, 'Sin mensajes todavía')
          else
            for (int i = 0; i < muro.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              _muroItem(context, muro[i]),
            ],
        ],
      ),
    );
  }

  Widget _muroItem(BuildContext context, MuroMensaje m) {
    final t = Theme.of(context).textTheme;
    final meta = <String>[
      if (m.autor.isNotEmpty) m.autor,
      if (m.rol.isNotEmpty) m.rol,
      if (m.dateAdd.isNotEmpty) Fecha.parse(m.dateAdd),
    ];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.mensaje.isEmpty ? '—' : m.mensaje,
              style: t.bodyMedium?.copyWith(color: AppColors.textPrimary)),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            MetaLine(meta),
          ],
        ],
      ),
    );
  }

  // ---- Ficheros ----
  Widget _ficherosCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Ficheros', style: t.titleMedium),
              if (ficheros.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Text('${ficheros.length}',
                    style:
                        t.labelMedium?.copyWith(color: AppColors.textMuted)),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (ficheros.isEmpty)
            _emptyRow(context, Icons.folder_open_outlined, 'Sin ficheros')
          else
            for (int i = 0; i < ficheros.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              _ficheroItem(context, ficheros[i]),
            ],
        ],
      ),
    );
  }

  Widget _ficheroItem(BuildContext context, Fichero f) {
    final t = Theme.of(context).textTheme;
    final meta = <String>[
      if (f.tipoFichero.isNotEmpty) f.tipoFichero,
      if (f.usuario.isNotEmpty) f.usuario,
      if (f.dateAdd.isNotEmpty) Fecha.parse(f.dateAdd),
    ];
    final icon = f.isVideo
        ? Icons.play_circle_outline
        : (f.isImage ? Icons.image_outlined : Icons.description_outlined);
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openFichero(context, f),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (f.isImage)
                Image.network(
                  AppConfig.fotoUrl(f.ruta),
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 60,
                    alignment: Alignment.center,
                    color: AppColors.surfaceWarm,
                    child: Text('No se pudo cargar',
                        style: t.bodySmall
                            ?.copyWith(color: AppColors.textMuted)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(f.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleSmall),
                          if (meta.isNotEmpty) MetaLine(meta),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                        f.isVideo
                            ? Icons.play_arrow_rounded
                            : Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                        size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFichero(BuildContext context, Fichero f) {
    if (f.isVideo) {
      context.push('/video', extra: {'url': AppConfig.fotoUrl(f.ruta)});
    } else {
      context.push('/webview', extra: {'url': AppConfig.fotoUrl(f.ruta)});
    }
  }

  // ---- helpers ----
  Widget _card({required Widget child}) {
    return Container(
      decoration: AppDecorations.whiteCard,
      child: ClipRRect(
        borderRadius: AppRadius.brLg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      ),
    );
  }

  Widget _emptyRow(BuildContext context, IconData icon, String text) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Text(text,
            style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
      ],
    );
  }
}
