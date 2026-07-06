import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/app_config.dart';

/// Content-Type explícito por extensión del fichero, igual que Android
/// (que escribe `image/jpeg`, `video/mp4`, etc. en la parte multipart). Sin
/// esto dio envía `application/octet-stream` y el backend puede rechazarlo.
DioMediaType? mediaTypeForFilename(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0) return null;
  switch (filename.substring(dot + 1).toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return DioMediaType('image', 'jpeg');
    case 'png':
      return DioMediaType('image', 'png');
    case 'gif':
      return DioMediaType('image', 'gif');
    case 'webp':
      return DioMediaType('image', 'webp');
    case 'mp4':
      return DioMediaType('video', 'mp4');
    case 'mov':
      return DioMediaType('video', 'quicktime');
    case 'm4v':
      return DioMediaType('video', 'x-m4v');
    case '3gp':
      return DioMediaType('video', '3gpp');
    case 'webm':
      return DioMediaType('video', 'webm');
    case 'avi':
      return DioMediaType('video', 'x-msvideo');
    case 'mkv':
      return DioMediaType('video', 'x-matroska');
    case 'pdf':
      return DioMediaType('application', 'pdf');
  }
  return null;
}

/// Envoltorio sobre dio. Inyecta la `api_key` en cada petición, expone
/// `postForm` (form-urlencoded) y `getJson`, y parsea la respuesta de forma
/// tolerante (rescatando JSON embebido en HTML, igual que la app Android).
class ApiClient {
  final Dio _dio;

  ApiClient([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              // Recibimos texto plano y parseamos nosotros (tolerante).
              responseType: ResponseType.plain,
              // Dejamos pasar 4xx para poder leer cuerpos {success:false}.
              validateStatus: (s) => s != null && s < 500,
            ));

  /// POST form-urlencoded. Añade `api_key` automáticamente.
  Future<Map<String, dynamic>> postForm(
    String path,
    Map<String, String> fields,
  ) async {
    final body = <String, String>{...fields, 'api_key': AppConfig.apiKey};
    final resp = await _dio.post(
      path,
      data: body,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return _parse(resp.data);
  }

  /// GET con parámetros de query. Añade `api_key` automáticamente.
  /// Con [noCache] añade `_ts` y cabecera anti-caché (como las llamadas de
  /// visitas/incidencias pendientes en Android).
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    bool noCache = false,
  }) async {
    final q = <String, dynamic>{...?query, 'api_key': AppConfig.apiKey};
    Options? options;
    if (noCache) {
      q['_ts'] = DateTime.now().millisecondsSinceEpoch.toString();
      options = Options(headers: {'Cache-Control': 'no-cache'});
    }
    final resp = await _dio.get(path, queryParameters: q, options: options);
    return _parse(resp.data);
  }

  /// Subida multipart de un fichero (upload_foto.php). Añade `api_key`.
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required Map<String, String> fields,
    required String filePath,
    required String filename,
    String fileField = 'archivo',
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      ...fields,
      'api_key': AppConfig.apiKey,
      fileField: await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: mediaTypeForFilename(filename),
      ),
    });
    final resp = await _dio.post(
      path,
      data: form,
      onSendProgress: onProgress,
      options: Options(
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 1),
      ),
    );
    return _parse(resp.data);
  }

  /// Subida multipart desde bytes en memoria (imágenes comprimidas).
  Future<Map<String, dynamic>> uploadBytes(
    String path, {
    required Map<String, String> fields,
    required List<int> bytes,
    required String filename,
    String fileField = 'archivo',
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      ...fields,
      'api_key': AppConfig.apiKey,
      fileField: MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: mediaTypeForFilename(filename),
      ),
    });
    final resp = await _dio.post(
      path,
      data: form,
      onSendProgress: onProgress,
      options: Options(
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 1),
      ),
    );
    return _parse(resp.data);
  }

  Map<String, dynamic> _parse(dynamic data) {
    final raw = data is String ? data : (data?.toString() ?? '');
    final direct = _tryDecode(raw);
    if (direct != null) return direct;

    // Rescate de JSON embebido entre el primer '{' y el último '}'.
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      final salvaged = _tryDecode(raw.substring(start, end + 1));
      if (salvaged != null) return salvaged;
    }
    throw const FormatException('Respuesta no JSON del servidor');
  }

  Map<String, dynamic>? _tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) {
        return <String, dynamic>{'success': true, 'data': decoded};
      }
    } catch (_) {
      // No es JSON válido.
    }
    return null;
  }
}
