import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Acciones externas de las tarjetas (mapa, llamada, SMS/WhatsApp) con avisos
/// cuando faltan datos. Réplica del comportamiento Android: selector nativo de
/// mapas con `geo:` (en iOS, Apple Maps), y avisos "no disponible".
class ExternalActions {
  ExternalActions._();

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static Future<void> _launch(BuildContext context, Uri uri,
      {String? fallbackError}) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted && fallbackError != null) {
        _toast(context, fallbackError);
      }
    } catch (_) {
      if (context.mounted && fallbackError != null) _toast(context, fallbackError);
    }
  }

  /// Abre el mapa en la dirección dada. En Android usa `geo:` (selector nativo);
  /// en iOS usa Apple Maps. Avisa si no hay dirección.
  static Future<void> openMaps(BuildContext context, String direccion) async {
    final dir = direccion.trim();
    if (dir.isEmpty) {
      _toast(context, 'Dirección no disponible');
      return;
    }
    final q = Uri.encodeComponent(dir);
    final uri = Platform.isIOS
        ? Uri.parse('https://maps.apple.com/?q=$q')
        : Uri.parse('geo:0,0?q=$q');
    await _launch(context, uri, fallbackError: 'No se pudo abrir el mapa');
  }

  /// Inicia una llamada. Avisa si no hay teléfono.
  static Future<void> call(BuildContext context, String telefono) async {
    final tel = telefono.trim();
    if (tel.isEmpty) {
      _toast(context, 'Teléfono no disponible');
      return;
    }
    await _launch(context, Uri.parse('tel:$tel'),
        fallbackError: 'No se pudo iniciar la llamada');
  }

  /// Envía un SMS. El cuerpo "Hola {cliente}, " solo se añade si hay cliente.
  static Future<void> sms(
      BuildContext context, String telefono, String cliente) async {
    final tel = telefono.trim();
    if (tel.isEmpty) {
      _toast(context, 'Teléfono no disponible');
      return;
    }
    final nombre = cliente.trim();
    final uri = nombre.isEmpty
        ? Uri.parse('sms:$tel')
        : Uri.parse('sms:$tel?body=${Uri.encodeComponent('Hola $nombre, ')}');
    await _launch(context, uri, fallbackError: 'No se pudo abrir Mensajes');
  }
}
