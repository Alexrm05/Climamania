import 'package:climamania_app/data/models/pedido.dart';
import 'package:climamania_app/data/models/retirada_equipo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DetalleLinea.esEquipoDesinstalado', () {
    DetalleLinea linea(String ref) =>
        DetalleLinea(cantidad: '1', referencia: ref, nombre: 'x');

    test('reconoce las dos grafías', () {
      expect(linea('DESINTDO').esEquipoDesinstalado, isTrue);
      expect(linea('DESINSTDO').esEquipoDesinstalado, isTrue);
    });

    test('ignora mayúsculas y espacios', () {
      expect(linea(' desintdo ').esEquipoDesinstalado, isTrue);
    });

    test('no marca otras referencias', () {
      expect(linea('SPLIT3500').esEquipoDesinstalado, isFalse);
      expect(linea('').esEquipoDesinstalado, isFalse);
    });
  });

  group('RetiradaEquipo.errorParaFinalizar', () {
    String? error(RetiradaEquipo r,
            {bool fotoRetirado = false,
            bool fotoConservado = false,
            bool declaracion = false}) =>
        r.errorParaFinalizar(
            tieneFotoRetirado: fotoRetirado,
            tieneFotoConservado: fotoConservado,
            tieneDeclaracionFirmada: declaracion);

    test('bloquea hasta responder la pregunta', () {
      expect(error(RetiradaEquipo()), isNotNull);
    });

    group('rama SÍ', () {
      test('exige ambas unidades y la foto del equipo retirado', () {
        final r = RetiradaEquipo()..retiraCompleto = true;
        expect(error(r, fotoRetirado: true), contains('unidad'));

        r.unidadInteriorRetirada = true;
        r.unidadExteriorRetirada = true;
        expect(error(r), contains('foto'));
        expect(error(r, fotoRetirado: true), isNull);
      });

      test('la foto de la rama NO no cuenta', () {
        final r = RetiradaEquipo()
          ..retiraCompleto = true
          ..unidadInteriorRetirada = true
          ..unidadExteriorRetirada = true;
        expect(error(r, fotoConservado: true), isNotNull);
      });
    });

    group('rama NO', () {
      test('exige al menos un componente', () {
        final r = RetiradaEquipo()..retiraCompleto = false;
        expect(error(r, fotoConservado: true), contains('conserva'));
      });

      test('con "otros" exige el detalle', () {
        final r = RetiradaEquipo()
          ..retiraCompleto = false
          ..conserva.add('otros');
        expect(error(r, fotoConservado: true), contains('otros'));

        r.otrosDetalle = 'Soporte de pared';
        expect(error(r, fotoConservado: true, declaracion: true), isNull);
      });

      test('exige la foto de lo que conserva el cliente', () {
        final r = RetiradaEquipo()
          ..retiraCompleto = false
          ..conserva.add('compresor');
        expect(error(r), contains('foto'));
        expect(error(r, fotoRetirado: true), contains('foto'));
        expect(error(r, fotoConservado: true, declaracion: true), isNull);
      });

      test('exige la declaración firmada, después de la foto', () {
        final r = RetiradaEquipo()
          ..retiraCompleto = false
          ..conserva.add('compresor');
        expect(error(r, fotoConservado: true), contains('declaración'));
        expect(error(r, fotoConservado: true, declaracion: true), isNull);
      });

      test('errorParaDeclaracion valida solo la selección', () {
        final r = RetiradaEquipo();
        expect(r.errorParaDeclaracion, isNotNull); // aún no es rama NO
        r.retiraCompleto = false;
        expect(r.errorParaDeclaracion, contains('conserva'));
        r.conserva.add('otros');
        expect(r.errorParaDeclaracion, contains('otros'));
        r.otrosDetalle = 'Mando';
        expect(r.errorParaDeclaracion, isNull);
      });
    });
  });
}
