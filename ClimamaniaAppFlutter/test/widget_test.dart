import 'package:flutter_test/flutter_test.dart';
import 'package:climamania_app/core/ui_text.dart';

void main() {
  group('UiText.sanitizeDbValue', () {
    test('devuelve "" para valores nulos/placeholder', () {
      expect(UiText.sanitizeDbValue(null), '');
      expect(UiText.sanitizeDbValue('-'), '');
      expect(UiText.sanitizeDbValue('null'), '');
      expect(UiText.sanitizeDbValue('UNDEFINED'), '');
      expect(UiText.sanitizeDbValue('N/A'), '');
      expect(UiText.sanitizeDbValue('  '), '');
    });

    test('recorta y conserva valores reales', () {
      expect(UiText.sanitizeDbValue('  Calle Mayor 1  '), 'Calle Mayor 1');
      expect(UiText.sanitizeDbValue('Pepe'), 'Pepe');
    });

    test('reemplaza el espacio duro (NBSP, U+00A0) por espacio normal', () {
      expect(UiText.sanitizeDbValue('A B'), 'A B');
    });
  });

  group('UiText.isMissingDbValue', () {
    test('detecta valores ausentes', () {
      expect(UiText.isMissingDbValue('-'), true);
      expect(UiText.isMissingDbValue('Madrid'), false);
    });
  });
}
