import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../core/ui_text.dart';
import '../../data/models/gestion_item.dart';
import '../../data/models/pedido.dart';
import '../../data/repositories/incidencia_repository.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../data/repositories/visita_repository.dart';
import '../../services/session_service.dart';

class PedidoController extends ChangeNotifier {
  final PedidoRepository _repo;
  final SessionService _session;
  final VisitaRepository _visitaRepo;
  final IncidenciaRepository _incidenciaRepo;
  final String referencia;
  final String clienteHint;

  PedidoController(
    this._repo,
    this._session,
    this._visitaRepo,
    this._incidenciaRepo, {
    required this.referencia,
    this.clienteHint = '',
  });

  bool loading = true;
  String? errorMsg;
  Pedido? pedido;
  bool savingComentario = false;

  // Previas asociadas a la referencia (histórico), como en el detalle Android.
  List<GestionItem> visitasPrevias = [];
  List<GestionItem> incidenciasPrevias = [];
  bool previasCargadas = false;

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
    if (pedido != null) _loadPrevias();
  }

  /// Carga las visitas e incidencias previas asociadas a la referencia, como
  /// hace PedidoDetailActivity al renderizar el pedido.
  Future<void> _loadPrevias() async {
    final rol = _session.rol;
    final equipo = _session.readEquipo();
    final usuario = _session.usuarioForRequests;
    try {
      final incidencias = await _incidenciaRepo.getPreviasPorReferencia(
        referencia: referencia,
        rol: rol,
        equipo: equipo,
        usuario: usuario,
      );
      final realizadas = await _visitaRepo.getRealizadas(
        rol: rol,
        equipo: equipo,
        usuario: usuario,
      );
      incidenciasPrevias = incidencias;
      visitasPrevias = _filtrarVisitasPrevias(realizadas);
    } catch (_) {
      // Silencioso: las previas son informativas.
    }
    previasCargadas = true;
    _notify();
  }

  /// Filtra las visitas realizadas que corresponden a este pedido. Como Android
  /// (PedidoDetailActivity: getTelefonosParaBusquedaVisitas + el filtro de
  /// asociación): exige coincidencia de teléfono MÓVIL (empieza por 6) **y**
  /// solape de al menos un token de dirección.
  List<GestionItem> _filtrarVisitasPrevias(List<GestionItem> realizadas) {
    // Solo móviles del pedido (empiezan por 6), igual que isPreferredVisitPhone.
    final phones = telefonos
        .map((p) => p.replaceAll(RegExp(r'\D'), ''))
        .where((d) => d.startsWith('6'))
        .toSet();
    final dirTokens = _tokens(direccion);
    final out = <GestionItem>[];
    for (final v in realizadas) {
      if (v.estadoRaw == '1') continue; // aún pendiente
      final vPhone = v.telefono.replaceAll(RegExp(r'\D'), '');
      final phoneMatch = vPhone.isNotEmpty && phones.contains(vPhone);
      final overlap = _tokenOverlap(_tokens(v.direccion), dirTokens);
      if (phoneMatch && overlap >= 1) out.add(v);
    }
    return out;
  }

  Set<String> _tokens(String s) {
    final clean = UiText.sanitizeDbValue(s).toLowerCase();
    const stop = {
      'calle', 'c', 'av', 'avda', 'avenida', 'piso', 'pta', 'puerta', 'nº',
      'num', 'numero', 'bajo', 'esc', 'escalera', 'de', 'la', 'el', 'los',
      'del', 'y', 's/n',
    };
    return clean
        .split(RegExp(r'[^a-z0-9áéíóúñ]+'))
        .where((t) => t.length >= 3 && !stop.contains(t))
        .toSet();
  }

  int _tokenOverlap(Set<String> a, Set<String> b) =>
      a.where(b.contains).length;

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
    // Entrega → facturación (troceando cada campo). La dirección solo se usa
    // como fallback si no hubo ningún teléfono, igual que Android.
    final principales = <String>[
      ..._extractPhones(p.entrega?.telefono ?? ''),
      ..._extractPhones(p.facturacion?.telefono ?? ''),
    ];
    if (principales.isEmpty) {
      principales.addAll(_extractPhones(p.direccionInstalacion));
    }
    return _dedupePhones(principales.where((e) => e.trim().isNotEmpty).toList());
  }

  String get telefonoPrincipal => _chooseBestMobile(telefonos);

  /// Etiqueta del teléfono según su prefijo (Móvil/Fijo), como el selector de
  /// teléfonos de Android.
  String phoneLabel(String phone) {
    var d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('34') && d.length > 9) d = d.substring(2);
    if (d.startsWith('6') || d.startsWith('7')) return 'Móvil';
    if (d.startsWith('8') || d.startsWith('9')) return 'Fijo';
    return 'Teléfono';
  }

  /// Número para WhatsApp: antepone el prefijo 34 a los números de 9 dígitos.
  String whatsappNumber(String phone) {
    var d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.length == 9) d = '34$d';
    return d;
  }

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
    // Tokeniza en números contiguos (opcional "+"), 9-13 dígitos, como Android.
    final matches = RegExp(r'\+?\d{9,13}').allMatches(text);
    final out = <String>[];
    for (final m in matches) {
      final tok = m.group(0)!;
      final digits = tok.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 9 && digits.length <= 13) out.add(tok);
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
