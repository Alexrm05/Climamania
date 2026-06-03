import '../../core/ui_text.dart';

double _d(dynamic v) =>
    double.tryParse((v ?? '').toString().replaceAll(',', '.')) ?? 0;

/// Línea de un presupuesto guardado.
class DetalleLineaPres {
  final String cantidad;
  final String articulo;
  final String descripcion;
  final double totalSinIva;
  final double ivaPct;
  final double totalConIva;

  const DetalleLineaPres({
    required this.cantidad,
    required this.articulo,
    required this.descripcion,
    required this.totalSinIva,
    required this.ivaPct,
    required this.totalConIva,
  });

  factory DetalleLineaPres.fromJson(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());
    return DetalleLineaPres(
      cantidad: s('cantidad'),
      articulo: s('articulo'),
      descripcion: s('descripcion'),
      totalSinIva: _d(j['precio_total_linea'] ?? j['precio_total_linea_sin_iva']),
      ivaPct: _d(j['iva_pct']),
      totalConIva: _d(j['precio_total_linea_con_iva']),
    );
  }
}

/// Detalle de un presupuesto (get_presupuesto_instalador_detalle).
class PresupuestoDetalle {
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
    return PresupuestoDetalle(
      id: s('id_presupuesto'),
      numeroPedido: s('numero_pedido'),
      cliente: s('nombre_cliente'),
      // La dirección puede llegar con <br> y el teléfono incrustado; se limpia
      // igual que en Inicio/Búsqueda (el teléfono se muestra en su propia fila).
      direccion: UiText.limpiarDireccion(p['direccion_cliente']?.toString()),
      telefono: s('telefono'),
      email: s('email_cliente'),
      estado: s('estado'),
      equipo: s('equipo_instaladores'),
      usuario: s('usuario_instalador'),
      fecha: s('fecha_presupuesto'),
      pdfUrl: s('pdf_url'),
      firmaUrl: s('foto_firma_url'),
      importeSinIva: _d(p['importe_sin_iva']),
      importeIva: _d(p['importe_iva']),
      importeConIva: _d(p['importe_con_iva']),
      mailEnviado: p['mail_enviado'] == true,
      canEdit: root['can_edit'] == true,
      lineas: lineas,
    );
  }
}
