import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_decorations.dart';

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
    return Container(
      decoration: AppDecorations.whiteCard,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buscar eventos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: AppDecorations.editText,
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: widget.onSearch,
                    style: const TextStyle(color: AppColors.black),
                    decoration: const InputDecoration(
                      hintText: 'Cliente, pedido, dirección, teléfono...',
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 6),
          const Text(
            'Introduce cualquier dato del evento y pulsa Buscar.',
            style: TextStyle(fontSize: 12, color: AppColors.hintGray),
          ),
        ],
      ),
    );
  }
}
