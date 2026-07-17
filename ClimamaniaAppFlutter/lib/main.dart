import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/api/api_client.dart';
import 'data/repositories/adicionales_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/home_repository.dart';
import 'data/repositories/incidencia_repository.dart';
import 'data/repositories/install_repository.dart';
import 'data/repositories/pedido_repository.dart';
import 'data/repositories/search_repository.dart';
import 'data/repositories/visita_repository.dart';
import 'services/location_service.dart';
import 'features/shell/refresh_signal.dart';
import 'features/shell/tab_history.dart';
import 'routing/app_router.dart';
import 'services/session_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Datos de formato de fecha en español (para el calendario).
  await initializeDateFormatting('es', null);

  // Barras del sistema oscuras (#212121), como el tema Android.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.primaryDark,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.primaryDark,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final prefs = await SharedPreferences.getInstance();
  final session = SessionService(prefs);
  final api = ApiClient();
  final authRepo = AuthRepository(api, session);
  final homeRepo = HomeRepository(api);
  final searchRepo = SearchRepository(api);
  final pedidoRepo = PedidoRepository(api);
  final installRepo = InstallRepository(api);
  final visitaRepo = VisitaRepository(api);
  final incidenciaRepo = IncidenciaRepository(api);
  final adicionalesRepo = AdicionalesRepository(api);
  final locationService = LocationService();

  runApp(MultiProvider(
    providers: [
      Provider<SessionService>.value(value: session),
      Provider<ApiClient>.value(value: api),
      Provider<AuthRepository>.value(value: authRepo),
      Provider<HomeRepository>.value(value: homeRepo),
      Provider<SearchRepository>.value(value: searchRepo),
      Provider<PedidoRepository>.value(value: pedidoRepo),
      Provider<InstallRepository>.value(value: installRepo),
      Provider<VisitaRepository>.value(value: visitaRepo),
      Provider<IncidenciaRepository>.value(value: incidenciaRepo),
      Provider<AdicionalesRepository>.value(value: adicionalesRepo),
      Provider<LocationService>.value(value: locationService),
      ChangeNotifierProvider<RefreshSignal>(create: (_) => RefreshSignal()),
      ChangeNotifierProvider<TabHistory>(create: (_) => TabHistory()),
    ],
    child: ClimaManiaApp(session: session),
  ));
}

class ClimaManiaApp extends StatelessWidget {
  final SessionService session;

  const ClimaManiaApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final router = createRouter(session);
    return MaterialApp.router(
      title: 'ClimaManiaApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      routerConfig: router,
      // Reduce el tamaño de letra de TODA la app un 10%, respetando además el
      // ajuste de accesibilidad del sistema (se multiplica, no se reemplaza).
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final base = mq.textScaler.scale(1.0); // factor efectivo del sistema
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(base * 0.9)),
          // Red de seguridad global: tocar fuera de un campo cierra el teclado.
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child!,
          ),
        );
      },
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
