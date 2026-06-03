import 'package:geolocator/geolocator.dart';

/// Ubicación capturada con formato de 7 decimales (como EventLocationCaptureHelper).
class CapturedLocation {
  final double latitude;
  final double longitude;
  const CapturedLocation(this.latitude, this.longitude);

  String get latParam => latitude.toStringAsFixed(7);
  String get lngParam => longitude.toStringAsFixed(7);
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => message;
}

/// Captura de GPS con geolocator. Réplica del comportamiento Android:
/// usa la última posición conocida si es reciente, si no pide una nueva
/// con timeout de 12s.
class LocationService {
  Future<CapturedLocation> capture() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Activa la ubicación del dispositivo');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationException('Permiso de ubicación denegado');
    }

    // Última posición conocida reciente (< 5 min).
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && _isValid(last)) {
        final age = DateTime.now().difference(last.timestamp);
        if (age.inMinutes < 5) {
          return CapturedLocation(last.latitude, last.longitude);
        }
      }
    } catch (_) {
      // Ignoramos y pedimos una nueva.
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (_isValid(pos)) {
        return CapturedLocation(pos.latitude, pos.longitude);
      }
      throw LocationException('No se pudo obtener una ubicación válida');
    } on LocationException {
      rethrow;
    } catch (_) {
      throw LocationException(
          'No se pudo obtener una ubicación válida. Inténtalo de nuevo');
    }
  }

  bool _isValid(Position p) =>
      !p.latitude.isNaN &&
      !p.longitude.isNaN &&
      p.latitude.abs() <= 90 &&
      p.longitude.abs() <= 180;
}
