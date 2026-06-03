/// Formato de importe en euros con coma decimal (estilo español): "1.234,56 €".
String euros(double v) {
  final fixed = v.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final dec = parts.length > 1 ? parts[1] : '00';
  // Separador de miles con punto.
  final buf = StringBuffer();
  final neg = intPart.startsWith('-');
  final digits = neg ? intPart.substring(1) : intPart;
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${neg ? '-' : ''}$buf,$dec €';
}
