import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/status_badge.dart';
import '../../data/models/pedido.dart';
import '../../data/models/retirada_equipo.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

String _titleCase(String s) => s
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

/// Hub del flujo "Realizar instalación". Réplica de InstallActivity.
class InstallScreen extends StatefulWidget {
  final String referencia;
  final String cliente;

  const InstallScreen({super.key, required this.referencia, this.cliente = ''});

  @override
  State<InstallScreen> createState() => _InstallScreenState();
}

class _InstallScreenState extends State<InstallScreen> {
  final _notaCtrl = TextEditingController();
  final _otrosCtrl = TextEditingController();
  Fotografias? _fotos;
  Pedido? _pedido;
  final _retirada = RetiradaEquipo();

  @override
  void initState() {
    super.initState();
    _notaCtrl.text =
        context.read<SessionService>().privateNote(widget.referencia);
    _cargarEstadoFotos();
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    _otrosCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEstadoFotos() async {
    try {
      final res =
          await context.read<PedidoRepository>().getPedido(widget.referencia);
      if (mounted && res.pedido != null) {
        setState(() {
          _pedido = res.pedido;
          _fotos = res.pedido!.fotografias;
        });
      }
    } catch (_) {}
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _guardarNota() async {
    FocusScope.of(context).unfocus(); // cerrar el teclado al guardar
    await context
        .read<SessionService>()
        .savePrivateNote(widget.referencia, _notaCtrl.text);
    if (mounted) _msg('Comentario guardado en este dispositivo');
  }

  Future<void> _abrirFotos(
      String categoria, String titulo, String clave) async {
    await context.push('/fotos', extra: {
      'titulo': titulo,
      'referencia': widget.referencia,
      'categoria': categoria,
      'clave': clave,
    });
    // Al volver, refrescar: las fotos obligatorias de la retirada se validan
    // contra lo que hay en el servidor.
    if (mounted) _cargarEstadoFotos();
  }

  Future<void> _anadirComentario() async {
    final ctrl = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir comentario'),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Escribe un comentario...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.errorFg),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              style: AppDecorations.greenButton,
              child: const Text('Guardar')),
        ],
      ),
    );
    if (texto == null || texto.isEmpty || !mounted) return;
    final session = context.read<SessionService>();
    final repo = context.read<PedidoRepository>();
    final (ok, msg) = await repo.addComentario(
          referencia: widget.referencia,
          usuario: session.displayName(fallback: 'Instalador'),
          texto: texto,
        );
    if (mounted) _msg(ok ? 'Comentario guardado' : msg);
  }

  void _firmaConforme() {
    context.push('/conforme', extra: {
      'referencia': widget.referencia,
      'cliente': widget.cliente,
    });
  }

  void _finalizar() {
    // El apartado de retirada es obligatorio en pedidos con equipo
    // desinstalado: hasta que esté completo no se pasa al formulario.
    if (_pedido == null) {
      _msg('Espera a que carguen los datos del pedido.');
      return;
    }
    if (_pedido!.tieneEquipoDesinstalado) {
      final error = _retirada.errorParaFinalizar(
        tieneFotoRetirado: _tieneFotos('retirado'),
        tieneFotoConservado: _tieneFotos('conservado'),
        tieneDeclaracionFirmada: _tieneFotos('declaracion'),
      );
      if (error != null) {
        _msg(error);
        return;
      }
    }
    // Sin confirmación aquí: lleva al formulario; la confirmación está al final
    // (botón "Finalizar ahora" de la pantalla de finalizar).
    context.push('/finalizar', extra: {'referencia': widget.referencia});
  }

  bool _tieneFotos(String cat) =>
      (_fotos?.byCategoria(cat).isNotEmpty) ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: const Text('Realizar instalación')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _header(),
                const SizedBox(height: AppSpacing.md),
                _notas(),
                const SizedBox(height: AppSpacing.md),
                _seccion(
                  'Fotografías y documentación',
                  Column(
                    children: [
                      _fotoRow('Fotos previas', 'previas', 'PREINST'),
                      _rowDivider(),
                      _fotoRow('Fotos incidencias', 'incidencias', 'DURINST'),
                      _rowDivider(),
                      _fotoRow('Fotos acabada', 'acabada', 'POSTINST'),
                      _rowDivider(),
                      _fotoRow('Fotos conforme', 'conforme', 'CONFCLI'),
                      _rowDivider(),
                      _fotoRow('Documento BOE', 'boe', 'DOCUBOE'),
                    ],
                  ),
                ),
                // Solo cuando el pedido lleva líneas DESINTDO / DESINSTDO.
                if (_pedido?.tieneEquipoDesinstalado ?? false) ...[
                  const SizedBox(height: AppSpacing.md),
                  _seccionEquipoDesinstalado(_pedido!),
                ],
                const SizedBox(height: AppSpacing.md),
                _seccion(
                  'Acciones',
                  Column(
                    children: [
                      _accionRow('Añadir comentarios', 'Notas para el pedido',
                          Icons.chat_outlined, AppColors.successFg,
                          AppColors.successTint, _anadirComentario),
                      _rowDivider(),
                      _accionRow('Firma conforme cliente', 'Recoge la conformidad',
                          Icons.draw_outlined, AppColors.infoFg, AppColors.infoTint,
                          _firmaConforme),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _finalizar,
                  style: AppDecorations.greenButton,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Finalizar instalación'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final t = Theme.of(context).textTheme;
    final cliente = widget.cliente.isNotEmpty
        ? _titleCase(widget.cliente)
        : 'Pedido ${widget.referencia}';
    return Container(
      decoration: AppDecorations.detailHero,
      child: ClipRRect(
        borderRadius: AppRadius.brLg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const StatusBadge('Instalación',
                      tone: BadgeTone.brand, icon: Icons.hvac),
                  const Spacer(),
                  if (widget.referencia.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: AppDecorations.chipLight,
                      child: Text('Nº ${widget.referencia}',
                          style: t.labelMedium
                              ?.copyWith(color: AppColors.textSecondary)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(cliente,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sube las fotos de cada fase, firma el conforme del cliente y finaliza la instalación.',
                style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notas() {
    return _seccion(
      'Comentario privado',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Solo se guarda en este dispositivo.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: AppDecorations.editText,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _notaCtrl,
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textPrimary),
              decoration: AppDecorations.bareInput(
                hintText: 'Notas privadas...',
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _guardarNota,
              style: AppDecorations.greenButton,
              child: const Text('Guardar comentario'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccion(String title, Widget child) {
    return Container(
      width: double.infinity,
      decoration: AppDecorations.whiteCard,
      child: ClipRRect(
        borderRadius: AppRadius.brLg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowDivider() => const Divider(height: 1, color: AppColors.border);

  /// Apartado obligatorio cuando el pedido incluye equipos desinstalados.
  /// De momento muestra las líneas afectadas; el resto del control se
  /// completa en los siguientes pasos de la fase.
  Widget _seccionEquipoDesinstalado(Pedido pedido) {
    final t = Theme.of(context).textTheme;
    final lineas = pedido.lineasDesinstalacion;
    return _seccion(
      'Equipo desinstalado / Retirada',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lineas.length; i++) ...[
            if (i > 0) _rowDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: AppColors.warningTint,
                        borderRadius: AppRadius.brMd),
                    child: const Icon(Icons.recycling_outlined,
                        color: AppColors.warningFg, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lineas[i].nombre, style: t.bodyLarge),
                        Text('${lineas[i].referencia} · ${lineas[i].cantidad} ud.',
                            style: t.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          _rowDivider(),
          const SizedBox(height: AppSpacing.md),
          Text('¿ClimaMania retira el equipo completo?',
              style: t.titleSmall),
          Text('Obligatorio para finalizar la instalación.',
              style: t.bodySmall),
          RadioGroup<bool>(
            groupValue: _retirada.retiraCompleto,
            onChanged: (v) => setState(() => _retirada.retiraCompleto = v),
            child: const Column(
              children: [
                RadioListTile<bool>(
                  value: true,
                  title: Text('SÍ – Se retira el equipo completo'),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<bool>(
                  value: false,
                  title: Text(
                      'NO – El cliente desea conservar total o parcialmente el equipo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          if (_retirada.retiraCompleto == true) ..._ramaRetiraCompleto(t),
          if (_retirada.retiraCompleto == false) ..._ramaConservaCliente(t),
        ],
      ),
    );
  }

  List<Widget> _ramaRetiraCompleto(TextTheme t) => [
        _rowDivider(),
        const SizedBox(height: AppSpacing.md),
        Text('Equipo completo retirado por ClimaMania', style: t.titleSmall),
        CheckboxListTile(
          value: _retirada.unidadInteriorRetirada,
          onChanged: (v) =>
              setState(() => _retirada.unidadInteriorRetirada = v ?? false),
          title: const Text('Unidad interior retirada'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _retirada.unidadExteriorRetirada,
          onChanged: (v) =>
              setState(() => _retirada.unidadExteriorRetirada = v ?? false),
          title: const Text('Unidad exterior retirada'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        _rowDivider(),
        _fotoObligatoriaRow(
          'Foto del equipo retirado',
          'Debe verse la unidad interior y la exterior que se lleva el instalador',
          'retirado',
          'RETIRADO',
        ),
      ];

  List<Widget> _ramaConservaCliente(TextTheme t) => [
        const SizedBox(height: AppSpacing.md),
        _avisoNoRetirado(t),
        const SizedBox(height: AppSpacing.md),
        Text('¿Qué conserva el cliente?', style: t.titleSmall),
        Text('Puedes marcar varios.', style: t.bodySmall),
        for (final c in ComponenteConservado.todos)
          CheckboxListTile(
            value: _retirada.conserva.contains(c.clave),
            onChanged: (v) => setState(() {
              if (v == true) {
                _retirada.conserva.add(c.clave);
              } else {
                _retirada.conserva.remove(c.clave);
              }
            }),
            title: Text(c.etiqueta),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        if (_retirada.conservaOtros)
          Padding(
            padding: const EdgeInsets.only(
                left: 48, bottom: AppSpacing.sm, top: AppSpacing.xs),
            child: TextField(
              controller: _otrosCtrl,
              onChanged: (v) => _retirada.otrosDetalle = v,
              decoration: const InputDecoration(
                labelText: 'Otros: especificar',
                isDense: true,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
        _rowDivider(),
        _fotoObligatoriaRow(
          'Foto de los componentes que conserva el cliente',
          'Debe verse cada componente que se queda en casa del cliente',
          'conservado',
          'CONSERVA',
        ),
        _rowDivider(),
        _declaracionRow(),
      ];

  /// Firma de la "Declaración del cliente sobre equipo desinstalado".
  /// Genera un PDF independiente del conforme, vinculado al pedido.
  Widget _declaracionRow() {
    final firmada = _tieneFotos('declaracion');
    return _hubRow(
      label: 'Firma de la declaración del cliente (obligatoria)',
      subtitle: firmada
          ? 'Declaración firmada y guardada'
          : 'El cliente lee y firma que conserva los elementos indicados',
      icon: firmada ? Icons.check_circle : Icons.draw_outlined,
      fg: firmada ? AppColors.successFg : AppColors.errorFg,
      tint: firmada ? AppColors.successTint : AppColors.errorTint,
      onTap: _abrirDeclaracion,
    );
  }

  Future<void> _abrirDeclaracion() async {
    // La declaración imprime los elementos marcados: deben estar completos.
    final error = _retirada.errorParaDeclaracion;
    if (error != null) {
      _msg(error);
      return;
    }
    final firmada = await context.push<bool>('/declaracion-equipo', extra: {
      'referencia': widget.referencia,
      'elementos': _retirada.conserva.toList(),
      'otros_detalle': _retirada.otrosDetalle,
    });
    if (mounted && firmada == true) _cargarEstadoFotos();
  }

  /// Aviso destacado de la rama NO: el servicio contratado incluye la
  /// retirada completa, y conservar algo exige aceptación y firma.
  Widget _avisoNoRetirado(TextTheme t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningTint,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.warningFg, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warningFg, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'ATENCIÓN – EQUIPO NO RETIRADO COMPLETAMENTE',
                  style: t.titleMedium?.copyWith(
                      color: AppColors.warningFg,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'El servicio contratado contempla la retirada del equipo completo '
            'para su correcta gestión y reciclaje.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Si el cliente desea conservar el equipo o alguno de sus '
            'componentes, deberá indicarse a continuación y será necesaria '
            'su aceptación y firma expresa.',
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Fila de foto marcada como obligatoria: en rojo hasta que exista.
  Widget _fotoObligatoriaRow(
      String label, String ayuda, String categoria, String clave) {
    final tiene = _tieneFotos(categoria);
    return _hubRow(
      label: '$label (obligatoria)',
      subtitle: tiene ? 'Foto añadida' : ayuda,
      icon: tiene ? Icons.check_circle : Icons.photo_camera_outlined,
      fg: tiene ? AppColors.successFg : AppColors.errorFg,
      tint: tiene ? AppColors.successTint : AppColors.errorTint,
      onTap: () => _abrirFotos(categoria, label, clave),
    );
  }

  Widget _fotoRow(String label, String categoria, String clave) {
    final tiene = _tieneFotos(categoria);
    return _hubRow(
      label: label,
      subtitle: tiene ? 'Fotos añadidas' : 'Sin fotos aún',
      icon: tiene ? Icons.check_circle : Icons.photo_camera_outlined,
      fg: tiene ? AppColors.successFg : AppColors.primary,
      tint: tiene ? AppColors.successTint : AppColors.footerActiveBg,
      onTap: () => _abrirFotos(categoria, label, clave),
    );
  }

  Widget _accionRow(String label, String subtitle, IconData icon, Color fg,
      Color tint, VoidCallback onTap) {
    return _hubRow(
        label: label,
        subtitle: subtitle,
        icon: icon,
        fg: fg,
        tint: tint,
        onTap: onTap);
  }

  Widget _hubRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color fg,
    required Color tint,
    required VoidCallback onTap,
  }) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: tint, borderRadius: AppRadius.brMd),
              child: Icon(icon, color: fg, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
