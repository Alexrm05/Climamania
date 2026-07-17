import 'package:flutter/widgets.dart';

/// Escala de radios de esquina. Colapsa el caos previo (5,6,8,10,12,14,16,18,20,50,999)
/// en 4 valores: sm (inputs/botones), md (tarjetas/resaltados), lg (tarjetas
/// grandes/hero) y pill (píldoras/badges).
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;

  static final BorderRadius brSm = BorderRadius.circular(sm);
  static final BorderRadius brMd = BorderRadius.circular(md);
  static final BorderRadius brLg = BorderRadius.circular(lg);
  static final BorderRadius brPill = BorderRadius.circular(pill);
}
