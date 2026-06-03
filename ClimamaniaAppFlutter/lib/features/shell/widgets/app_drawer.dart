import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';

/// Menú lateral (drawer) de 280dp. Réplica del menú de `activity_base.xml`:
/// cabecera con logo + "Hola, {nombre}" y las opciones de navegación.
class AppDrawer extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppDrawer({super.key, required this.navigationShell});

  void _goBranch(BuildContext context, int index) {
    Navigator.of(context).pop(); // cerrar drawer
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = context.read<SessionService>().displayName();

    return Drawer(
      width: 280,
      backgroundColor: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera
          Container(
            height: 140,
            color: AppColors.primaryLight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/climamania_logo.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                Text(
                  'Hola, $nombre',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          _DrawerItem(label: 'Inicio', onTap: () => _goBranch(context, 1)),
          _DrawerItem(
              label: 'Calendario', onTap: () => _goBranch(context, 0)),
          _DrawerItem(
            label: 'Buscar eventos',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/buscar');
            },
          ),
          _DrawerItem(
            label: 'Adicionales instalación',
            onTap: () => _goBranch(context, 3),
          ),
          _DrawerItem(
              label: 'Web ClimaMania', onTap: () => _goBranch(context, 4)),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Divider(height: 1, color: AppColors.primaryLight),
          ),
          _DrawerItem(
            label: 'Cerrar sesión',
            color: AppColors.logoutRed,
            onTap: () async {
              Navigator.of(context).pop();
              await context.read<SessionService>().clear();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _DrawerItem({
    required this.label,
    required this.onTap,
    this.color = AppColors.drawerItem,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: Text(
          label,
          style: TextStyle(fontSize: 15, color: color),
        ),
      ),
    );
  }
}
