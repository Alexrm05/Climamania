import 'package:flutter/material.dart';
import '../../../core/ui_text.dart';
import '../../../data/models/evento.dart';
import '../../../theme/app_colors.dart';
import '../event_styles.dart';

/// Diálogo que lista todos los eventos de una franja agrupada
/// (réplica de dialog_events_group + item_event_group_row).
Future<void> showEventGroupDialog(
  BuildContext context, {
  required List<Evento> group,
  required String hora,
  required void Function(Evento) onDetail,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '$hora · ${group.length} eventos',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                itemCount: group.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _GroupRow(
                  ev: group[i],
                  // Cerramos el diálogo en SU navigator (el raíz, donde lo
                  // empujó showDialog) y luego dejamos que el llamador navegue.
                  // Hacerlo con `ctx` evita cerrar el navigator de la rama del
                  // shell (que dejaría el calendario en negro).
                  onDetail: () {
                    Navigator.of(ctx).pop();
                    onDetail(group[i]);
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.errorFg),
                  child: const Text('Cerrar'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GroupRow extends StatelessWidget {
  final Evento ev;
  final VoidCallback onDetail;

  const _GroupRow({required this.ev, required this.onDetail});

  @override
  Widget build(BuildContext context) {
    final pedido = UiText.sanitizeDbValue(ev.referencia);
    final cliente = UiText.sanitizeDbValue(ev.nombreCliente);
    var titulo = pedido;
    if (cliente.isNotEmpty) {
      titulo = titulo.isEmpty ? cliente : '$titulo · $cliente';
    }
    if (ev.equipoInstaladores.isNotEmpty) {
      titulo += ' (Eq. ${ev.equipoInstaladores})';
    }

    final dir = EventStyles.formatDireccion(ev.direccion);
    final tel = UiText.sanitizeDbValue(ev.telefono);
    final wa = UiText.sanitizeDbValue(ev.whatsapp);
    final info = <String>[
      if (dir.isNotEmpty) 'Dirección: $dir',
      if (tel.isNotEmpty) 'Teléfono: $tel',
      if (wa.isNotEmpty) 'WhatsApp: $wa',
    ].join('\n');

    final pedidoValido = EventStyles.isPedidoValido(ev.referencia);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
                width: 5,
                color: EventStyles.readable(EventStyles.forEvento(ev))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo.trim().isEmpty ? 'Sin título' : titulo.trim(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: titulo.trim().isEmpty
                            ? AppColors.placeholder
                            : AppColors.primaryDark,
                        fontStyle: titulo.trim().isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.isEmpty ? 'Datos de contacto no disponibles' : info,
                      style: info.isEmpty
                          ? UiText.placeholderStyle
                          : const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: pedidoValido
                          ? ElevatedButton(
                              onPressed: onDetail,
                              style: ElevatedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Detalle'),
                            )
                          : const Text('Sin pedido',
                              style: TextStyle(color: AppColors.placeholder)),
                    ),
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
