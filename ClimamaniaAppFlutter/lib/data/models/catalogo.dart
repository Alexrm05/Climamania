import '../../core/ui_text.dart';

/// Parser de números en formato español: separador de miles "." y decimal ",".
/// Réplica de `parseBigDecimal` de Android pero saneando también el separador
/// de miles: "1.234,56" → 1234.56, "1234,56" → 1234.56, "1234.56" → 1234.56.
/// Un total con miles se mostraba 0,00 € por parsear mal el punto de miles.
double parseEsNumber(dynamic v, [double def = 0]) {
  var raw = UiText.sanitizeDbValue(v?.toString());
  if (raw.isEmpty) return def;
  final hasComma = raw.contains(',');
  final hasDot = raw.contains('.');
  if (hasComma && hasDot) {
    // "1.234,56" → el punto es separador de miles, la coma decimal.
    raw = raw.replaceAll('.', '').replaceAll(',', '.');
  } else if (hasComma) {
    // "1234,56" → coma decimal.
    raw = raw.replaceAll(',', '.');
  } else if (hasDot) {
    // Solo puntos. Si hay varios puntos son separadores de miles ("1.234.567").
    if ('.'.allMatches(raw).length > 1) {
      raw = raw.replaceAll('.', '');
    }
    // Un único punto se deja como decimal ("1234.56").
  }
  return double.tryParse(raw) ?? def;
}

// Alias corto usado internamente por los modelos.
double _d(dynamic v, [double def = 0]) => parseEsNumber(v, def);

/// Redondeo HALF_UP a [scale] decimales (replica BigDecimal.setScale HALF_UP).
double roundHalfUp(double value, int scale) {
  if (value.isNaN || value.isInfinite) return 0;
  final factor = _pow10(scale);
  final scaled = value * factor;
  // HALF_UP: 0.5 se redondea hacia arriba en magnitud.
  final rounded = scaled < 0
      ? -(( -scaled) + 0.5).floorToDouble()
      : (scaled + 0.5).floorToDouble();
  return rounded / factor;
}

double _pow10(int n) {
  var r = 1.0;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

/// Formatea un porcentaje conservando hasta 2 decimales sin ceros finales:
/// 21 → "21%", 10.5 → "10,5%", 10.50 → "10,5%". Réplica de `formatPercent`.
String formatPercent(double percent) {
  final rounded = roundHalfUp(percent, 2);
  var s = rounded.toStringAsFixed(2);
  // Quitar ceros finales y el separador si sobra.
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
  }
  s = s.replaceAll('.', ',');
  return '$s%';
}

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
    // precio base saneado a >= 0 (clamp del catálogo).
    var precioBase = _d(j['precio_base_sin_iva']);
    if (precioBase < 0) precioBase = 0;
    var ivaPct = _d(j['iva_pct'], 21);
    if (ivaPct < 0) ivaPct = 0;

    var descripcion = UiText.sanitizeDbValue(j['descripcion']?.toString());
    if (descripcion.isEmpty) descripcion = 'Descripción no disponible';

    // Parseo + saneamiento de tramos (réplica de parseCatalogProduct).
    final tramos = <Tramo>[];
    if (j['tramos'] is List) {
      for (final t in j['tramos'] as List) {
        if (t is! Map) continue;
        final tj = Map<String, dynamic>.from(t);
        var qtyMin = _d(tj['cantidad_minima'], 1);
        if (qtyMin <= 0) qtyMin = 1;
        var price = _d(tj['precio_base_sin_iva'], precioBase);
        if (price < 0) price = 0;
        var reduction = _d(tj['reduction']);
        if (reduction < 0) reduction = 0;
        var reductionType = UiText.sanitizeDbValue(tj['reduction_type']?.toString())
            .toLowerCase();
        if (reductionType != 'amount' && reductionType != 'percentage') {
          reductionType = 'amount';
        }
        tramos.add(Tramo(
          cantidadMinima: qtyMin,
          precioBaseSinIva: price,
          reduction: reduction,
          reductionType: reductionType,
        ));
      }
    }
    tramos.sort((a, b) => a.cantidadMinima.compareTo(b.cantidadMinima));
    // Inserta un tramo sintético qtyMin=1 si no hay tramos o el primero > 1.
    if (tramos.isEmpty) {
      tramos.add(Tramo(
        cantidadMinima: 1,
        precioBaseSinIva: precioBase,
        reduction: 0,
        reductionType: 'amount',
      ));
    } else if (tramos.first.cantidadMinima > 1) {
      tramos.insert(
        0,
        Tramo(
          cantidadMinima: 1,
          precioBaseSinIva: precioBase,
          reduction: 0,
          reductionType: 'amount',
        ),
      );
    }

    return CatalogProduct(
      idProduct: int.tryParse('${j['id_product']}') ?? 0,
      codigo: UiText.sanitizeDbValue(j['codigo']?.toString()),
      descripcion: descripcion,
      precioBaseSinIva: precioBase,
      ivaPct: ivaPct,
      ivaFallback: j['iva_fallback'] == true,
      tramos: tramos,
    );
  }

  /// Tramo aplicable a una cantidad: el de mayor `qtyMin` que no la supere.
  Tramo _resolveTier(double q) {
    var selected = tramos.first;
    for (final t in tramos) {
      if (t.cantidadMinima <= q) {
        selected = t;
      } else {
        break;
      }
    }
    return selected;
  }

  /// Precio para una cantidad, aplicando el tramo correspondiente.
  /// Réplica de `recalculateLine` con redondeo intermedio a 6 decimales HALF_UP.
  LinePricing priceFor(double quantity) {
    final q = quantity <= 0 ? 0.1 : quantity;
    final tramo = _resolveTier(q);
    var base = tramo.precioBaseSinIva;
    if (base < 0) base = 0;

    double discount;
    if (tramo.reductionType == 'percentage') {
      var factor = tramo.reduction;
      // Si llega "10" lo tratamos como 10%, si llega "0.10" como 10%.
      if (factor > 1) factor = roundHalfUp(factor / 100, 6);
      if (factor < 0) factor = 0;
      if (factor > 1) factor = 1;
      discount = roundHalfUp(base * factor, 6);
    } else {
      discount = tramo.reduction;
    }
    if (discount < 0) discount = 0;

    var unitSinIva = base - discount;
    if (unitSinIva < 0) unitSinIva = 0;

    final ivaMultiplier = 1 + roundHalfUp(ivaPct / 100, 6);
    final unitConIva = roundHalfUp(unitSinIva * ivaMultiplier, 6);
    final totalSinIva = roundHalfUp(unitSinIva * q, 6);
    final totalConIva = roundHalfUp(unitConIva * q, 6);
    final ivaAmount = roundHalfUp(totalConIva - totalSinIva, 6);
    return LinePricing(
      unitSinIva: unitSinIva,
      unitConIva: unitConIva,
      totalSinIva: totalSinIva,
      totalConIva: totalConIva,
      ivaAmount: ivaAmount,
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
  final int idNum;
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
    required this.idNum,
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
    final idNum = int.tryParse('${j['id_presupuesto']}') ?? 0;
    return PresupuestoResumen(
      idNum: idNum,
      id: idNum > 0 ? '$idNum' : s('id_presupuesto'),
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
