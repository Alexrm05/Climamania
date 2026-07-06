import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/adicionales/adicionales_screen.dart';
import '../features/adicionales/presupuesto_detalle_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/home/home_screen.dart';
import '../data/models/gestion_item.dart';
import '../features/incidencias/incidencia_detalle_screen.dart';
import '../features/incidencias/incidencia_enviar_screen.dart';
import '../features/incidencias/incidencias_pendientes_screen.dart';
import '../features/incidencias/incidencias_previas_screen.dart';
import '../features/login/login_screen.dart';
import '../features/install/conforme_screen.dart';
import '../features/install/finalizar_screen.dart';
import '../features/install/install_screen.dart';
import '../features/pedido/pedido_detail_screen.dart';
import '../features/photos/photo_list_screen.dart';
import '../features/placeholders/coming_soon_screen.dart';
import '../features/search/search_screen.dart';
import '../features/valoraciones/valoraciones_screen.dart';
import '../features/video/video_player_screen.dart';
import '../features/web/web_view_screen.dart';
import '../features/visitas/cerrar_gestion_screen.dart';
import '../features/visitas/visita_detalle_screen.dart';
import '../features/visitas/visita_enviar_screen.dart';
import '../features/visitas/visitas_pendientes_screen.dart';
import '../features/visitas/visitas_previas_screen.dart';
import '../features/shell/app_shell.dart';
import '../services/session_service.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Referencia desde el extra; si falta, usa el dev-define PEDIDO_REF (preview).
String _refOr(Object? v) {
  final s = (v ?? '').toString();
  return s.isEmpty ? const String.fromEnvironment('PEDIDO_REF') : s;
}

String _visitaIdOr(Object? v) {
  final s = (v ?? '').toString();
  return s.isEmpty ? const String.fromEnvironment('VISITA_ID') : s;
}

