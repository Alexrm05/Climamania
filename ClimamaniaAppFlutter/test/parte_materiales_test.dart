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
        {'articulo': '19860', 'codigo': 'TUBFRIG14', 'articulo_padre': 'INSTAL40',
          'descripcion': 'Tubería 1/4"', 'unidad': 'm',
          'cantidad_prevista': '3.00', 'cantidad': '4.00',
          'precio_unitario_sin_iva': '2.500000'},
      ],
      'defecto': [
        {'articulo': 'TUBFRIG14', 'descripcion': 'Tubería 1/4"', 'unidad': 'm',
          'cantidad_prevista': '3.00', 'cantidad': '0.00'},
        {'articulo': 'FUNGIBLE', 'descripcion': 'Fungible', 'unidad': '-',
          'cantidad_prevista': '0.00', 'cantidad': '0.00'},
      ],
    });
    expect(p.existe, isTrue);
    expect(p.equipo, 'CLM1');
    final l = p.lineas.single;
    expect(l.articulo, '19860'); // IdGotel: es lo que se guarda
    expect(l.codigo, 'TUBFRIG14');
    expect(l.referenciaVisible, 'TUBFRIG14'); // al técnico se le enseña el código
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

  test('MaterialLinea.toJson formatea cantidades y precio', () {
    final l = MaterialLinea(
        articulo: '19860', codigo: 'X', articuloPadre: 'INSTAL40',
        descripcion: ' Desc ',
        unidad: 'ud', cantidadPrevista: 1, cantidad: 2, precioUnitarioSinIva: 1.5);
    expect(l.toJson(), {
      'articulo': '19860',
      'articulo_padre': 'INSTAL40',
      'descripcion': 'Desc',
      'unidad': 'ud',
      'cantidad_prevista': '1.00',
      'cantidad': '2.00',
      'precio_unitario_sin_iva': '1.500000',
    });
  });

  test('formatoCantidad y formatoDesviacion', () {
    expect(formatoCantidad(4), '4');
    expect(formatoCantidad(2.5), '2,5');
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

  test('MaterialCatalogo se convierte en línea guardando el IdGotel', () {
    final m = MaterialCatalogo.fromJson({
      'articulo': '19821',
      'codigo': 'CINST0400051',
      'descripcion': 'SOPORTE PLASTICO SUELO 450',
      'unidad': '',
      'precio_unitario_sin_iva': '0.000000',
    });
    expect(m.unidad, 'ud'); // sin unidad en el catálogo -> ud
    final l = m.comoLinea();
    expect(l.articulo, '19821'); // IdGotel, no el Id de la tabla
    expect(l.codigo, 'CINST0400051');
    expect(l.referenciaVisible, 'CINST0400051');
    expect(l.cantidad, 1);
    expect(l.toJson()['articulo'], '19821');
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
        {'articulo': '19860', 'codigo': 'TUBFRIG14',
          'descripcion': 'Tubería 1/4"', 'unidad': 'm',
          'cantidad_prevista': '6.00', 'cantidad': '8.00', 'desviacion': '2.00',
          'num_partes': 2, 'importe_sin_iva': '20.00'},
      ],
    });
    expect(d.soloUsuario, isTrue);
    expect(d.partes.single.numLineas, 3);
    expect(d.partes.single.totalSinIva, 12.5);
    expect(d.totales.single.referenciaVisible, 'TUBFRIG14');
    expect(d.totales.single.desviacion, 2);
    expect(d.totales.single.numPartes, 2);
  });
}
