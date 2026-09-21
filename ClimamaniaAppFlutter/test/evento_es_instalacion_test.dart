import 'package:climamania_app/data/models/evento.dart';
import 'package:flutter_test/flutter_test.dart';

/// Casos tomados de la agenda real: las vacaciones y otras anotaciones se
/// escriben a mano y no tienen campo de tipo.
void main() {
  Evento ev(String referencia, {String title = '', String cliente = ''}) =>
      Evento.fromJson({
        'referencia': referencia,
        'title': title,
        'nombrecliente': cliente,
        'start': '2026-09-21 08:00:00',
        'end': '2026-09-21 19:00:00',
      });

  test('un pedido numérico es instalación', () {
    expect(ev('71425', title: '71425: - Danhoé', cliente: 'Danhoé').esInstalacion, isTrue);
    expect(ev('53338', title: 'ok INCIDENCIA', cliente: 'ok INCIDENCIA').esInstalacion, isTrue);
  });

  test('vacaciones en referencia, título o nombre no lo son', () {
    expect(ev('VACACIONES').esInstalacion, isFalse);
    expect(ev('Vacaciones').esInstalacion, isFalse);
    expect(ev('JO-VACACIONES').esInstalacion, isFalse);
    expect(ev('00000-AJ-VACACIONES').esInstalacion, isFalse);
    expect(ev('00000', cliente: 'VACACIONES SV').esInstalacion, isFalse);
    expect(ev('00000', title: '<p><u>00000</u>: -VACACIONES SV</p>').esInstalacion, isFalse);
  });

  test('las erratas habituales también cuentan como vacaciones', () {
    expect(ev('vaciones').esInstalacion, isFalse);
    expect(ev('vacaiones').esInstalacion, isFalse);
    expect(ev('71425', cliente: 'vacaiones Pepe').esInstalacion, isFalse);
  });

  test('reservas, visitas, ofertas y ceros no son instalaciones', () {
    expect(ev('reserva').esInstalacion, isFalse);
    expect(ev('visita').esInstalacion, isFalse);
    expect(ev('OFERTAR-INSTALACION').esInstalacion, isFalse);
    expect(ev('00000').esInstalacion, isFalse);
    expect(ev('').esInstalacion, isFalse);
  });
}
