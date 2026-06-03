import 'package:flutter/material.dart';
import '../../../core/ui_text.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_decorations.dart';
import '../home_controller.dart';

/// Tarjeta de "Instalación en curso" / "Próxima instalación" (resumen de Inicio).
class InstallationCard extends StatelessWidget {
  final bool isEnCurso;
  final CardState state;
  final VoidCallback onMaps;
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;
  final VoidCallback? onTap;

  const InstallationCard({
    super.key,
    required this.isEnCurso,
    required this.state,
    required this.onMaps,
    required this.onCall,
    required this.onWhatsapp,
    this.onTap,
  });

  String get _defaultTitle =>
      isEnCurso ? 'Instalación en curso' : 'Próxima instalación';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppDecorations.whiteCard,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _labelRow(),
            const SizedBox(height: 8),
            _dynamicTitle(),
            if (state.hasData) ...[
              const SizedBox(height: 8),
              _addressBlock(state.data!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _labelRow() {
    final icon = Image.asset(
      isEnCurso
          ? 'assets/images/ic_home.png'
          : 'assets/images/ic_calendar.png',
      width: 18,
      height: 18,
      color: AppColors.primary,
      colorBlendMode: BlendMode.srcIn,
    );

    final Widget label = isEnCurso
        ? Container(
            decoration: AppDecorations.sectionLabelGreen,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: const Text(
              'Instalación en curso',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          )
        : Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            child: const Text(
              'Próxima instalación',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          );

    return Row(
      children: [
        icon,
        const SizedBox(width: 8),
        label,
      ],
    );
  }

  Widget _dynamicTitle() {
    const baseStyle = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.bold,
      color: AppColors.primary,
    );

    if (!state.hasData) {
      return Text(state.message ?? '', style: baseStyle);
    }

    final data = state.data!;
    final ref = data.referencia;
    final cliente = data.cliente;

    if (ref.isEmpty && cliente.isEmpty) {
      return Text(_defaultTitle, style: baseStyle);
    }

    final children = <TextSpan>[];
    if (ref.isNotEmpty) {
      // RelativeSizeSpan(1.2) → 19 * 1.2 = 22.8
      children.add(TextSpan(
        text: ref,
        style: const TextStyle(fontSize: 22.8),
      ));
    }
    if (ref.isNotEmpty && cliente.isNotEmpty) {
      children.add(const TextSpan(text: ' - '));
    }
    if (cliente.isNotEmpty) {
      children.add(TextSpan(
        text: cliente,
        style: const TextStyle(color: AppColors.black),
      ));
    }

    return RichText(text: TextSpan(style: baseStyle, children: children));
  }

  Widget _addressBlock(InstallationData data) {
    final dir = data.direccionLimpia;
    final tel = data.telefono;
    final hasDetalle = dir.isNotEmpty || tel.isNotEmpty;

    final Widget detalle = hasDetalle
        ? RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.addressText,
              ),
              children: [
                if (dir.isNotEmpty) ...[
                  const TextSpan(
                    text: 'Dirección: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: dir),
                ],
                if (tel.isNotEmpty) ...[
                  if (dir.isNotEmpty) const TextSpan(text: '\n'),
                  const TextSpan(
                    text: 'Teléfono: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: tel),
                ],
              ],
            ),
          )
        : const Text('Dirección no disponible', style: UiText.placeholderStyle);

    return Container(
      width: double.infinity,
      decoration: AppDecorations.addressHighlight,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          detalle,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _actionButton('Maps', onMaps)),
              const SizedBox(width: 8),
              Expanded(child: _actionButton('Llamar', onCall)),
              const SizedBox(width: 8),
              Expanded(child: _actionButton('Mensaje', onWhatsapp)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: AppDecorations.orangeButton(fontSize: 12),
        child: Text(label),
      ),
    );
  }
}
