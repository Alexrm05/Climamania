import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Pantalla provisional "Próximamente / En construcción".
/// - Como rama del shell ([standalone] = false): solo el contenido centrado.
/// - Empujada de forma independiente ([standalone] = true): con AppBar y volver.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final bool standalone;

  const ComingSoonScreen({
    super.key,
    required this.title,
    this.standalone = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: AppColors.primaryLight,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction, size: 56, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Próximamente / En construcción',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );

    if (!standalone) return content;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: content,
    );
  }
}
