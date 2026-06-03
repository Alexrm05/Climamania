import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';

/// Pantalla de Valoraciones (rama /ratings). Réplica de ValoracionActivity +
/// content_valoracion: cabecera hero, tarjeta con el QR oficial y pasos.
class ValoracionesScreen extends StatelessWidget {
  const ValoracionesScreen({super.key});

  static const _greyText = Color(0xFF6F6F6F);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Cabecera hero.
          _card(
            decoration: AppDecorations.detailHero.copyWith(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Valoraciones',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark)),
                const SizedBox(height: 6),
                const Text('Ayuda a mejorar nuestro servicio en un minuto.',
                    style: TextStyle(fontSize: 13, color: _greyText)),
                const SizedBox(height: 10),
                Container(
                  decoration: AppDecorations.chipLight,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  child: const Text('QR oficial',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Tarjeta del QR.
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Escanea el QR y deja tu valoración',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark)),
                const SizedBox(height: 6),
                const Text(
                    'Puedes usar la cámara del móvil o cualquier lector de QR.',
                    style: TextStyle(fontSize: 13, color: _greyText)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8E1D8)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Center(
                    child: Image.asset(
                      'assets/images/qr_valoracion.jpg',
                      width: 300,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text('Gracias por compartir tu experiencia.',
                      style: TextStyle(fontSize: 13, color: _greyText)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Pasos rápidos.
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Pasos rápidos',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark)),
                SizedBox(height: 6),
                Text(
                    '1. Abre la cámara y enfoca el QR.\n'
                    '2. Completa la valoración en menos de un minuto.',
                    style: TextStyle(fontSize: 13, color: _greyText)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Volver (en el shell, vuelve a Inicio).
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => context.go('/home'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primaryDark),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              child: const Text('Volver'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, BoxDecoration? decoration}) {
    return Container(
      decoration: decoration ??
          AppDecorations.whiteCard.copyWith(
            borderRadius: BorderRadius.circular(20),
          ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
