import '../../core/ui_text.dart';
import 'catalogo.dart';

double _d(dynamic v, [double def = 0]) => parseEsNumber(v, def);

/// Línea de un presupuesto guardado. Los totales se recalculan en la pantalla
/// desde `precio_unitario_sin_iva × cantidad × (1+iva_pct/100)`, porque el
/// backend puede no enviar `precio_total_linea_con_iva` (salía 0,00 €).
class DetalleLineaPres {
  final String cantidad;
  final double cantidadNum;
  final String articulo;
  final String descripcion;
  final double unitSinIva;
  final double ivaPct;
  final bool ivaFallback;

  const DetalleLineaPres({
    required this.cantidad,
    required this.cantidadNum,
    required this.articulo,
    required this.descripcion,
    required this.unitSinIva,
    required this.ivaPct,
    required this.ivaFallback,
  });

  factory DetalleLineaPres.fromJson(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());
    var cantidadNum = _d(j['cantidad'], 1);
    if (cantidadNum <= 0) cantidadNum = 1;
    var unit = _d(j['precio_unitario_sin_iva']);
    if (unit < 0) unit = 0;
    var iva = _d(j['iva_pct'], 21);
    if (iva < 0) iva = 0;
    var art = s('articulo');
    if (art.isEmpty) art = 'SIN-CODIGO';
    var desc = s('descripcion');
    if (desc.isEmpty) desc = 'Sin descripción';
    return DetalleLineaPres(
      cantidad: s('cantidad'),
      cantidadNum: cantidadNum,
      articulo: art,
      descripcion: desc,
      unitSinIva: unit,
      ivaPct: iva,
      ivaFallback: j['iva_fallback'] == true,
    );
  }

  // Totales recalculados desde el unitario (P:636-716).
  double get unitConIva => roundHalfUp(unitSinIva * (1 + roundHalfUp(ivaPct / 100, 6)), 6);
  double get totalSinIva => roundHalfUp(unitSinIva * cantidadNum, 6);
  double get totalConIva => roundHalfUp(unitConIva * cantidadNum, 6);
}

/// Detalle de un presupuesto (get_presupuesto_instalador_detalle).
class PresupuestoDetalle {
  final int idNum;
  final String id;
  final String numeroPedido;
  final String cliente;
  final String direccion;
  final String telefono;
  final String email;
  final String estado;
  final String equipo;
  final String usuario;
  final String fecha;
  final String pdfUrl;
  final String firmaUrl;
  final double importeSinIva;
  final double importeIva;
  final double importeConIva;
  final bool mailEnviado;
  final bool canEdit;
  final List<DetalleLineaPres> lineas;

  const PresupuestoDetalle({
    required this.idNum,
    required this.id,
    required this.numeroPedido,
    required this.cliente,
    required this.direccion,
    required this.telefono,
    required this.email,
    required this.estado,
    required this.equipo,
    required this.usuario,
    required this.fecha,
    required this.pdfUrl,
    required this.firmaUrl,
    required this.importeSinIva,
    required this.importeIva,
    required this.importeConIva,
    required this.mailEnviado,
    required this.canEdit,
    required this.lineas,
  });

