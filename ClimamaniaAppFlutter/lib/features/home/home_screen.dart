import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/external_actions.dart';
import '../../data/repositories/home_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../calendar/event_styles.dart';
import '../shell/refresh_signal.dart';
import 'home_controller.dart';
import 'widgets/greeting_hero.dart';
import 'widgets/installation_card.dart';
import 'widgets/pending_button.dart';
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
    await ExternalActions.openMaps(context, direccion ?? '');
  }

  /// Abre el pedido solo si la referencia es válida (contiene algún dígito),
  /// igual que `isPedidoValido` en Android; si no, avisa y no navega.
  void _openPedido(String referencia, String cliente) {
    if (!EventStyles.isPedidoValido(referencia)) {
      _msg('Este evento no tiene pedido asociado');
      return;
    }
    context.push('/pedido', extra: {'ref': referencia, 'cliente': cliente});
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
              GreetingHero(name: c.greeting),
              const SizedBox(height: 14),
              PendingButton(
                variant: PendingVariant.green,
                text: c.visitasText,
                onTap: () => context.push('/visitas'),
              ),
              const SizedBox(height: 10),
              PendingButton(
                variant: PendingVariant.red,
                text: c.incidenciasText,
                onTap: () => context.push('/incidencias'),
              ),
              const SizedBox(height: 14),
              SearchCard(onSearch: _onSearch),
              const SizedBox(height: 16),
              const Text(
                'Resumen de hoy',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 6),
              InstallationCard(
                isEnCurso: true,
                state: c.enCurso,
                onMaps: () => _openMaps(c.enCurso.data?.direccionParaMapa),
                onCall: () => _call(c.enCurso.data?.telefono),
                onWhatsapp: () => _whatsapp(
                    c.enCurso.data?.whatsapp, c.enCurso.data?.telefono),
                onTap: c.enCurso.hasData
                    ? () => _openPedido(c.enCurso.data!.referencia,
                        c.enCurso.data!.cliente)
                    : null,
              ),
              const SizedBox(height: 10),
              InstallationCard(
                isEnCurso: false,
                state: c.proxima,
                onMaps: () => _openMaps(c.proxima.data?.direccionParaMapa),
                onCall: () => _call(c.proxima.data?.telefono),
                onWhatsapp: () => _whatsapp(
                    c.proxima.data?.whatsapp, c.proxima.data?.telefono),
                onTap: c.proxima.hasData
                    ? () => _openPedido(c.proxima.data!.referencia,
                        c.proxima.data!.cliente)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
