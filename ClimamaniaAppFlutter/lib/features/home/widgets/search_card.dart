import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_decorations.dart';
import '../../../theme/app_spacing.dart';

/// Tarjeta "Buscar eventos" (layoutSearch de activity_main).
class SearchCard extends StatefulWidget {
  final ValueChanged<String> onSearch;

  const SearchCard({super.key, required this.onSearch});

  @override
  State<SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends State<SearchCard> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: AppDecorations.whiteCard,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Buscar eventos', style: t.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: AppDecorations.editText,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.search,
                          size: 20, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          textInputAction: TextInputAction.search,
                          onSubmitted: widget.onSearch,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: AppDecorations.bareInput(
                            hintText: 'Cliente, pedido, dirección, teléfono...',
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () => widget.onSearch(_ctrl.text),
                  style: AppDecorations.orangeButton(fontSize: 14),
                  child: const Text('Buscar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Introduce cualquier dato del evento y pulsa Buscar.',
            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
