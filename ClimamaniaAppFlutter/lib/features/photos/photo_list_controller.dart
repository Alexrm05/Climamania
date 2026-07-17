import 'package:flutter/foundation.dart';

import '../../core/app_config.dart';
import '../../core/ui_text.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../services/session_service.dart';

class PhotoListController extends ChangeNotifier {
  final PedidoRepository _pedidoRepo;
  final ApiClient _api;
  final SessionService _session;
  final String referencia;
  final String categoria;
  final String clave;

  PhotoListController(
    this._pedidoRepo,
    this._api,
    this._session, {
    required this.referencia,
    required this.categoria,
    required this.clave,
    List<String> initial = const [],
  }) : fotos = List<String>.from(initial);

  bool loading = true;
  bool uploading = false;
  double uploadProgress = 0;
  String? errorMsg;
  List<String> fotos;

  bool _disposed = false;

  bool get canUpload => clave.isNotEmpty;

  void init() => load();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    errorMsg = null;
    _notify();
    try {
      final res = await _pedidoRepo.getPedido(referencia);
      if (res.pedido != null) {
        fotos = res.pedido!.fotografias.byCategoria(categoria);
      } else {
        errorMsg =
            res.message.isEmpty ? 'No se pudieron cargar las fotos' : res.message;
      }
    } catch (_) {
      errorMsg = 'Error de conexión al cargar las fotos';
    }
    loading = false;
    _notify();
  }

  String get _usuario => _session.displayName(fallback: 'Instalador');

  // Fotos que se están eliminando (para mostrar spinner).
  final Set<String> deletingDocs = {};

  String _sanit(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');

  bool get _esAdmin {
    final r = _session.rol.trim().toLowerCase();
    return r == 'adminclm' || r == 'admin' || r == 'administrador';
  }

  /// Usuario que subió la foto, extraído del nombre del fichero:
  /// {referencia}-{clave}-{YYYYMMDDHHMMSS}-{usuario}.ext
  String _uploaderDe(String doc) {
    final name = doc.split('/').last;
    final m = RegExp(r'-(\d{14})-(.+)\.[^.]+$').firstMatch(name);
    return m != null ? m.group(2)! : '';
  }

  /// El instalador solo puede eliminar sus propias fotos; el admin, todas.
  bool puedeEliminar(String doc) {
    if (_esAdmin) return true;
    final uploader = _uploaderDe(doc);
    return uploader.isNotEmpty &&
        _sanit(uploader).toLowerCase() == _sanit(_usuario).toLowerCase();
  }

  /// Elimina una foto (solo si el usuario tiene permiso).
  Future<(bool, String)> eliminarFoto(String doc) async {
    deletingDocs.add(doc);
    _notify();
    try {
      final json = await _api.postForm(AppConfig.eliminarFoto, {
        'doc': doc,
        'usuario': _usuario,
        'rol': _session.rol,
      });
      final ok = json['success'] == true;
      final msg = UiText.sanitizeDbValue(json['message']?.toString());
      if (ok) fotos = List<String>.from(fotos)..remove(doc);
      deletingDocs.remove(doc);
      _notify();
      return (ok, ok ? 'Foto eliminada' : (msg.isEmpty ? 'No se pudo eliminar' : msg));
    } catch (_) {
      deletingDocs.remove(doc);
      _notify();
      return (false, 'Error de conexión al eliminar la foto');
    }
  }

  Future<(bool, String)> uploadBytes(List<int> bytes, String filename) =>
      _doUpload(() => _api.uploadBytes(
            AppConfig.uploadFoto,
            fields: _fields(),
            bytes: bytes,
            filename: filename,
            onProgress: _onProgress,
          ));

  Future<(bool, String)> uploadPath(String path, String filename) =>
      _doUpload(() => _api.uploadFile(
            AppConfig.uploadFoto,
            fields: _fields(),
            filePath: path,
            filename: filename,
            onProgress: _onProgress,
          ));

  Map<String, String> _fields() => {
        'referencia': referencia,
        'clave': clave,
        'usuario': _usuario,
      };

  void _onProgress(int sent, int total) {
    if (total > 0) {
      uploadProgress = sent / total;
      _notify();
    }
  }

  Future<(bool, String)> _doUpload(
      Future<Map<String, dynamic>> Function() request) async {
    uploading = true;
    uploadProgress = 0;
    _notify();
    try {
      final json = await request();
      final ok = json['success'] == true;
      final msg = UiText.sanitizeDbValue(json['message']?.toString());
      uploading = false;
      _notify();
      if (ok) await load();
      return (ok, ok ? 'Archivo subido' : (msg.isEmpty ? 'No se pudo subir' : msg));
    } catch (_) {
      uploading = false;
      _notify();
      return (false, 'Error al subir el archivo');
    }
  }
}
