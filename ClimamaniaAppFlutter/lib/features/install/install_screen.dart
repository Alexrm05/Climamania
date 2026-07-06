import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/pedido.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../shell/detail_scaffold.dart';
import '../shell/nav_destinations.dart';

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
  Fotografias? _fotos;

  @override
  void initState() {
    super.initState();
    _notaCtrl.text =
        context.read<SessionService>().privateNote(widget.referencia);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.referencia.trim().isEmpty) {
        _msg('Referencia no disponible');
      }
    });
    _cargarEstadoFotos();
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEstadoFotos() async {
    try {
      final res =
          await context.read<PedidoRepository>().getPedido(widget.referencia);
      if (mounted && res.pedido != null) {
        setState(() => _fotos = res.pedido!.fotografias);
      }
    } catch (_) {}
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _guardarNota() async {
    await context
        .read<SessionService>()
        .savePrivateNote(widget.referencia, _notaCtrl.text);
    _msg('Comentario guardado en este dispositivo');
  }

  Future<void> _abrirFotos(String categoria, String titulo, String clave) async {
    await context.push('/fotos', extra: {
      'titulo': titulo,
      'referencia': widget.referencia,
      'categoria': categoria,
      'clave': clave,
    });
    // Al volver, refrescar el estado de los botones (verde si hay fotos),
    // como hace InstallActivity en onResume.
    if (mounted) await _cargarEstadoFotos();
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
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (texto == null || !mounted) return;
    if (texto.isEmpty) {
      _msg('El comentario está vacío');
      return;
    }
    final session = context.read<SessionService>();
    final repo = context.read<PedidoRepository>();
    final (ok, msg) = await repo.addComentario(
          referencia: widget.referencia,
          usuario: session.displayName(fallback: 'Instalador'),
          texto: texto,
        );
    if (mounted) _msg(ok ? 'Comentario guardado' : msg);
  }

  Future<void> _firmaConforme() async {
    await context.push('/conforme', extra: {
      'referencia': widget.referencia,
      'cliente': widget.cliente,
    });
    if (mounted) await _cargarEstadoFotos();
  }

  Future<void> _finalizar() async {
    // Sin confirmación aquí: lleva al formulario; la confirmación está al final
    // (botón "Finalizar ahora" de la pantalla de finalizar).
    await context.push('/finalizar', extra: {'referencia': widget.referencia});
    if (mounted) await _cargarEstadoFotos();
  }

  bool _tieneFotos(String cat) =>
      (_fotos?.byCategoria(cat).isNotEmpty) ?? false;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      activeIndex: NavBranch.home,
      onReload: _cargarEstadoFotos,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(),
                _notas(),
                _seccion('Fotografías y documentación', Column(
                  children: [
                    _fotoBtn('Fotos previas', 'previas', 'PREINST'),
                    _fotoBtn('Fotos incidencias', 'incidencias', 'DURINST'),
                    _fotoBtn('Fotos acabada', 'acabada', 'POSTINST'),
                    _fotoBtn('Fotos conforme', 'conforme', 'CONFCLI'),
                    _fotoBtn('Documento BOE', 'boe', 'DOCUBOE'),
                  ],
                )),
                _seccion('Acciones', Column(
                  children: [
                    _accionBtn(
                        'Añadir comentarios', Icons.comment, _anadirComentario),
                    const SizedBox(height: 10),
                    _accionBtn(
                        'Firma conforme cliente', Icons.draw, _firmaConforme),
                  ],
                )),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _finalizar,
                        child: const Text('Finalizar instalación'),
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
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: AppDecorations.detailHero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.referencia,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
          if (widget.cliente.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(widget.cliente,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark)),
            ),
          const SizedBox(height: 8),
          const Text(
            'Sube las fotos de cada fase, firma el conforme del cliente y finaliza la instalación.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6D4C41)),
          ),
        ],
      ),
    );
  }

  Widget _notas() {
    return _seccion('Comentario privado (solo en este dispositivo)', Column(
      children: [
        Container(
          decoration: AppDecorations.editText,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _notaCtrl,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(fontSize: 15, color: Color(0xFF424242)),
            decoration: const InputDecoration(
              hintText: 'Notas privadas...',
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
            onPressed: _guardarNota,
            child: const Text('Guardar comentario'),
          ),
        ),
      ],
    ));
  }

  Widget _seccion(String title, Widget child) {
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

  Widget _fotoBtn(String label, String categoria, String clave) {
    final tiene = _tieneFotos(categoria);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton.icon(
          onPressed: () => _abrirFotos(categoria, label, clave),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                tiene ? const Color(0xFF2E7D32) : AppColors.primary,
            alignment: Alignment.centerLeft,
          ),
          icon: Icon(tiene ? Icons.check_circle : Icons.photo_camera, size: 20),
          label: Text(label),
        ),
      ),
    );
  }

  Widget _accionBtn(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(alignment: Alignment.centerLeft),
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}
