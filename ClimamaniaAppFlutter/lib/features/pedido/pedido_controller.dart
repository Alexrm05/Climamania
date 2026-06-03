import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../core/ui_text.dart';
import '../../data/models/pedido.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../services/session_service.dart';

class PedidoController extends ChangeNotifier {
  final PedidoRepository _repo;
  final SessionService _session;
  final String referencia;
  final String clienteHint;

  PedidoController(
    this._repo,
    this._session, {
    required this.referencia,
    this.clienteHint = '',
  });

  bool loading = true;
  String? errorMsg;
  Pedido? pedido;
  bool savingComentario = false;

  // Comentarios añadidos en esta sesión (se muestran sin recargar).
  final List<ComentarioInstalador> _extraComentarios = [];

  bool _disposed = false;

  void init() => load();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    errorMsg = null;
    _notify();
    try {
      final res = await _repo.getPedido(referencia);
      if (!res.ok || res.pedido == null) {
        errorMsg = res.message.isEmpty
            ? 'No se pudo cargar el pedido'
            : res.message;
        pedido = res.pedido;
      } else {
        pedido = res.pedido;
      }
    } catch (_) {
      errorMsg = 'Error de conexión al cargar el pedido';
    }
    loading = false;
    _notify();
  }

  Future<(bool, String)> addComentario(String texto) async {
    final t = texto.trim();
    if (t.isEmpty) return (false, 'Escribe un comentario');
    savingComentario = true;
    _notify();

    final usuario = _session.displayName(fallback: _session.usuario);
    final result = await _repo.addComentario(
      referencia: referencia,
      usuario: usuario,
      texto: t,
    );
    if (result.$1) {
      _extraComentarios.add(ComentarioInstalador(
        fecha: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        usuario: usuario,
        texto: t,
      ));
    }
    savingComentario = false;
    _notify();
    return (result.$1, result.$2.isEmpty ? 'Comentario guardado' : result.$2);
  }

  // --- Datos para la UI ---

  String get cliente {
    final c = pedido?.cliente ?? '';
    return c.isNotEmpty ? c : clienteHint;
  }

  String get fechaHora {
    final eq = pedido?.equipoAsignado ?? const [];
    if (eq.isEmpty) return '';
    return _formatFechaHoraCorta(eq.first.start);
  }

  String get direccion =>
      _cleanDireccion(pedido?.direccionInstalacion ?? '');

  List<String> get telefonos {
    final p = pedido;
    if (p == null) return const [];
    final raw = <String>[
      p.entrega?.telefono ?? '',
      p.facturacion?.telefono ?? '',
      ..._extractPhones(p.direccionInstalacion),
    ];
    return _dedupePhones(raw.where((e) => e.trim().isNotEmpty).toList());
  }

  String get telefonoPrincipal => _chooseBestMobile(telefonos);

  String get equipoTexto {
    final p = pedido;
    if (p == null) return '';
    final lines = <String>[];
    for (final e in p.equipoAsignado) {
      final desc = e.descripcion;
      final fecha = _formatFecha(e.start);
      if (desc.isNotEmpty) {
        lines.add(fecha.isEmpty ? '• $desc' : '• $desc · $fecha');
      }
    }
    for (final f in p.finalizaciones) {
      final fecha = _formatFecha(f.fecha);
      lines.add('• Finalizada por ${f.usuario}'
          '${fecha.isEmpty ? '' : ' · $fecha'}');
    }
    return lines.join('\n');
  }

  String get observaciones => pedido?.observaciones ?? '';

  List<DetalleLinea> get detalleLineas => pedido?.detallePedido ?? const [];

  String get comentariosTexto {
    final p = pedido;
    if (p == null) return '';
    final all = [...p.comentarios, ..._extraComentarios];
    final lines = <String>[];
    for (final c in all) {
      final fecha = _formatFecha(c.fecha);
      lines.add('• $fecha · ${c.usuario}: ${c.texto}');
    }
    return lines.join('\n');
  }

  int get fotosClienteCount => pedido?.fotografias.cliente.length ?? 0;

  // --- Helpers de formato (port de PedidoDetailActivity) ---

  String _formatFechaHoraCorta(String raw) {
    final clean = UiText.sanitizeDbValue(raw);
    if (clean.isEmpty) return '';
    final d = DateTime.tryParse(clean.replaceFirst(' ', 'T'));
    if (d == null) return clean;
    return DateFormat('EEE d MMM · HH:mm', 'es').format(d);
  }

  String _formatFecha(String raw) {
    final clean = UiText.sanitizeDbValue(raw);
    return clean.replaceAll('T', ' ').replaceAll('.000', '');
  }

  /// Quita <br>/etiquetas y líneas de teléfono de la dirección.
  String _cleanDireccion(String raw) {
    var r = UiText.sanitizeDbValue(raw);
    r = r.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    r = r.replaceAll(RegExp(r'<[^>]+>'), '');
    final lines = r.split('\n');
    final keep = <String>[];
    for (final line in lines) {
      final l = line.trim();
      if (l.isEmpty) continue;
      final lower = l.toLowerCase();
      if (lower.contains('tel') || lower.contains('whatsapp')) continue;
      final digits = l.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 9 &&
          digits.length <= 13 &&
          l.replaceAll(RegExp(r'[\d\s]'), '').isEmpty) {
        continue; // línea que es básicamente un teléfono
      }
      keep.add(l);
    }
    return keep.join('\n');
  }

  List<String> _extractPhones(String raw) {
    final text = UiText.sanitizeDbValue(raw);
    final matches = RegExp(r'\d[\d \t]{7,}').allMatches(text);
    final out = <String>[];
    for (final m in matches) {
      final digits = m.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 9 && digits.length <= 13) out.add(digits);
    }
    return out;
  }

  List<String> _dedupePhones(List<String> phones) {
    final seen = <String>{};
    final out = <String>[];
    for (final p in phones) {
      final digits = p.replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty || seen.contains(digits)) continue;
      seen.add(digits);
      out.add(p.trim());
    }
    return out;
  }

  String _chooseBestMobile(List<String> phones) {
    if (phones.isEmpty) return '';
    for (final p in phones) {
      if (p.replaceAll(RegExp(r'\D'), '').startsWith('6')) return p;
    }
    for (final p in phones) {
      if (p.replaceAll(RegExp(r'\D'), '').startsWith('7')) return p;
    }
    return phones.first;
  }
}
