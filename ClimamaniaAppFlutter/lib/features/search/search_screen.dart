import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/search_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../shell/detail_scaffold.dart';
import '../shell/nav_destinations.dart';
import 'search_controller.dart';

/// Pantalla de búsqueda (eventos + visitas + incidencias).
/// Réplica de SearchEventsActivity + content_search_events.
class SearchScreen extends StatelessWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => EventSearchController(
        ctx.read<SearchRepository>(),
        ctx.read<SessionService>(),
      ),
      child: _SearchView(initialQuery: initialQuery),
    );
  }
}

class _SearchView extends StatefulWidget {
  final String? initialQuery;

  const _SearchView({this.initialQuery});

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _ctrl = TextEditingController();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    var q = widget.initialQuery?.trim() ?? '';
    // Dev (--dart-define=SEARCH_Q=...): autocompleta una búsqueda al previsualizar.
    if (q.isEmpty) q = const String.fromEnvironment('SEARCH_Q');
    if (q.isNotEmpty) {
      _ctrl.text = q;
      // Diferir al siguiente frame: evita notifyListeners durante el build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<EventSearchController>().search(q);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _runSearch() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Introduce un dato para buscar')));
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<EventSearchController>().search(q);
  }

  void _openResult(SearchResult r) {
    if (!r.canOpen) {
      final msg = r.kind == SearchKind.evento
          ? 'Este evento no tiene pedido asociado'
          : 'Identificador no disponible';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    if (r.kind == SearchKind.evento) {
      context.push('/pedido',
          extra: {'ref': r.navRef, 'cliente': r.navCliente});
      return;
    }
    if (r.kind == SearchKind.visita) {
      context.push('/visita', extra: {'id': r.navId});
      return;
    }
    // Incidencia: pasamos también la referencia (Android la envía al detalle).
    context.push('/incidencia', extra: {'id': r.navId, 'referencia': r.navRef});
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      activeIndex: NavBranch.home,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      onSubmitted: (_) => _runSearch(),
                      style: const TextStyle(color: AppColors.black),
                      decoration: const InputDecoration(
                        hintText:
                            'Cliente, pedido, dirección, teléfono, visita, incidencia...',
                        hintStyle: TextStyle(color: Colors.grey),
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
                    onPressed: _runSearch,
                    style: AppDecorations.orangeButton(fontSize: 14),
                    child: const Text('Buscar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer<EventSearchController>(
                builder: (context, c, _) {
                  return ListView(
                    children: [
                      Text(
                        c.statusText,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF555555)),
                      ),
                      const SizedBox(height: 12),
                      if (c.loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        _section('Eventos', c.eventos),
                        _section('Visitas', c.visitas),
                        _section('Incidencias', c.incidencias),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<SearchResult> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${items.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: AppDecorations.chipLight,
              child: const Text('Sin resultados',
                  style: TextStyle(fontSize: 13, color: Color(0xFF607D8B))),
            )
          else
            for (final r in items) _ResultCard(result: r, onTap: () => _openResult(r)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _ResultCard({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardStroke),
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: result.accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF455A64)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.address,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF455A64)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: result.metaColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
