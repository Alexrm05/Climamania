import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../core/fecha.dart';
import '../../core/ui_text.dart';
import '../../data/models/gestion_item.dart';
import '../../data/models/pedido.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../data/repositories/search_repository.dart';
import '../../services/session_service.dart';

class PedidoController extends ChangeNotifier {
  final PedidoRepository _repo;
  final SearchRepository _search;
  final SessionService _session;
  final String referencia;
  final String clienteHint;

  PedidoController(
    this._repo,
    this._search,
    this._session, {
    required this.referencia,
    this.clienteHint = '',
  });

  bool loading = true;
  String? errorMsg;
  Pedido? pedido;
  bool savingComentario = false;
  String? deletingComentarioId; // id del comentario que se está eliminando

  // Visitas previas (mismas reglas que Android: teléfono móvil + dirección).
  bool visitasPreviasLoading = false;
  bool visitasPreviasChecked = false;
  List<GestionItem> visitasPrevias = const [];

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
    // Carga las visitas previas en segundo plano (no bloquea el detalle).
    if (pedido != null) {
      unawaited(loadVisitasPrevias());
    }
  }

  /// Busca visitas realizadas del mismo cliente (teléfono móvil coincidente y
  /// dirección solapada), replicando PedidoDetailActivity de Android.
  Future<void> loadVisitasPrevias() async {
    final p = pedido;
    if (p == null) return;
    visitasPreviasLoading = true;
    visitasPreviasChecked = false;
    _notify();

    // Móviles del pedido. Importante: entrega/facturación llegan como fijo+móvil
    // en una sola cadena ("912345678 612345678"), así que hay que SEPARAR cada
    // número antes de detectar el móvil (comparando por los últimos 9 dígitos).
    final phones = <String>{
      for (final src in [
        p.entrega?.telefono ?? '',
        p.facturacion?.telefono ?? '',
        p.direccionInstalacion,
      ])
        ..._movilesDe(src),
    };

    if (phones.isEmpty) {
      visitasPrevias = const [];
      visitasPreviasLoading = false;
      visitasPreviasChecked = true;
      _notify();
      return;
    }

    final tokensInstalacion = _tokensDireccion(p.direccionInstalacion);
    final (ok, visitas) = await _search.getVisitas(
      rol: _session.rol,
      equipo: _session.readEquipo(),
      usuario: _session.usuarioForRequests,
    );

    final result = <GestionItem>[];
    if (ok) {
      for (final v in visitas) {
        if (v.estado.trim() == '1') continue; // sin realizar
        final telV = _movil9(v.telefono);
        if (telV == null || !phones.contains(telV)) continue;
        if (!_direccionesSolapan(tokensInstalacion, _tokensDireccion(v.direccion))) {
          continue;
        }
        result.add(v);
      }
    }

    visitasPrevias = result;
    visitasPreviasLoading = false;
    visitasPreviasChecked = true;
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
      // Mostrado al instante; luego se recarga en silencio para asignarle el id
      // real del servidor (necesario para poder eliminarlo).
      _extraComentarios.add(ComentarioInstalador(
        fecha: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        usuario: usuario,
        texto: t,
      ));
      unawaited(refreshComentarios());
    }
    savingComentario = false;
    _notify();
    return (result.$1, result.$2.isEmpty ? 'Comentario guardado' : result.$2);
  }

  /// Recarga la ficha en silencio (sin spinner de pantalla completa) para
  /// refrescar los comentarios con sus ids reales.
  Future<void> refreshComentarios() async {
    try {
      final res = await _repo.getPedido(referencia);
      if (res.pedido != null) {
        pedido = res.pedido;
        _extraComentarios.clear();
        _notify();
      }
    } catch (_) {}
  }

  /// Elimina un comentario del instalador por su id (eliminar_comentario.php).
  Future<(bool, String)> eliminarComentario(ComentarioInstalador c) async {
    if (c.id.isEmpty) {
      return (false, 'Espera unos segundos e inténtalo de nuevo');
    }
    deletingComentarioId = c.id;
    _notify();
    final result = await _repo.eliminarComentario(
      referencia: referencia,
      id: c.id,
      rol: _session.rol,
      usuario: _usuarioActual,
    );
    if (result.$1) {
      await refreshComentarios();
    }
    deletingComentarioId = null;
    _notify();
    return (result.$1, result.$2.isEmpty ? 'Comentario eliminado' : result.$2);
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

  String get direccion {
    final p = pedido;
    if (p == null) return '';
    final fromEvent = _cleanDireccion(p.direccionInstalacion);
    if (fromEvent.isNotEmpty) return fromEvent;
    // Fallback: dirección de entrega (PrestaShop)
    final parts = [
      p.entrega?.direccion ?? '',
      p.entrega?.poblacion ?? '',
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(', ');
    // Segundo fallback: dirección de facturación
    final factParts = [
      p.facturacion?.direccion ?? '',
      p.facturacion?.poblacion ?? '',
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return factParts.join(', ');
  }

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

  /// Lista de comentarios (servidor + añadidos en esta sesión).
  List<ComentarioInstalador> get comentarios =>
      [...(pedido?.comentarios ?? const []), ..._extraComentarios];

  /// Fecha formateada de un comentario, para la UI.
  String fechaComentario(ComentarioInstalador c) => _formatFecha(c.fecha);

  bool get _esAdmin {
    final rol = _session.rol.trim().toLowerCase();
    return rol == 'adminclm' || rol == 'admin' || rol == 'administrador';
  }

  String get _usuarioActual =>
      _session.displayName(fallback: _session.usuario);

  /// El admin puede eliminar cualquier comentario; el instalador, solo los suyos.
  bool puedeEliminar(ComentarioInstalador c) {
    if (_esAdmin) return true;
    final autor = c.usuario.trim().toLowerCase();
    final yo = _usuarioActual.trim().toLowerCase();
    return autor.isNotEmpty && autor == yo;
  }

  // Las fotos que sube el cliente se guardan como PREINST ("previas"); la clave
  // FOTOCLI está en desuso. Por eso "Fotos del cliente" usa las previas.
  int get fotosClienteCount => pedido?.fotografias.previas.length ?? 0;

  // --- Helpers de formato (port de PedidoDetailActivity) ---

  String _formatFechaHoraCorta(String raw) => Fecha.parse(raw);

  String _formatFecha(String raw) => Fecha.parse(raw);

  // --- Helpers de visitas previas (port de PedidoDetailActivity) ---

  String _soloDigitos(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// Últimos 9 dígitos de un número si es un móvil español (empieza por 6 o 7);
  /// null si no lo es. Tolera prefijos como +34 y separa por longitud.
  String? _movil9(String raw) {
    final d = _soloDigitos(raw);
    if (d.length < 9) return null;
    final last9 = d.substring(d.length - 9);
    return (last9.startsWith('6') || last9.startsWith('7')) ? last9 : null;
  }

  /// Extrae todos los móviles (9 dígitos, empieza por 6/7) de una cadena que
  /// puede contener varios números juntos ("912345678 612345678").
  Set<String> _movilesDe(String raw) {
    final out = <String>{};
    for (final tok in UiText.sanitizeDbValue(raw).split(RegExp(r'[^0-9]+'))) {
      final m = _movil9(tok);
      if (m != null) out.add(m);
    }
    return out;
  }

  static const _stopWordsDireccion = {
    'calle', 'c', 'cl', 'avenida', 'av', 'avinguda', 'plaza', 'placa',
    'paseo', 'passeig', 'camino', 'cami', 'carretera', 'numero', 'num',
    'portal', 'piso', 'puerta', 'bloque', 'escalera', 'bajo', 'local',
    'cp', 'codigo', 'postal', 'tel', 'telefono', 'whatsapp',
  };

  String _quitarAcentos(String s) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'aaaaaeeeeiiiiooooouuuunc';
    var r = s;
    for (var i = 0; i < from.length; i++) {
      r = r.replaceAll(from[i], to[i]);
    }
    return r;
  }

  /// Tokens significativos de una dirección (sin números, palabras cortas ni
  /// preposiciones/tipos de vía), para comparar dos direcciones.
  Set<String> _tokensDireccion(String raw) {
    var clean = UiText.sanitizeDbValue(raw);
    clean = clean.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
    clean = clean.replaceAll(RegExp(r'<[^>]+>'), ' ');
    clean = _quitarAcentos(clean.toLowerCase());
    clean = clean.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    final tokens = <String>{};
    for (final part in clean.split(RegExp(r'\s+'))) {
      final t = part.trim();
      if (t.length < 3) continue;
      if (RegExp(r'^\d+$').hasMatch(t)) continue;
      if (_stopWordsDireccion.contains(t)) continue;
      tokens.add(t);
    }
    return tokens;
  }

  /// Dos direcciones "solapan" si comparten al menos un token significativo.
  bool _direccionesSolapan(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return false;
    for (final t in a) {
      if (b.contains(t)) return true;
    }
    return false;
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
      // Solo descarta etiquetas explícitas de teléfono al inicio de la línea
      // (p. ej. "Tel: 600...", "Teléfono ...", "Tfno.", "WhatsApp ..."),
      // no cualquier palabra que contenga "tel" (Castelldefels, Montellano...).
      if (RegExp(r'^(tel[ée]fono|tel|tfno|tlf|whatsapp|wsp)\b[\s.:]*\d')
          .hasMatch(lower)) {
        continue;
      }
      final digits = l.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 9 &&
          digits.length <= 13 &&
          l.replaceAll(RegExp(r'[\d\s]'), '').isEmpty) {
        continue; // línea que es básicamente un teléfono
      }
      // Teléfono pegado al final de la línea, incluso sin separador
      // (p. ej. "...BarcelonaTel. 622025625"). Se quita la etiqueta + número.
      final stripped = l.replaceFirst(
          RegExp(
              r'\s*(tel[eé]fonos?|telf|tfno|tlf|whats?app|wsp|tel)\.?\s*:?\s*[\d\s.\-]{9,}$',
              caseSensitive: false),
          '');
      keep.add(stripped.trim());
    }
    return keep.where((e) => e.isNotEmpty).join('\n');
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
