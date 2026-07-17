import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../tab_history.dart';

/// Menú lateral (drawer): cabecera con logo + "Hola, {nombre}" y opciones de
/// navegación con icono.
class AppDrawer extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppDrawer({super.key, required this.navigationShell});

  void _goBranch(BuildContext context, int index) {
    final current = navigationShell.currentIndex;
    if (index != current) {
      context.read<TabHistory>().record(current);
    }
    Navigator.of(context).pop(); // cerrar drawer
    navigationShell.goBranch(
      index,
      initialLocation: index == current,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = context.read<SessionService>().displayName();

    return Drawer(
      width: 288,
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/climamania_logo.png',
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  Text('Hola, $nombre',
                      style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _DrawerItem(
                icon: Icons.home_outlined,
                label: 'Inicio',
                onTap: () => _goBranch(context, 2)),
            _DrawerItem(
                icon: Icons.calendar_today_outlined,
                label: 'Calendario',
                onTap: () => _goBranch(context, 0)),
            _DrawerItem(
              icon: Icons.search,
              label: 'Buscar eventos',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/buscar');
              },
            ),
            _DrawerItem(
              icon: Icons.add_box_outlined,
              label: 'Adicionales instalación',
              onTap: () => _goBranch(context, 1),
            ),
            _DrawerItem(
                icon: Icons.language,
                label: 'Web ClimaMania',
                onTap: () => _goBranch(context, 4)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Divider(height: 1, color: AppColors.border),
            ),
            _DrawerItem(
              icon: Icons.logout,
              label: 'Cerrar sesión',
              color: AppColors.errorFg,
              onTap: () async {
                Navigator.of(context).pop();
                context.read<TabHistory>().clear();
                await context.read<SessionService>().clear();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
