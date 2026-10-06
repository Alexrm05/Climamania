import 'package:climamania_app/data/models/consumible_tarifa.dart';
import 'package:flutter_test/flutter_test.dart';

/// Manguera de 100 m: el formato trae 100 unidades.
ConsumibleTarifa _manguera() => ConsumibleTarifa.fromJson({
      'id': 42,
      'id_gotel': 19857,
      'codigo': 'CINST0300010',
      'nombre': 'MANGUERA 3X2,5 BLANCA VV-F (METRO) ROLLO 100M',
      'descripcion': 'MANGUERA CABLE ELECTRICO 3 HILOS X 2,5 MM2',
      'texto_formato': 'Rollo 100 m · 1 ud',
      'unidad_venta': 'metro',
      'precio_formato': '94.00',
      'precio_unidad': '0.9400',
      'unidades_por_formato': '100.0000',
      'foto_url': 'https://clminstal.es/imagenes/consumibles/CINST0300010.jpg?v=1a2b',
      'fecha_precios': '06/10/2026 12:30',
    });

void main() {
  test('ConsumibleTarifa lee la tarifa', () {
    final a = _manguera();
    expect(a.id, 42);
    expect(a.idGotel, 19857);
    expect(a.precioFormato, 94);
    expect(a.precioUnidad, 0.94);
    expect(a.unidadesPorFormato, 100);
    expect(a.muestraPrecioUnidad, isTrue);
  });

  test('un artículo que se vende suelto no enseña precio por unidad', () {
    final a = ConsumibleTarifa.fromJson({
      'id': 7, 'codigo': 'CINST0400051', 'descripcion': 'SOPORTE',
      'unidad_venta': 'ud', 'precio_formato': '12.50',
      'precio_unidad': '12.50', 'unidades_por_formato': '1.0000',
    });
    expect(a.muestraPrecioUnidad, isFalse);
  });

  test('el carrito cuenta formatos completos, no unidades sueltas', () {
    final l = LineaPedidoConsumible(articulo: _manguera(), cantidadFormatos: 2);
    expect(l.unidades, 200); // 2 rollos de 100 m
    expect(l.importe, 188); // 2 × 94,00
    expect(l.toJson(), {'id': 42, 'cantidad_formatos': 2});
  });

  test('la búsqueda mira código, descripción y nombre', () {
    final a = _manguera();
    expect(a.textoBusqueda.contains('cinst0300010'), isTrue);
    expect(a.textoBusqueda.contains('manguera'), isTrue);
    expect(a.textoBusqueda.contains('hilos'), isTrue);
  });

  test('formatoEuros usa el formato español', () {
    expect(formatoEuros(94), '94,00 €');
    expect(formatoEuros(0.94, decimales: 4), '0,9400 €');
    expect(formatoEuros(1234.5), '1.234,50 €');
  });

  test('formatoUnidades quita los ceros de relleno', () {
    expect(formatoUnidades(200), '200');
    expect(formatoUnidades(3.5), '3,5');
    expect(formatoUnidades(0.25), '0,25');
  });

  group('ResultadoPedidoConsumibles', () {
    test('pedido enviado con los dos correos', () {
      final r = ResultadoPedidoConsumibles.fromJson({
        'success': true, 'referencia': 'PC-000123',
        'email_compras_enviado': true, 'email_confirmacion_enviado': true,
      });
      expect(r.ok, isTrue);
      expect(r.referencia, 'PC-000123');
      expect(r.conAvisoCorreo, isFalse);
    });

    test('pedido registrado pero sin correo: hay que avisar', () {
      final r = ResultadoPedidoConsumibles.fromJson({
        'success': true, 'referencia': 'PC-000124',
        'email_compras_enviado': false, 'email_confirmacion_enviado': true,
        'message': 'Pedido PC-000124 registrado, pero no se pudo enviar el correo',
      });
      expect(r.conAvisoCorreo, isTrue);
    });
  });
}