  /// Absolutiza rutas relativas con base https://clminstal.es (P:1240-1252).
  static String _absoluteUrl(String? raw) {
    final clean = UiText.sanitizeDbValue(raw);
    if (clean.isEmpty) return '';
    final lower = clean.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return clean;
    }
    if (clean.startsWith('/')) return 'https://clminstal.es$clean';
    return 'https://clminstal.es/$clean';
  }

  factory PresupuestoDetalle.fromJson(
      Map<String, dynamic> root, Map<String, dynamic> p) {
    String s(String k) => UiText.sanitizeDbValue(p[k]?.toString());
    final lineas = <DetalleLineaPres>[];
    if (root['lineas'] is List) {
      for (final l in root['lineas'] as List) {
        if (l is Map) {
          lineas.add(DetalleLineaPres.fromJson(Map<String, dynamic>.from(l)));
        }
      }
    }
    // pdf_url con fallback pdf; foto_firma_url con fallback foto_firma.
    var pdf = s('pdf_url');
    if (pdf.isEmpty) pdf = s('pdf');
    var firma = s('foto_firma_url');
    if (firma.isEmpty) firma = s('foto_firma');
    final idNum = int.tryParse('${p['id_presupuesto']}') ?? 0;
    final estado = s('estado');
    return PresupuestoDetalle(
      idNum: idNum,
      id: idNum > 0 ? '$idNum' : s('id_presupuesto'),
      numeroPedido: s('numero_pedido'),
      cliente: s('nombre_cliente'),
      // La dirección puede llegar con <br> y el teléfono incrustado; se limpia
      // igual que en Inicio/Búsqueda (el teléfono se muestra en su propia fila).
      direccion: UiText.limpiarDireccion(p['direccion_cliente']?.toString()),
      telefono: s('telefono'),
      email: s('email_cliente'),
      estado: estado,
      equipo: s('equipo_instaladores'),
      usuario: s('usuario_instalador'),
      fecha: s('fecha_presupuesto'),
      pdfUrl: _absoluteUrl(pdf),
      firmaUrl: _absoluteUrl(firma),
      importeSinIva: _d(p['importe_sin_iva']),
      importeIva: _d(p['importe_iva']),
      importeConIva: _d(p['importe_con_iva']),
      mailEnviado: p['mail_enviado'] == true,
      // can_edit && estado != CANCELADO (P:335).
      canEdit: root['can_edit'] == true &&
          estado.toUpperCase() != 'CANCELADO',
      lineas: lineas,
    );
  }
}

/// Línea editable del detalle en modo edición. Puede venir de una línea
/// existente (precio unitario fijo) o de un producto del catálogo (con tramos).
class EditableDetalleLinea {
  final int localId;
  int? catalogProductId;
  CatalogProduct? product;
  String articulo;
  String descripcion;
  double quantity;
  double fixedUnitSinIva;
  double ivaPct;
  bool ivaFallback;

  EditableDetalleLinea({
    required this.localId,
    this.catalogProductId,
    this.product,
    this.articulo = 'SIN-CODIGO',
    this.descripcion = 'Sin descripción',
    this.quantity = 1,
    this.fixedUnitSinIva = 0,
    this.ivaPct = 21,
    this.ivaFallback = false,
  });

  factory EditableDetalleLinea.fromExisting(int localId, DetalleLineaPres l) {
    return EditableDetalleLinea(
      localId: localId,
      articulo: l.articulo,
      descripcion: l.descripcion,
      quantity: l.cantidadNum,
      fixedUnitSinIva: l.unitSinIva,
      ivaPct: l.ivaPct,
      ivaFallback: l.ivaFallback,
    );
  }

  factory EditableDetalleLinea.fromProduct(int localId, CatalogProduct p) {
    return EditableDetalleLinea(
      localId: localId,
      catalogProductId: p.idProduct,
      product: p,
      articulo: p.codigo.isEmpty ? 'SIN-CODIGO' : p.codigo,
      descripcion: p.descripcion,
      quantity: 1,
      ivaPct: p.ivaPct,
      ivaFallback: p.ivaFallback,
    );
  }

  double get unitSinIva {
    if (product != null) {
      var u = product!.priceFor(quantity).unitSinIva;
      if (u < 0) u = 0;
      return u;
    }
    return fixedUnitSinIva < 0 ? 0 : fixedUnitSinIva;
  }

  double get _iva {
    if (product != null) {
      final p = product!.ivaPct;
      return p < 0 ? 0 : p;
    }
    return ivaPct < 0 ? 0 : ivaPct;
  }

  bool get _ivaFallback => product != null ? product!.ivaFallback : ivaFallback;

  double get effectiveIvaPct => _iva;
  bool get effectiveIvaFallback => _ivaFallback;

  double get unitConIva =>
      roundHalfUp(unitSinIva * (1 + roundHalfUp(_iva / 100, 6)), 6);
  double get totalSinIva => roundHalfUp(unitSinIva * quantity, 6);
  double get totalConIva => roundHalfUp(unitConIva * quantity, 6);
}
