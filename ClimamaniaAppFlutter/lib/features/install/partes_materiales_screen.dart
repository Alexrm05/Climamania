import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/parte_materiales.dart';
import '../../data/repositories/materiales_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Escandallo total: partes de trabajo entre dos fechas y el material
/// consumido acumulado por artículo. Cada usuario ve solo lo suyo (el
/// servidor filtra por usuario salvo rol administrador). Desde aquí se abre
/// cualquier parte para verlo o editarlo, y se puede crear uno nuevo.
///
/// [embebida] = true cuando vive en la pestaña "Escandallo" del shell: sin
/// barra propia (la pone el shell) y con el alta como botón flotante.
class PartesMaterialesScreen extends StatefulWidget {
  final bool embebida;

  const PartesMaterialesScreen({super.key, this.embebida = false});

  @override
  State<PartesMaterialesScreen> createState() => _PartesMaterialesScreenState();
}

class _PartesMaterialesScreenState extends State<PartesMaterialesScreen> {
  static final _iso = DateFormat('yyyy-MM-dd');
  static final _corta = DateFormat('dd/MM/yyyy');

  final _buscarCtrl = TextEditingController();
  late DateTime _desde;
  late DateTime _hasta;
  PartesMateriales? _datos;
  bool _cargando = false;
  bool _verTotales = true;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _desde = DateTime(hoy.year, hoy.month, 1);
    _hasta = DateTime(hoy.year, hoy.month, hoy.day);
    _cargar();
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  /// Abre el parte del pedido escrito (existente para ver/editar, o nuevo).
  Future<void> _buscarPedido() async {
    FocusScope.of(context).unfocus();
    final ref = _buscarCtrl.text.trim();
    if (ref.isEmpty) return;
    await _abrirParte(ref);
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final session = context.read<SessionService>();
    final repo = context.read<MaterialesRepository>();
    try {
      final d = await repo.getPartes(
        usuario: session.usuarioForRequests,
        rol: session.rol,
        desde: _iso.format(_desde),
        hasta: _iso.format(_hasta),
      );
      if (mounted) setState(() => _datos = d);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirFecha(bool esDesde) async {
    final actual = esDesde ? _desde : _hasta;
    final d = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: esDesde ? 'Desde' : 'Hasta',
    );
    if (d == null || !mounted) return;
    setState(() {
      if (esDesde) {
        _desde = d;
        if (_hasta.isBefore(_desde)) _hasta = _desde;
      } else {
        _hasta = d;
        if (_desde.isAfter(_hasta)) _desde = _hasta;
      }
    });
    _cargar();
  }

  Future<void> _abrirParte(String referencia) async {
    final cambiado =
        await context.push<bool>('/escandallo', extra: {'referencia': referencia});
    if (mounted && cambiado == true) _cargar();
  }

  Future<void> _nuevoParte() async {
    final creado = await context.push<bool>('/escandallo');
    if (mounted && creado == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = _datos;
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: widget.embebida
          ? null
          : AppBar(
              title: const Text('Partes de trabajo'),
              actions: [
                IconButton(
                  tooltip: 'Nuevo parte',
                  icon: const Icon(Icons.add),
                  onPressed: _nuevoParte,
                ),
              ],
            ),
      floatingActionButton: widget.embebida
          ? FloatingActionButton.extended(
              onPressed: _nuevoParte,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo parte'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
              AppSpacing.lg, widget.embebida ? 88 : AppSpacing.lg),
          children: [
            if (widget.embebida)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text('Escandallo · Partes de trabajo',
                    style: t.titleLarge),
              ),
            _cardBuscar(t),
            _cardFiltro(t),
            if (_cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (d == null)
              _vacio('No se pudo cargar el escandallo. Desliza para reintentar.')
            else ...[
              _selector(t),
              if (_verTotales) _cardTotales(t, d) else _cardPartes(t, d),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cardBuscar(TextTheme t) {
    return _card(
      'Buscar parte',
      Row(
        children: [
          Expanded(
            child: Container(
              decoration: AppDecorations.editText,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _buscarCtrl,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _buscarPedido(),
                decoration: AppDecorations.bareInput(
                    hintText: 'Nº de pedido',
                    contentPadding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _buscarPedido,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd)),
              icon: const Icon(Icons.search, size: 20),
              label: const Text('Abrir'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardFiltro(TextTheme t) {
    return _card(
      'Periodo',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _fechaBtn('Desde', _desde, () => _elegirFecha(true))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _fechaBtn('Hasta', _hasta, () => _elegirFecha(false))),
            ],
          ),
          if (_datos?.soloUsuario ?? true)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text('Solo se muestran tus partes.',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }

  Widget _fechaBtn(String label, DateTime v, VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: const BorderSide(color: AppColors.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              Text(_corta.format(v),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selector(TextTheme t) {
    final d = _datos!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SegmentedButton<bool>(
        segments: [
          ButtonSegment(
              value: true,
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text('Totales (${d.totales.length})')),
          ButtonSegment(
              value: false,
              icon: const Icon(Icons.description_outlined),
              label: Text('Partes (${d.partes.length})')),
        ],
        selected: {_verTotales},
        onSelectionChanged: (s) => setState(() => _verTotales = s.first),
      ),
    );
  }

  Widget _cardTotales(TextTheme t, PartesMateriales d) {
    if (d.totales.isEmpty) {
      return _vacio('Sin material registrado en este periodo.');
    }
    final importe = d.totales.fold<double>(0, (a, x) => a + x.importeSinIva);
    final s = t.labelSmall?.copyWith(color: AppColors.textMuted);
    return _card(
      'Material consumido en el periodo',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Ref. / Descripción', style: s)),
              SizedBox(width: 48, child: Text('Prev.', style: s, textAlign: TextAlign.right)),
              SizedBox(width: 56, child: Text('Real', style: s, textAlign: TextAlign.right)),
              SizedBox(width: 48, child: Text('Desv.', style: s, textAlign: TextAlign.right)),
            ],
          ),
          const Divider(height: 12, color: AppColors.border),
          for (final m in d.totales) _totalRow(t, m),
          if (importe > 0) ...[
            const Divider(height: 16, color: AppColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Importe material (sin IVA)', style: t.bodyMedium),
                Text('${importe.toStringAsFixed(2).replaceAll('.', ',')} €',
                    style: t.titleSmall?.copyWith(color: AppColors.primaryDark)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _totalRow(TextTheme t, MaterialTotal m) {
    final desv = m.desviacion;
    final desvColor = desv > 0
        ? AppColors.errorFg
        : desv < 0
            ? AppColors.infoFg
            : AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.referenciaVisible,
                    style: t.titleSmall?.copyWith(color: AppColors.primary)),
                Text(m.descripcion, style: t.bodySmall),
                Text('${m.unidad} · en ${m.numPartes} parte${m.numPartes == 1 ? '' : 's'}',
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(formatoCantidad(m.cantidadPrevista),
                textAlign: TextAlign.right, style: t.bodyMedium),
          ),
          SizedBox(
            width: 56,
            child: Text(formatoCantidad(m.cantidad),
                textAlign: TextAlign.right,
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          SizedBox(
            width: 48,
            child: Text(formatoDesviacion(desv),
                textAlign: TextAlign.right,
                style: t.bodyMedium?.copyWith(color: desvColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _cardPartes(TextTheme t, PartesMateriales d) {
    if (d.partes.isEmpty) {
      return _vacio('Sin partes de trabajo en este periodo.');
    }
    return Column(
      children: [for (final p in d.partes) _parteItem(t, p)],
    );
  }

  Widget _parteItem(TextTheme t, ParteResumen p) {
    final min = minutosEntre(p.horaInicio, p.horaFinal);
    final fecha = DateTime.tryParse(p.fechaCreacion);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.white,
        borderRadius: AppRadius.brMd,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _abrirParte(p.pedido),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: AppColors.successTint, borderRadius: AppRadius.brMd),
                  child: const Icon(Icons.description_outlined,
                      color: AppColors.successFg),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Parte Nº ${p.pedido}',
                          style: t.titleSmall?.copyWith(color: AppColors.primary)),
                      if (p.cliente.isNotEmpty) Text(p.cliente, style: t.bodyMedium),
                      Text(
                        [
                          if (fecha != null) _corta.format(fecha),
                          if (p.horaInicio.isNotEmpty) '${p.horaInicio}–${p.horaFinal}',
                          if (min != null) formatoHoras(min),
                          '${p.numLineas} material${p.numLineas == 1 ? '' : 'es'}',
                        ].join(' · '),
                        style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vacio(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(texto,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textMuted)),
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
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
      ),
    );
  }
}
