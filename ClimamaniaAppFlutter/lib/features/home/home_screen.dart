import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/home_repository.dart';
import '../../services/session_service.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../theme/app_colors.dart';
import '../shell/refresh_signal.dart';
import 'home_controller.dart';
import '../../theme/app_spacing.dart';
import 'widgets/greeting_hero.dart';
import 'widgets/installation_card.dart';
import 'widgets/metric_tile.dart';
import 'widgets/search_card.dart';

/// Pantalla de Inicio. Réplica de `MainActivity` + `activity_main.xml`.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => HomeController(
        ctx.read<HomeRepository>(),
        ctx.read<SessionService>(),
      )..init(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  RefreshSignal? _signal;

  @override
  void initState() {
    super.initState();
    _signal = context.read<RefreshSignal>();
    _signal?.addListener(_onRefreshSignal);
  }

  void _onRefreshSignal() {
    if (!mounted) return;
    context.read<HomeController>().load();
  }

  @override
  void dispose() {
    _signal?.removeListener(_onRefreshSignal);
    super.dispose();
  }

  void _msg(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _launch(Uri uri, String errorMsg) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _msg(errorMsg);
    } catch (_) {
      _msg(errorMsg);
    }
  }

  Future<void> _openMaps(String? direccion) async {
    final d = (direccion ?? '').trim();
    if (d.isEmpty) {
      _msg('Dirección no disponible');
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(d)}',
    );
    await _launch(uri, 'No se pudo abrir el mapa');
  }

  Future<void> _call(String? telefono) async {
    final t = (telefono ?? '').trim();
    if (t.isEmpty) {
      _msg('Teléfono no disponible');
      return;
    }
    await _launch(Uri.parse('tel:$t'), 'No se pudo iniciar la llamada');
  }

  Future<void> _whatsapp(String? whatsapp, String? telefono) async {
    final source = (whatsapp ?? '').trim().isNotEmpty
        ? (whatsapp ?? '').trim()
        : (telefono ?? '').trim();
    final digits = source.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _msg('WhatsApp no disponible');
      return;
    }
    await _launch(Uri.parse('https://wa.me/$digits'), 'No se pudo abrir WhatsApp');
  }

  void _onSearch(String query) {
    FocusScope.of(context).unfocus(); // cerrar el teclado al buscar
    if (query.trim().isEmpty) {
      _msg('Introduce un dato para buscar');
      return;
    }
    context.push('/buscar', extra: query.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeController>(
      builder: (context, c, _) {
        return RefreshIndicator(
          onRefresh: c.load,
          color: AppColors.primary,
          backgroundColor: AppColors.white,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              FadeSlideIn(child: GreetingHero(name: c.greeting)),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delayMs: 70,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: MetricTile(
                          tone: MetricTone.success,
                          icon: Icons.event_available_outlined,
                          label: 'Visitas',
                          count: c.visitasCount,
                          error: c.visitasError,
                          onTap: () => context.push('/visitas'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: MetricTile(
                          tone: MetricTone.danger,
                          icon: Icons.report_problem_outlined,
                          label: 'Incidencias',
                          count: c.incidenciasCount,
                          error: c.incidenciasError,
                          onTap: () => context.push('/incidencias'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delayMs: 140,
                child: SearchCard(onSearch: _onSearch),
              ),
              const SizedBox(height: AppSpacing.xl),
              FadeSlideIn(
                delayMs: 200,
                child: Text(
                  'Resumen de hoy',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Una tarjeta por cada instalación en curso (pueden ser varias en
              // paralelo, de equipos distintos).
              for (int i = 0; i < c.enCurso.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                FadeSlideIn(
                  delayMs: 240 + i * 60,
                  child: InstallationCard(
                    isEnCurso: true,
                    state: c.enCurso[i],
                    onMaps: () =>
                        _openMaps(c.enCurso[i].data?.direccionParaMapa),
                    onCall: () => _call(c.enCurso[i].data?.telefono),
                    onWhatsapp: () => _whatsapp(c.enCurso[i].data?.whatsapp,
                        c.enCurso[i].data?.telefono),
                    onTap: c.enCurso[i].hasData
                        ? () => context.push('/pedido', extra: {
                              'ref': c.enCurso[i].data!.referencia,
                              'cliente': c.enCurso[i].data!.cliente,
                            })
                        : null,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              FadeSlideIn(
                delayMs: 300,
                child: InstallationCard(
                  isEnCurso: false,
                  state: c.proxima,
                  onMaps: () => _openMaps(c.proxima.data?.direccionParaMapa),
                  onCall: () => _call(c.proxima.data?.telefono),
                  onWhatsapp: () => _whatsapp(
                      c.proxima.data?.whatsapp, c.proxima.data?.telefono),
                  onTap: c.proxima.hasData
                      ? () => context.push('/pedido', extra: {
                            'ref': c.proxima.data!.referencia,
                            'cliente': c.proxima.data!.cliente,
                          })
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
