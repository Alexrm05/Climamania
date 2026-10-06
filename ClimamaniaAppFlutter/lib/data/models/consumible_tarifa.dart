import '../../core/ui_text.dart';

double _num(dynamic v) =>
    double.tryParse((v ?? '').toString().replaceAll(',', '.')) ?? 0;

/// Artículo de la tarifa de consumibles (ClimaSinc_ClimaInstal_Consumibles).
/// Los precios se leen del servidor cada vez que se abre la tarifa: no se
/// guardan en la app porque cambian.
class ConsumibleTarifa {
  /// Id de la fila del catálogo: es lo que se manda al pedir.
  final int id;
  final int idGotel;
  final String codigo;
  final String nombre;
  final String descripcion;

  /// En qué se vende: "Rollo 100 m · 1 ud".
  final String textoFormato;

  /// Unidad suelta: metro, ud, m²…
  final String unidadVenta;

  /// Precio sin IVA del formato completo.
  final double precioFormato;

  /// Precio sin IVA por unidad.
  final double precioUnidad;

  /// Unidades que trae un formato (Formato × Factor).
  final double unidadesPorFormato;
  final String fotoUrl;
  final String fechaPrecios;

  const ConsumibleTarifa({
    required this.id,
    required this.idGotel,
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.textoFormato,
    required this.unidadVenta,
    required this.precioFormato,
    required this.precioUnidad,
    required this.unidadesPorFormato,
    required this.fotoUrl,
    required this.fechaPrecios,
  });

  /// Solo tiene sentido enseñar el precio por unidad si el formato trae más
  /// de una.
  bool get muestraPrecioUnidad => unidadesPorFormato > 1 && precioUnidad > 0;

  /// Texto para buscar: código, descripción y nombre.
  String get textoBusqueda =>
      '$codigo $descripcion $nombre'.toLowerCase();

  factory ConsumibleTarifa.fromJson(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());
    return ConsumibleTarifa(
      id: int.tryParse('${j['id']}') ?? 0,
      idGotel: int.tryParse('${j['id_gotel']}') ?? 0,
      codigo: s('codigo'),
      nombre: s('nombre'),
      descripcion: s('descripcion'),
      textoFormato: s('texto_formato'),
      unidadVenta: s('unidad_venta'),
      precioFormato: _num(j['precio_formato']),
      precioUnidad: _num(j['precio_unidad']),
      unidadesPorFormato: _num(j['unidades_por_formato']),
      fotoUrl: s('foto_url'),
      fechaPrecios: s('fecha_precios'),
    );
  }
}

/// Línea del carrito: un artículo y cuántos formatos completos se piden.
class LineaPedidoConsumible {
  final ConsumibleTarifa articulo;
  int cantidadFormatos;

  LineaPedidoConsumible({required this.articulo, this.cantidadFormatos = 1});

  double get importe => cantidadFormatos * articulo.precioFormato;

  /// Unidades totales: 2 rollos de 100 m son 200 metros.
  double get unidades => cantidadFormatos * articulo.unidadesPorFormato;

  Map<String, dynamic> toJson() => {
        'id': articulo.id,
        'cantidad_formatos': cantidadFormatos,
      };
}

/// Lo que responde el servidor al enviar el pedido.
class ResultadoPedidoConsumibles {
  final bool ok;
  final String referencia;
  final String message;
  final bool emailComprasEnviado;
  final bool emailConfirmacionEnviado;

  const ResultadoPedidoConsumibles({
    required this.ok,
    required this.referencia,
    required this.message,
    this.emailComprasEnviado = false,
    this.emailConfirmacionEnviado = false,
  });

  /// Pedido guardado pero con algún correo sin salir: hay que avisar.
  bool get conAvisoCorreo =>
      ok && (!emailComprasEnviado || !emailConfirmacionEnviado);

  factory ResultadoPedidoConsumibles.fromJson(Map<String, dynamic> j) =>
      ResultadoPedidoConsumibles(
        ok: j['success'] == true,
        referencia: UiText.sanitizeDbValue(j['referencia']?.toString()),
        message: UiText.sanitizeDbValue(j['message']?.toString()),
        emailComprasEnviado: j['email_compras_enviado'] == true,
        emailConfirmacionEnviado: j['email_confirmacion_enviado'] == true,
      );
}

/// Precio en formato español: 94 → "94,00 €".
String formatoEuros(double v, {int decimales = 2}) {
  final partes = v.toStringAsFixed(decimales).split('.');
  final entero = partes[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  return '$entero,${partes[1]} €';
}

/// Cantidad sin ceros de relleno: 100 → "100", 3,5 → "3,5".
String formatoUnidades(double v) {
  var s = v.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s.replaceAll('.', ',');
}

/// Línea de un pedido ya enviado (solo lectura).
class LineaPedidoEnviado {
  final String codigo;
  final String descripcion;
  final String textoFormato;
  final String unidadVenta;
  final double cantidadFormatos;
  final double cantidadUnidades;
  final double precioFormato;
  final double importeLinea;

  const LineaPedidoEnviado({
    required this.codigo,
    required this.descripcion,
    required this.textoFormato,
    required this.unidadVenta,
    required this.cantidadFormatos,
    required this.cantidadUnidades,
    required this.precioFormato,
    required this.importeLinea,
  });

  factory LineaPedidoEnviado.fromJson(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());
    return LineaPedidoEnviado(
      codigo: s('codigo'),
      descripcion: s('descripcion'),
      textoFormato: s('texto_formato'),
      unidadVenta: s('unidad_venta'),
      cantidadFormatos: _num(j['cantidad_formatos']),
      cantidadUnidades: _num(j['cantidad_unidades']),
      precioFormato: _num(j['precio_formato']),
      importeLinea: _num(j['importe_linea']),
    );
  }
}

/// Pedido de consumibles ya enviado. No se puede modificar desde la app:
/// esto es solo para que el instalador vea lo que pidió.
class PedidoEnviado {
  final String referencia;
  final String fecha; // YYYY-MM-DD HH:MM:SS
  final String equipo;
  final String estado;
  final String observaciones;
  final int numLineas;
  final double totalSinIva;

  /// Algún correo no salió: la oficina puede no haberse enterado.
  final bool avisoCorreo;
  final List<LineaPedidoEnviado> lineas;

  const PedidoEnviado({
    required this.referencia,
    required this.fecha,
    required this.equipo,
    required this.estado,
    required this.observaciones,
    required this.numLineas,
    required this.totalSinIva,
    required this.avisoCorreo,
    required this.lineas,
  });

  factory PedidoEnviado.fromJson(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());
    final raw = j['lineas'];
    return PedidoEnviado(
      referencia: s('referencia'),
      fecha: s('fecha'),
      equipo: s('equipo'),
      estado: s('estado'),
      observaciones: s('observaciones'),
      numLineas: int.tryParse('${j['num_lineas']}') ?? 0,
      totalSinIva: _num(j['total_sin_iva']),
      avisoCorreo: j['aviso_correo'] == true,
      lineas: [
        for (final e in (raw is List ? raw : const []))
          if (e is Map) LineaPedidoEnviado.fromJson(Map<String, dynamic>.from(e)),
      ],
    );
  }
}
