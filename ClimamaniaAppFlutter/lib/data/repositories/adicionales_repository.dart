import '../../core/app_config.dart';
import '../../core/ui_text.dart';
import '../api/api_client.dart';
import '../models/catalogo.dart';
import '../models/presupuesto_detalle.dart';

/// Contexto de instalación autocompletado desde get_events + get_pedido.
class InstallationContext {
  final String referencia;
  final String cliente;
  final String direccion;
  final String telefono;
  final String email; // email de la referencia (si es válido)
  const InstallationContext({
    required this.referencia,
    required this.cliente,
    required this.direccion,
    required this.telefono,
    required this.email,
  });
}

class AdicionalesRepository {
  final ApiClient _api;

  AdicionalesRepository(this._api);

  String _s(dynamic v) => UiText.sanitizeDbValue(v?.toString());

  /// Catálogo de adicionales. Propaga el `message` del backend en el estado
  /// vacío (antes devolvía [] sin mensaje). [limit] 0 = sin límite (pantalla
  /// nueva), 20 = buscador del detalle.
  Future<({List<CatalogProduct> productos, String message})> getCatalogo(
    String q, {
    int limit = 0,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getAdicionalesCatalogo,
        query: {'q': q, 'limit': '$limit'},
        noCache: true,
      );
      if (json['success'] != true) {
        var msg = _s(json['message']);
        if (msg.isEmpty) msg = 'Catálogo no disponible';
        return (productos: <CatalogProduct>[], message: msg);
      }
      final out = <CatalogProduct>[];
      final raw = json['productos'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            final p = CatalogProduct.fromJson(Map<String, dynamic>.from(e));
            if (p.idProduct > 0) out.add(p);
          }
        }
      }
      return (productos: out, message: '');
    } catch (_) {
      return (
        productos: <CatalogProduct>[],
        message: 'No se pudo cargar el catálogo'
      );
    }
  }

  /// Resuelve el contexto de la instalación en curso (A:403-662):
  /// get_events → evento EN CURSO con referencia válida (inicio más antiguo)
  /// → get_pedido → cliente, dirección de instalación, email, teléfono.
  Future<InstallationContext?> resolveInstallationContext({
    required String rol,
    required String usuario,
    required String equipo,
  }) async {
    final ref = await _fetchCurrentReference(
      rol: rol,
      usuario: usuario,
      equipo: equipo,
    );
    if (ref.isEmpty) return null;
    return _loadInstallationHeader(ref);
  }

  /// Carga la cabecera de instalación por referencia manual (get_pedido).
  Future<InstallationContext?> resolveInstallationHeaderByRef(String ref) =>
      _loadInstallationHeader(ref);

  Future<String> _fetchCurrentReference({
    required String rol,
    required String usuario,
    required String equipo,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getEvents,
        query: {'rol': rol, 'equipo': equipo, 'usuario': usuario},
        noCache: true,
      );
      if (json['success'] != true) return '';
      final eventos = json['eventos'];
      if (eventos is! List || eventos.isEmpty) return '';

      final now = DateTime.now();
      DateTime? bestStart;
      var selectedRef = '';
      for (final ev in eventos) {
        if (ev is! Map) continue;
        final startRaw = _s(ev['start']);
        final endRaw = _s(ev['end']);
        final referencia = _s(ev['referencia']);
        if (!isPedidoValido(referencia) || startRaw.isEmpty) continue;
        final start = _parseServerDate(startRaw);
        if (start == null) continue;
        var end = endRaw.isEmpty ? null : _parseServerDate(endRaw);
        // fin implícito = inicio + 1h.
        end ??= start.add(const Duration(hours: 1));
        final enCurso = !now.isBefore(start) && now.isBefore(end);
        if (!enCurso) continue;
        if (bestStart == null || start.isBefore(bestStart)) {
          bestStart = start;
          selectedRef = referencia;
        }
      }
      return selectedRef;
    } catch (_) {
      return '';
    }
  }

  Future<InstallationContext?> _loadInstallationHeader(String referencia) async {
    try {
      final json = await _api.getJson(
        AppConfig.getPedido,
        query: {'referencia': referencia},
        noCache: true,
      );
      if (json['success'] != true) return null;
      final pedido = json['pedido'];
      if (pedido is! Map) return null;
      final p = Map<String, dynamic>.from(pedido);

      final cliente = _s(p['cliente']);
      final direccion = _s(p['direccion_instalacion']);
      final refEmail = _s(p['email_cliente']);
      final email = isValidEmail(refEmail) ? refEmail : '';

      // Teléfono: entrega → facturación.
      var telefono = '';
      if (p['entrega'] is Map) {
        telefono = _s((p['entrega'] as Map)['telefono']);
      }
      if (telefono.isEmpty && p['facturacion'] is Map) {
        telefono = _s((p['facturacion'] as Map)['telefono']);
      }

      return InstallationContext(
        referencia: referencia,
        cliente: cliente,
        direccion: direccion,
        telefono: telefono,
        email: email,
      );
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseServerDate(String raw) {
    // Formato del backend: "yyyy-MM-dd HH:mm:ss".
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})')
        .firstMatch(raw);
    if (m == null) return null;
    try {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6)!),
      );
    } catch (_) {
      return null;
    }
  }

  Future<({bool ok, String message, String idPresupuesto, String pdfUrl})>
      guardar(Map<String, String> payload) async {
    try {
      final json = await _api.postForm(AppConfig.guardarPresupuesto, payload);
      final ok = json['success'] == true;
      var msg = _s(json['message']);
      if (msg.isEmpty) {
        msg = ok ? 'Presupuesto guardado' : 'No se pudo guardar el presupuesto';
      }
      final idNum = int.tryParse('${json['id_presupuesto']}') ?? 0;
      // Mensaje de éxito con " (ID <id_presupuesto>)" (A:1364-1368).
      if (ok && idNum > 0) msg = '$msg (ID $idNum)';
      final pdf = _s(json['pdf_url'].toString().isNotEmpty
          ? json['pdf_url']
          : json['pdf']);
      return (
        ok: ok,
        message: msg,
        idPresupuesto: idNum > 0 ? '$idNum' : _s(json['id_presupuesto']),
        pdfUrl: pdf,
      );
    } catch (_) {
      return (
        ok: false,
        message: 'No se pudo guardar el presupuesto',
        idPresupuesto: '',
        pdfUrl: '',
      );
    }
  }

  /// Actualiza un presupuesto en modo edición (actualizar_presupuesto_instalador.php).
  Future<(bool, String)> actualizarPresupuesto({
    required String idPresupuesto,
    required String rol,
    required String usuario,
    required String equipo,
    required String nombreCliente,
    required String direccionCliente,
    required String telefono,
    required String emailCliente,
    required String lineasJson,
  }) async {
    try {
      final json = await _api.postForm(AppConfig.actualizarPresupuesto, {
        'id_presupuesto': idPresupuesto,
        'rol': rol,
        'usuario': usuario,
        'equipo': equipo,
        'nombre_cliente': nombreCliente,
        'direccion_cliente': direccionCliente,
        'telefono': telefono,
        'email_cliente': emailCliente,
        'lineas_json': lineasJson,
      });
      final ok = json['success'] == true;
      var msg = _s(json['message']);
      if (msg.isEmpty) {
        msg = ok
            ? 'Presupuesto actualizado'
            : 'No se pudo actualizar el presupuesto';
      }
      return (ok, msg);
    } catch (_) {
      return (false, 'No se pudo actualizar el presupuesto');
    }
  }

  Future<({bool ok, String message, List<PresupuestoResumen> items, bool hasMore, List<String> estados})>
      getPresupuestos({
    required String rol,
    required String usuario,
    required String equipo,
    required String q,
    required String estado,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getPresupuestos,
        query: {
          'rol': rol,
          'usuario': usuario,
          'equipo': equipo,
          'q': q,
          'estado': estado,
          'page': '$page',
          'page_size': '$pageSize',
        },
        noCache: true,
      );
      if (json['success'] != true) {
        var msg = _s(json['message']);
        if (msg.isEmpty) msg = 'No se pudo cargar la búsqueda';
        return (
          ok: false,
          message: msg,
          items: <PresupuestoResumen>[],
          hasMore: false,
          estados: <String>[],
        );
      }
      final items = <PresupuestoResumen>[];
      if (json['presupuestos'] is List) {
        for (final e in json['presupuestos'] as List) {
          if (e is Map) {
            final r =
                PresupuestoResumen.fromJson(Map<String, dynamic>.from(e));
            // Descarta resúmenes con id<=0.
            if (r.idNum > 0) items.add(r);
          }
        }
      }
      final estados = <String>[];
      if (json['estados_disponibles'] is List) {
        for (final e in json['estados_disponibles'] as List) {
          estados.add(e.toString());
        }
      }
      return (
        ok: true,
        message: '',
        items: items,
        hasMore: json['has_more'] == true,
        estados: estados,
      );
    } catch (_) {
      return (
        ok: false,
        message: 'No se pudo cargar la búsqueda',
        items: <PresupuestoResumen>[],
        hasMore: false,
        estados: <String>[],
      );
    }
  }

  Future<({bool ok, String message, PresupuestoDetalle? detalle})> getDetalle(
    String id, {
    required String rol,
    required String usuario,
    required String equipo,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getPresupuestoDetalle,
        query: {
          'id_presupuesto': id,
          'rol': rol,
          'usuario': usuario,
          'equipo': equipo,
        },
        noCache: true,
      );
      final ok = json['success'] == true;
      final p = json['presupuesto'];
      if (!ok || p is! Map) {
        var msg = _s(json['message']);
        if (msg.isEmpty) msg = 'No se pudo cargar el presupuesto';
        return (ok: false, message: msg, detalle: null);
      }
      return (
        ok: true,
        message: '',
        detalle: PresupuestoDetalle.fromJson(json, Map<String, dynamic>.from(p)),
      );
    } catch (_) {
      return (ok: false, message: 'No se pudo cargar el presupuesto', detalle: null);
    }
  }

  Future<(bool, String)> cancelar(
    String id, {
    required String rol,
    required String usuario,
    required String equipo,
  }) async {
    try {
      final json = await _api.postForm(AppConfig.cancelarPresupuesto, {
        'id_presupuesto': id,
        'rol': rol,
        'usuario': usuario,
        'equipo': equipo,
      });
      final ok = json['success'] == true;
      final msg = _s(json['message']);
      return (ok, msg.isEmpty ? (ok ? 'Presupuesto cancelado' : 'No se pudo cancelar el presupuesto') : msg);
    } catch (_) {
      return (false, 'No se pudo cancelar el presupuesto');
    }
  }
}

/// Réplica de `isPedidoValido`: no vacío y contiene al menos un dígito.
bool isPedidoValido(String? pedido) {
  final clean = UiText.sanitizeDbValue(pedido);
  return clean.isNotEmpty && RegExp(r'\d').hasMatch(clean);
}

/// Réplica de `isManualPedido`: empieza por "MANUAL-".
bool isManualPedido(String? pedido) {
  final clean = UiText.sanitizeDbValue(pedido).toUpperCase();
  return clean.startsWith('MANUAL-');
}

/// Validación de email con regex (no solo contains '@').
final _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$");

bool isValidEmail(String? email) {
  final clean = UiText.sanitizeDbValue(email);
  return clean.isNotEmpty && _emailRegex.hasMatch(clean);
}
