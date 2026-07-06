import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/external_actions.dart';
import '../../data/models/pedido.dart';
import '../../data/repositories/incidencia_repository.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../data/repositories/visita_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../shell/detail_scaffold.dart';
import '../shell/nav_destinations.dart';
import 'pedido_controller.dart';

/// Detalle del pedido. Réplica de PedidoDetailActivity + content_pedido_detail.
class PedidoDetailScreen extends StatelessWidget {
  final String referencia;
  final String clienteHint;

  const PedidoDetailScreen({
    super.key,
    required this.referencia,
    this.clienteHint = '',
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => PedidoController(
        ctx.read<PedidoRepository>(),
        ctx.read<SessionService>(),
        ctx.read<VisitaRepository>(),
        ctx.read<IncidenciaRepository>(),
        referencia: referencia,
        clienteHint: clienteHint,
      )..init(),
      child: const _PedidoView(),
    );
  }
}

class _PedidoView extends StatefulWidget {
  const _PedidoView();

  @override
  State<_PedidoView> createState() => _PedidoViewState();
}

class _PedidoViewState extends State<_PedidoView> {
  final _comentarioCtrl = TextEditingController();

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _launch(Uri uri, String err) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _msg(err);
      }
    } catch (_) {
      _msg(err);
    }
  }

  /// Selector de teléfonos (Móvil/Fijo, con "Principal") cuando hay más de uno;
  /// si solo hay uno lo devuelve directamente. Réplica de `mostrarSelectorTelefono`.
  Future<String?> _pickPhone(PedidoController c) async {
    final phones = c.telefonos;
    if (phones.isEmpty) return null;
    if (phones.length == 1) return phones.first;
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Selecciona un teléfono',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            ),
            for (var i = 0; i < phones.length; i++)
              ListTile(
                leading: Icon(
                    c.phoneLabel(phones[i]) == 'Móvil'
                        ? Icons.smartphone
                        : Icons.call,
                    color: AppColors.primary),
                title: Text(phones[i]),
                subtitle: Text(c.phoneLabel(phones[i])),
                trailing: i == 0
                    ? const Text('Principal',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary))
                    : null,
                onTap: () => Navigator.pop(sheetCtx, phones[i]),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _callFlow(PedidoController c) async {
    if (c.telefonos.isEmpty) {
      _msg('Teléfono no disponible');
      return;
    }
    final tel = await _pickPhone(c);
    if (tel == null || !mounted) return;
    await _launch(Uri.parse('tel:${tel.trim()}'), 'No se pudo iniciar la llamada');
  }

  Future<void> _whatsappFlow(PedidoController c) async {
    if (c.telefonos.isEmpty) {
      _msg('WhatsApp no disponible');
      return;
    }
    final tel = await _pickPhone(c);
    if (tel == null || !mounted) return;
    final num = c.whatsappNumber(tel);
    if (num.isEmpty) {
      _msg('WhatsApp no disponible');
      return;
    }
    await _launch(Uri.parse('https://wa.me/$num'), 'No se pudo abrir WhatsApp');
  }

  Future<void> _guardarComentario(PedidoController c) async {
    final (ok, message) = await c.addComentario(_comentarioCtrl.text);
    if (ok) _comentarioCtrl.clear();
    _msg(message);
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      activeIndex: NavBranch.home,
      onReload: () => context.read<PedidoController>().load(),
      child: Consumer<PedidoController>(
        builder: (context, c, _) {
          if (c.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.pedido == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  c.errorMsg ?? 'No se pudo cargar el pedido',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return _content(c);
        },
      ),
    );
  }

  Widget _content(PedidoController c) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _hero(c),
        if (c.equipoTexto.isNotEmpty)
          _section('Equipo asignado', _bodyText(c.equipoTexto)),
        _section('Detalle del pedido', _detalleTable(c.detalleLineas)),
        if (c.observaciones.isNotEmpty)
          _section('Observaciones del cliente', _bodyText(c.observaciones)),
        _previasSection(c),
        _section('Comentarios del instalador', _comentarios(c)),
        _section('Fotografías', _fotos(c)),
        const SizedBox(height: 14),
        _bottomActions(),
      ],
    );
  }

  /// Secciones "Visitas previas" e "Incidencias previas" asociadas al pedido.
  Widget _previasSection(PedidoController c) {
    if (!c.previasCargadas) return const SizedBox.shrink();
    final children = <Widget>[];
    if (c.visitasPrevias.isNotEmpty) {
      children.add(_section(
        'Visitas previas',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Se han encontrado ${c.visitasPrevias.length} '
                'visita(s) previa(s) asociada(s) a esta referencia.',
                style: const TextStyle(color: Color(0xFF424242))),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => context.push('/visitas-previas', extra: {
                  'items': c.visitasPrevias,
                  'referencia': c.referencia,
                }),
                child: const Text('Ver detalles de la visita'),
              ),
            ),
          ],
        ),
      ));
    }
    if (c.incidenciasPrevias.isNotEmpty) {
      children.add(_section(
        'Incidencias previas',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Se han encontrado ${c.incidenciasPrevias.length} '
                'incidencia(s) previa(s) asociada(s) a esta referencia.',
                style: const TextStyle(color: Color(0xFF424242))),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => context.push('/incidencias-previas', extra: {
                  'items': c.incidenciasPrevias,
                  'referencia': c.referencia,
                }),
                child: const Text('Ver incidencias previas'),
              ),
            ),
          ],
        ),
      ));
    }
    return Column(children: children);
  }

  Widget _hero(PedidoController c) {
    return Container(
      decoration: AppDecorations.detailHero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ficha completa',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6D4C41))),
                    const SizedBox(height: 8),
                    Text(c.referencia,
                        style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                    if (c.cliente.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(c.cliente,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark)),
                      ),
                  ],
                ),
              ),
              if (c.fechaHora.isNotEmpty)
                Container(
                  decoration: AppDecorations.chipLight,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Text(c.fechaHora,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark)),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1, color: Color(0xFFF2D9C2)),
          ),
          const Text('Dirección de instalación',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark)),
          const SizedBox(height: 12),
          _contactRow(
            value: c.direccion.isNotEmpty ? c.direccion : 'Dirección no disponible',
            valueStyle: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF263238)),
            icon: Icons.map,
            onTap: () => ExternalActions.openMaps(context, c.direccion),
          ),
          const SizedBox(height: 10),
          _contactRow(
            value: c.telefonoPrincipal.isNotEmpty
                ? 'Teléfono: ${c.telefonoPrincipal}'
                : 'Teléfono no disponible',
            valueStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF37474F)),
            icon: Icons.call,
            onTap: () => _callFlow(c),
          ),
          const SizedBox(height: 10),
          _contactRow(
            value: c.telefonoPrincipal.isNotEmpty
                ? 'WhatsApp: ${c.telefonoPrincipal}'
                : 'WhatsApp no disponible',
            valueStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF37474F)),
            icon: Icons.send,
            onTap: () => _whatsappFlow(c),
          ),
        ],
      ),
    );
  }

  Widget _contactRow({
    required String value,
    required TextStyle valueStyle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: AppDecorations.addressHighlight,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(child: Text(value, style: valueStyle)),
          const SizedBox(width: 8),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 40,
              height: 40,
              decoration: AppDecorations.chipLight,
              child: Icon(icon, size: 20, color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: double.infinity,
        decoration: AppDecorations.whiteCard,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _bodyText(String text) => Text(
        text,
        style: const TextStyle(fontSize: 16, color: Color(0xFF424242), height: 1.4),
      );

  Widget _detalleTable(List<DetalleLinea> lineas) {
    Widget row(String c1, String c2, String c3, {bool header = false}) {
      final style = TextStyle(
        fontSize: header ? 13 : 14,
        fontWeight: header ? FontWeight.bold : FontWeight.normal,
        color: header ? AppColors.primaryDark : const Color(0xFF424242),
      );
      return Container(
        color: header ? AppColors.primaryLight : null,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: Text(c1, style: style)),
            Expanded(flex: 13, child: Text(c2, style: style)),
            Expanded(flex: 30, child: Text(c3, style: style)),
          ],
        ),
      );
    }

    return Column(
      children: [
        row('CTD', 'Código', 'Descripción', header: true),
        if (lineas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Sin artículos',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          )
        else
          for (final l in lineas)
            row(l.cantidad.isEmpty ? '0' : l.cantidad,
                l.referencia.isEmpty ? 'Sin datos' : l.referencia,
                l.nombre.isEmpty ? 'Sin datos' : l.nombre),
      ],
    );
  }

  Widget _comentarios(PedidoController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.comentariosTexto.isNotEmpty) ...[
          _bodyText(c.comentariosTexto),
          const SizedBox(height: 12),
        ],
        Container(
          decoration: AppDecorations.editText,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _comentarioCtrl,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(fontSize: 15, color: Color(0xFF424242)),
            decoration: const InputDecoration(
              hintText: 'Añadir comentario...',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed:
                c.savingComentario ? null : () => _guardarComentario(c),
            child: c.savingComentario
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white))
                : const Text('Guardar comentario'),
          ),
        ),
      ],
    );
  }

  Widget _fotos(PedidoController c) {
    final n = c.fotosClienteCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cliente',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF616161))),
        const SizedBox(height: 4),
        Text(
          n > 0 ? '$n foto${n == 1 ? '' : 's'} disponibles' : 'Sin fotos',
          style: const TextStyle(fontSize: 15, color: Color(0xFF424242)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () => context.push('/fotos', extra: {
              'titulo': 'Fotos del cliente',
              'referencia': c.referencia,
              'categoria': 'cliente',
              'clave': 'FOTOCLI',
            }),
            child: const Text('Ver fotos del cliente'),
          ),
        ),
      ],
    );
  }

  Widget _bottomActions() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final c = context.read<PedidoController>();
                    context.push('/install', extra: {
                      'referencia': c.referencia,
                      'cliente': c.cliente,
                    });
                  },
                  child: const Text('Realizar instalación'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primaryDark),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  child: const Text('Volver'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
