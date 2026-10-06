import 'package:climamania_app/data/models/parte_materiales.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('minutosEntre', () {
    test('calcula la diferencia en minutos', () {
      expect(minutosEntre('08:30', '12:15'), 225);
      expect(minutosEntre('9:00', '9:45'), 45);
    });

    test('rechaza horas inválidas o salida anterior a entrada', () {
      expect(minutosEntre('', '12:00'), isNull);
      expect(minutosEntre('25:00', '12:00'), isNull);
      expect(minutosEntre('12:00', '12:00'), isNull);
      expect(minutosEntre('13:00', '12:00'), isNull);
    });
  });

  test('formatoHoras', () {
    expect(formatoHoras(45), '45 min');
    expect(formatoHoras(120), '2 h');
    expect(formatoHoras(225), '3 h 45 min');
  });

  test('ParteMateriales.fromJson separa guardadas y por defecto', () {
    final p = ParteMateriales.fromJson({
      'success': true,
      'existe': true,
      'pedido': '71425',
      'horas': {'hora_inicio': '08:30', 'hora_final': '11:00'},
      'jornadas': [
        {'fecha': '2026-09-21', 'hora_inicio': '08:30', 'hora_final': '11:00'},
        {'fecha': '2026-09-22', 'hora_inicio': '09:00', 'hora_final': '13:30'},
      ],
      'meta': {'usuario': 'joseluis', 'equipo': 'CLM1',
        'fecha_creacion': '2026-09-21 09:00:00', 'fecha_edicion': '2026-09-21 11:05:00'},
      'lineas': [
        {'articulo': 'CINST0350011', 'articulo_padre': 'INSTAL40',
          'descripcion': 'Tubería 1/4"', 'unidad': 'm',
          'cantidad_prevista': '3.00', 'cantidad': '4.00',
          'precio_unitario_sin_iva': '2.500000'},
      ],
      'defecto': [
        {'articulo': 'CINST0350011', 'descripcion': 'Tubería 1/4"', 'unidad': 'm',
          'cantidad_prevista': '3.00', 'cantidad': '0.00'},
        {'articulo': 'CINST0200116', 'descripcion': 'Fungible', 'unidad': '-',
          'cantidad_prevista': '0.00', 'cantidad': '0.00'},
      ],
    });
    expect(p.existe, isTrue);
    expect(p.equipo, 'CLM1');
    final l = p.lineas.single;
    // Se guarda el código del catálogo: es la clave de GOTEL para el stock.
    expect(l.articulo, 'CINST0350011');
    expect(l.articuloPadre, 'INSTAL40');
    expect(l.cantidad, 4);
    expect(l.cantidadPrevista, 3);
    expect(l.desviacion, 1);
    expect(l.unidad, 'm');
    expect(l.precioUnitarioSinIva, 2.5);
    expect(l.porDefecto, isFalse);
    expect(p.defecto, hasLength(2));
    expect(p.defecto.first.porDefecto, isTrue);
    expect(p.defecto.first.relevante, isTrue); // previsión sin consumo cuenta
    expect(p.defecto.last.relevante, isFalse);
    expect(minutosEntre(p.horaInicio, p.horaFinal), 150);
    // Instalación de dos días: se conservan las dos jornadas.
    expect(p.jornadas, hasLength(2));
    expect(p.jornadas.first.fecha, DateTime(2026, 9, 21));
    expect(p.jornadas.first.minutos, 150);
    expect(p.jornadas.last.minutos, 270);
  });

  test('MaterialLinea.toJson formatea cantidades y no manda precio', () {
    final l = MaterialLinea(
        articulo: 'CINST0300010', articuloPadre: 'INSTAL40',
        descripcion: ' Desc ', unidad: 'm',
        cantidadPrevista: 1, cantidad: 3.5, precioUnitarioSinIva: 1.5);
    // El precio lo pone el servidor a 0: el coste lo calcula GOTEL.
    expect(l.toJson(), {
      'articulo': 'CINST0300010',
      'articulo_padre': 'INSTAL40',
      'descripcion': 'Desc',
      'unidad': 'm',
      'cantidad_prevista': '1.00',
      'cantidad': '3.50',
    });
  });

  test('cantidadDesdeTexto admite coma, punto y 2 decimales', () {
    expect(cantidadDesdeTexto('3,5'), 3.5); // metros de tubo
    expect(cantidadDesdeTexto('3.5'), 3.5);
    expect(cantidadDesdeTexto(' 12 '), 12);
    expect(cantidadDesdeTexto('0,125'), 0.13); // la BD solo guarda 2 decimales
    expect(cantidadDesdeTexto(''), 0);
    expect(cantidadDesdeTexto('dos'), 0);
    expect(cantidadDesdeTexto('-4'), 0);
  });

  test('lo que se ve es lo que se guarda', () {
    for (final escrito in ['3,5', '0,13', '12', '4,05', '7,25']) {
      final v = cantidadDesdeTexto(escrito);
      expect(cantidadDesdeTexto(formatoCantidad(v)), v, reason: escrito);
    }
  });

  test('formatoCantidad y formatoDesviacion', () {
    expect(formatoCantidad(4), '4');
    expect(formatoCantidad(2.5), '2,5');
    expect(formatoCantidad(3.25), '3,25'); // no se redondea a 3,3
    expect(formatoCantidad(0.13), '0,13');
    expect(formatoCantidad(12.10), '12,1');
    expect(formatoDesviacion(-0.25), '-0,25');
    expect(formatoDesviacion(0), '0');
    expect(formatoDesviacion(2), '+2');
    expect(formatoDesviacion(-1.5), '-1,5');
  });

  group('Jornada', () {
    test('calcula los minutos y sabe si está completa', () {
      final j = Jornada(fecha: DateTime(2026, 9, 29));
      expect(j.completa, isFalse);
      expect(j.minutos, isNull);
      j.horaInicio = '08:00';
      expect(j.completa, isFalse); // falta la salida
      j.horaFinal = '14:30';
      expect(j.minutos, 390);
      expect(j.completa, isTrue);
      j.horaFinal = '07:00'; // salida anterior a la llegada
      expect(j.completa, isFalse);
    });

    test('toJson manda la fecha en ISO', () {
      final j = Jornada(
          fecha: DateTime(2026, 3, 7), horaInicio: '9:05', horaFinal: '17:00');
      expect(j.toJson(), {
        'fecha': '2026-03-07',
        'hora_inicio': '9:05',
        'hora_final': '17:00',
      });
    });

    test('fromJson tolera una fecha con hora o vacía', () {
      expect(Jornada.fromJson({'fecha': '2026-09-29 00:00:00'}).fecha,
          DateTime(2026, 9, 29));
      expect(Jornada.fromJson({'fecha': ''}).completa, isFalse);
    });
  });

  test('ParteResumen suma las jornadas del parte', () {
    final d = PartesMateriales.fromJson({
      'success': true,
      'partes': [
        {'pedido': '71425', 'num_jornadas': 3, 'minutos_total': '810',
          'primera_fecha': '2026-09-21', 'ultima_fecha': '2026-09-23',
          'num_lineas': 5, 'total_sin_iva': '0.00'},
      ],
    });
    final p = d.partes.single;
    expect(p.numJornadas, 3);
    expect(formatoHoras(p.minutosTotal), '13 h 30 min');
    expect(p.primeraFecha, '2026-09-21');
    expect(p.ultimaFecha, '2026-09-23');
  });

  group('ParteMaterialesResumen', () {
    test('usa los minutos de las jornadas', () {
      final r = ParteMaterialesResumen.fromJson({
        'num_lineas': 4, 'num_jornadas': 2, 'minutos_total': '570',
        'hora_inicio': '08:00', 'hora_final': '13:00',
      });
      expect(r.hecho, isTrue);
      expect(r.minutos, 570); // no las 5 h del primer par de horas
    });

    test('con un servidor antiguo cae a las dos horas sueltas', () {
      final r = ParteMaterialesResumen.fromJson(
          {'num_lineas': 2, 'hora_inicio': '08:00', 'hora_final': '13:00'});
      expect(r.minutos, 300);
    });

    test('sin horas no inventa minutos', () {
      expect(ParteMaterialesResumen.fromJson({'num_lineas': 1}).minutos, isNull);
    });
  });

  test('MaterialCatalogo se convierte en línea guardando el código', () {
    final m = MaterialCatalogo.fromJson({
      'articulo': 'CINST0400051',
      'descripcion': 'SOPORTE PLASTICO SUELO 450',
      'unidad': '',
      'precio_unitario_sin_iva': '0.000000',
    });
    expect(m.unidad, 'ud'); // sin unidad en el catálogo -> ud
    final l = m.comoLinea();
    expect(l.articulo, 'CINST0400051'); // el código, no el Id ni el IdGotel
    expect(l.cantidad, 1);
    expect(l.toJson()['articulo'], 'CINST0400051');
  });

  test('PartesMateriales.fromJson agrega partes y totales', () {
    final d = PartesMateriales.fromJson({
      'success': true, 'desde': '2026-09-01', 'hasta': '2026-09-21', 'solo_usuario': true,
      'partes': [
        {'pedido': '71425', 'cliente': 'C', 'fecha_creacion': '2026-09-21 09:00:00',
          'hora_inicio': '08:30', 'hora_final': '11:00', 'usuario': 'joseluis',
          'equipo': 'CLM1', 'num_lineas': 3, 'total_sin_iva': '12.50'},
      ],
      'totales': [
        {'articulo': 'CINST0350011',
          'descripcion': 'Tubería 1/4"', 'unidad': 'm',
          'cantidad_prevista': '6.00', 'cantidad': '8.00', 'desviacion': '2.00',
          'num_partes': 2, 'importe_sin_iva': '20.00'},
      ],
    });
    expect(d.soloUsuario, isTrue);
    expect(d.partes.single.numLineas, 3);
    expect(d.partes.single.totalSinIva, 12.5);
    expect(d.totales.single.articulo, 'CINST0350011');
    expect(d.totales.single.desviacion, 2);
    expect(d.totales.single.numPartes, 2);
  });
}
