import '../../core/ui_text.dart';

double _d(dynamic v, [double def = 0]) =>
    double.tryParse((v ?? '').toString().replaceAll(',', '.')) ?? def;

/// Tramo de precio por cantidad mínima.
class Tramo {
  final double cantidadMinima;
  final double precioBaseSinIva;
  final double reduction;
  final String reductionType; // 'amount' | 'percentage'

  const Tramo({
    required this.cantidadMinima,
    required this.precioBaseSinIva,
    required this.reduction,
    required this.reductionType,
  });

  factory Tramo.fromJson(Map<String, dynamic> j) => Tramo(
        cantidadMinima: _d(j['cantidad_minima']),
        precioBaseSinIva: _d(j['precio_base_sin_iva']),
        reduction: _d(j['reduction']),
        reductionType:
            UiText.sanitizeDbValue(j['reduction_type']?.toString()).toLowerCase(),
      );
}

/// Precio calculado de una línea para una cantidad.
class LinePricing {
  final double unitSinIva;
  final double unitConIva;
  final double totalSinIva;
  final double totalConIva;
  final double ivaAmount;
  final double ivaPct;
  final bool ivaFallback;

  const LinePricing({
    required this.unitSinIva,
    required this.unitConIva,
    required this.totalSinIva,
    required this.totalConIva,
    required this.ivaAmount,
    required this.ivaPct,
    required this.ivaFallback,
  });
}

/// Producto del catálogo de adicionales (con tramos de precio).
class CatalogProduct {
  final int idProduct;
  final String codigo;
  final String descripcion;
  final double precioBaseSinIva;
  final double ivaPct;
  final bool ivaFallback;
  final List<Tramo> tramos;

  const CatalogProduct({
    required this.idProduct,
    required this.codigo,
    required this.descripcion,
    required this.precioBaseSinIva,
    required this.ivaPct,
    required this.ivaFallback,
    required this.tramos,
  });

  factory CatalogProduct.fromJson(Map<String, dynamic> j) {
    final tramos = <Tramo>[];
    if (j['tramos'] is List) {
      for (final t in j['tramos'] as List) {
        if (t is Map) tramos.add(Tramo.fromJson(Map<String, dynamic>.from(t)));
      }
    }
    tramos.sort((a, b) => a.cantidadMinima.compareTo(b.cantidadMinima));
    return CatalogProduct(
      idProduct: int.tryParse('${j['id_product']}') ?? 0,
      codigo: UiText.sanitizeDbValue(j['codigo']?.toString()),
      descripcion: UiText.sanitizeDbValue(j['descripcion']?.toString()),
      precioBaseSinIva: _d(j['precio_base_sin_iva']),
      ivaPct: _d(j['iva_pct'], 21),
      ivaFallback: j['iva_fallback'] == true,
      tramos: tramos,
    );
  }

  /// Precio para una cantidad, aplicando el tramo correspondiente.
  LinePricing priceFor(double quantity) {
    final q = quantity <= 0 ? 0.1 : quantity;

    double base = precioBaseSinIva;
    double reduction = 0;
    String type = 'amount';
    Tramo? best;
    for (final t in tramos) {
      if (t.cantidadMinima <= q) best = t;
    }
    if (best != null) {
      base = best.precioBaseSinIva;
      reduction = best.reduction;
      type = best.reductionType;
    }

    double discount;
    if (type == 'percentage') {
      final pct = reduction > 1 ? reduction / 100 : reduction;
      discount = base * pct;
    } else {
      discount = reduction;
    }
    var unitSinIva = base - discount;
    if (unitSinIva < 0) unitSinIva = 0;
    final unitConIva = unitSinIva * (1 + ivaPct / 100);
    final totalSinIva = unitSinIva * q;
    final totalConIva = unitConIva * q;
    return LinePricing(
      unitSinIva: unitSinIva,
      unitConIva: unitConIva,
      totalSinIva: totalSinIva,
      totalConIva: totalConIva,
      ivaAmount: totalConIva - totalSinIva,
      ivaPct: ivaPct,
      ivaFallback: ivaFallback,
    );
  }
}

/// Línea editable de un presupuesto.
class BudgetLine {
  final CatalogProduct product;
  double quantity;
  String descripcion;

  BudgetLine({required this.product, this.quantity = 1, String? descripcion})
      : descripcion = descripcion ?? product.descripcion;

  LinePricing get pricing => product.priceFor(quantity);
}

/// Resumen de un presupuesto en la búsqueda.
class PresupuestoResumen {
  final String id;
  final String numeroPedido;
  final String cliente;
  final String telefono;
  final String equipo;
  final String usuario;
  final double importeConIva;
  final String estado;
  final String fecha;
  final bool mailEnviado;

  const PresupuestoResumen({
    required this.id,
    required this.numeroPedido,
    required this.cliente,
    required this.telefono,
    required this.equipo,
    required this.usuario,
    required this.importeConIva,
    required this.estado,
    required this.fecha,
    required this.mailEnviado,
  });

  factory PresupuestoResumen.fromJson(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());
    return PresupuestoResumen(
      id: s('id_presupuesto'),
      numeroPedido: s('numero_pedido'),
      cliente: s('nombre_cliente'),
      telefono: s('telefono'),
      equipo: s('equipo_instaladores'),
      usuario: s('usuario_instalador'),
      importeConIva: _d(j['importe_con_iva']),
      estado: s('estado'),
      fecha: s('fecha_presupuesto'),
      mailEnviado: j['mail_enviado'] == true,
    );
  }
}
