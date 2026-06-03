import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/incidencia_repository.dart';
import '../../data/repositories/visita_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';

/// Finalizar o cancelar una visita/incidencia. Réplica de CerrarGestionActivity.
class CerrarGestionScreen extends StatefulWidget {
  final String tipo; // 'visita' | 'incidencia'
  final String id;
  final String cliente;
  final String direccion;
  final String poblacion;

  const CerrarGestionScreen({
    super.key,
    required this.tipo,
    required this.id,
    this.cliente = '',
    this.direccion = '',
    this.poblacion = '',
  });

  @override
  State<CerrarGestionScreen> createState() => _CerrarGestionScreenState();
}

class _CerrarGestionScreenState extends State<CerrarGestionScreen> {
  final _motivoCtrl = TextEditingController();
  final _resumenCtrl = TextEditingController();
  bool _busy = false;

  bool get _esIncidencia => widget.tipo == 'incidencia';
  String get _caso => _esIncidencia ? 'incidencia' : 'visita';

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _resumenCtrl.dispose();
    super.dispose();
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _enviar(String accion) async {
    if (accion == 'cancelar' && _motivoCtrl.text.trim().isEmpty) {
      _msg('Indica el motivo de la cancelación');
      return;
    }
    if (accion == 'finalizar' &&
        _esIncidencia &&
        _resumenCtrl.text.trim().isEmpty) {
      _msg('Describe cómo se ha resuelto la incidencia');
      return;
    }
    setState(() => _busy = true);
    final session = context.read<SessionService>();
    final rol = session.rol;
    final usuario = session.usuarioForRequests;
    final equipo = session.readEquipo();
    final autor = session.displayName(fallback: 'Instalador');
    final motivo = _motivoCtrl.text.trim();
    final resumen = _resumenCtrl.text.trim();
    final incidenciaRepo = context.read<IncidenciaRepository>();
    final visitaRepo = context.read<VisitaRepository>();

    final (bool, String) res = _esIncidencia
        ? await incidenciaRepo.cerrar(
            idIncidencia: widget.id,
            rol: rol,
            usuario: usuario,
            equipo: equipo,
            autor: autor,
            accion: accion,
            motivo: motivo,
            resumen: resumen,
          )
        : await visitaRepo.cerrar(
            idVisita: widget.id,
            rol: rol,
            usuario: usuario,
            equipo: equipo,
            autor: autor,
            accion: accion,
            motivo: motivo,
            resumen: resumen,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    _msg(res.$2);
    if (res.$1) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: Text('Finalizar $_caso')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.cliente.isNotEmpty || widget.direccion.isNotEmpty)
                Container(
                  decoration: AppDecorations.whiteCard,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.cliente.isNotEmpty)
                        Text(widget.cliente,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark)),
                      if (widget.direccion.isNotEmpty)
                        Text(
                            [widget.direccion, widget.poblacion]
                                .where((e) => e.isNotEmpty)
                                .join(', '),
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF455A64))),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              // Finalizar
              _card(
                'Finalizar $_caso',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'La $_caso se marcará como resuelta.',
                      style: const TextStyle(color: Color(0xFF455A64)),
                    ),
                    if (_esIncidencia) ...[
                      const SizedBox(height: 10),
                      const Text('Resumen de la actuación',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      _field(_resumenCtrl,
                          'Describe brevemente cómo se ha resuelto...'),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _busy ? null : () => _enviar('finalizar'),
                        child: Text('Finalizar $_caso'),
                      ),
                    ),
                  ],
                ),
              ),
              // Cancelar
              _card(
                'Cancelar $_caso',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Es obligatorio indicar el motivo de la cancelación.',
                      style: TextStyle(color: Color(0xFF455A64)),
                    ),
                    const SizedBox(height: 10),
                    _field(_motivoCtrl, 'Motivo de la cancelación...'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _enviar('cancelar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB00020),
                          side: const BorderSide(color: Color(0xFFB00020)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                        ),
                        child: Text('Cancelar $_caso'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint) {
    return Container(
      decoration: AppDecorations.editText,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        minLines: 2,
        maxLines: 5,
        decoration: InputDecoration(
            hintText: hint,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10)),
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
}
