import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_decorations.dart';

/// Tarjeta de saludo con degradado (bg_detail_hero). "Bienvenido {nombre}",
/// con el nombre en negro y el resto en gris oscuro (igual que MainActivity).
class GreetingHero extends StatelessWidget {
  final String name;

  const GreetingHero({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AppDecorations.detailHero,
      padding: const EdgeInsets.all(18),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
          children: [
            const TextSpan(text: 'Bienvenido '),
            TextSpan(
              text: name,
              style: const TextStyle(color: AppColors.black),
            ),
          ],
        ),
      ),
    );
  }
}