/// Construye el router con guarda de sesión (auto-login / logout) y el shell
/// persistente de 5 ramas. Reproduce la navegación de la app Android.
GoRouter createRouter(SessionService session) {
  // Solo desarrollo (--dart-define). Apagados por defecto: en producción la
  // guarda de sesión funciona con normalidad.
  const bypassAuth = bool.fromEnvironment('BYPASS_AUTH');
  const startRoute = String.fromEnvironment('START_ROUTE', defaultValue: '/home');

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: startRoute,
    redirect: (context, state) {
      if (bypassAuth) return null;
      final loggedIn = session.isLoggedIn;
      final loggingIn = state.matchedLocation == '/login';
      if (!loggedIn) return loggingIn ? null : '/login';
      if (loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Detalle del pedido (empujado sobre el shell).
      GoRoute(
        path: '/pedido',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          var ref = '';
          var cliente = '';
          if (extra is Map) {
            ref = (extra['ref'] ?? '').toString();
            cliente = (extra['cliente'] ?? '').toString();
          } else if (extra is String) {
            ref = extra;
          }
          // Dev (--dart-define=PEDIDO_REF=...): previsualizar un pedido directo.
          if (ref.isEmpty) ref = const String.fromEnvironment('PEDIDO_REF');
          return PedidoDetailScreen(referencia: ref, clienteHint: cliente);
        },
      ),
      // Flujo de instalación (Fase 3), empujado sobre el shell.
      GoRoute(
        path: '/install',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          return InstallScreen(
            referencia: _refOr(e['referencia']),
            cliente: (e['cliente'] ?? '').toString(),
          );
        },
      ),
      GoRoute(
        path: '/fotos',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          return PhotoListScreen(
            titulo: (e['titulo'] ?? 'Fotos del cliente').toString(),
            referencia: _refOr(e['referencia']),
            categoria: (e['categoria'] ?? 'cliente').toString(),
            clave: (e['clave'] ?? 'FOTOCLI').toString(),
          );
        },
      ),
      GoRoute(
        path: '/finalizar',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          return FinalizarScreen(referencia: _refOr(e['referencia']));
        },
      ),
      GoRoute(
        path: '/conforme',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          return ConformeScreen(
            referencia: _refOr(e['referencia']),
            cliente: (e['cliente'] ?? '').toString(),
          );
        },
      ),
      // Visitas (Fase 4)
      GoRoute(
        path: '/visitas',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const VisitasPendientesScreen(),
      ),
      GoRoute(
        path: '/visita',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          return VisitaDetalleScreen(idVisita: _visitaIdOr(e['id']));
        },
      ),
      GoRoute(
        path: '/visita-enviar',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          return VisitaEnviarScreen(
            idVisita: _visitaIdOr(e['id']),
            cliente: (e['cliente'] ?? '').toString(),
            direccion: (e['direccion'] ?? '').toString(),
            poblacion: (e['poblacion'] ?? '').toString(),
          );
        },
      ),
      GoRoute(
        path: '/cerrar-gestion',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          return CerrarGestionScreen(
            tipo: (e['tipo'] ?? 'visita').toString(),
            id: (e['id'] ?? '').toString(),
            cliente: (e['cliente'] ?? '').toString(),
            direccion: (e['direccion'] ?? '').toString(),
            poblacion: (e['poblacion'] ?? '').toString(),
          );
        },
      ),
      // Detalle de presupuesto (Fase 6)
      GoRoute(
        path: '/presupuesto',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          final id = (e['id'] ?? '').toString();
          return PresupuestoDetalleScreen(
            id: id.isEmpty
                ? const String.fromEnvironment('PRESUPUESTO_ID')
                : id,
          );
        },
      ),
      // Incidencias (Fase 5)
      GoRoute(
        path: '/incidencias',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const IncidenciasPendientesScreen(),
      ),
      GoRoute(
        path: '/incidencia',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          return IncidenciaDetalleScreen(
            idIncidencia: _visitaIdOr(e['id']),
            referencia: (e['referencia'] ?? '').toString(),
          );
        },
      ),
      // Visitas / incidencias previas (histórico por referencia del pedido).
      GoRoute(
        path: '/visitas-previas',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          final items = (e['items'] is List)
              ? List<GestionItem>.from(e['items'] as List)
              : <GestionItem>[];
          return VisitasPreviasScreen(
            visitas: items,
            referencia: (e['referencia'] ?? '').toString(),
          );
        },
      ),
      GoRoute(
        path: '/incidencias-previas',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          final items = (e['items'] is List)
              ? List<GestionItem>.from(e['items'] as List)
              : <GestionItem>[];
          return IncidenciasPreviasScreen(
            incidencias: items,
            referencia: (e['referencia'] ?? '').toString(),
          );
        },
      ),
      GoRoute(
        path: '/incidencia-enviar',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          return IncidenciaEnviarScreen(
            idIncidencia: _visitaIdOr(e['id']),
            referencia: (e['referencia'] ?? '').toString(),
            cliente: (e['cliente'] ?? '').toString(),
            direccion: (e['direccion'] ?? '').toString(),
            poblacion: (e['poblacion'] ?? '').toString(),
          );
        },
      ),
      // Reproductor de vídeo (Fase 7), empujado sobre el shell.
      GoRoute(
        path: '/video',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          final urls = <String>[];
          if (e['urls'] is List) {
            for (final u in e['urls'] as List) {
              final s = (u ?? '').toString();
              if (s.isNotEmpty) urls.add(s);
            }
          }
          final single = (e['url'] ?? '').toString();
          if (urls.isEmpty && single.isNotEmpty) urls.add(single);
          // Dev (--dart-define=VIDEO_URL=...): previsualizar el reproductor.
          if (urls.isEmpty) {
            const dev = String.fromEnvironment('VIDEO_URL');
            if (dev.isNotEmpty) urls.add(dev);
          }
          return VideoPlayerScreen(urls: urls);
        },
      ),
      // Web empujada sobre el shell (gestión / PDF con URL concreta).
      GoRoute(
        path: '/webview',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra is Map ? state.extra as Map : const {};
          return WebViewScreen(
            url: (e['url'] ?? 'https://www.climamania.com').toString(),
            standalone: true,
          );
        },
      ),
      // Búsqueda de eventos/visitas/incidencias (empujada sobre el shell).
      GoRoute(
        path: '/buscar',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            SearchScreen(initialQuery: state.extra as String?),
      ),
      // Pantalla provisional empujada sobre el shell (con barra y volver).
      GoRoute(
        path: '/proximamente',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ComingSoonScreen(
          title: (state.extra as String?) ?? 'Próximamente',
          standalone: true,
        ),
      ),
      // Shell persistente: barra superior + barra inferior + drawer.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Orden EXACTO de la barra inferior: Calendario · Inicio ·
          // Valoraciones · Adicionales · Web.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ratings',
                builder: (context, state) => const ValoracionesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/adicionales',
                builder: (context, state) => const AdicionalesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/web',
                builder: (context, state) => const WebViewScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
