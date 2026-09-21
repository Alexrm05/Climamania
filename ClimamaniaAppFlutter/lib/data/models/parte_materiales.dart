import '../../core/ui_text.dart';

double _num(dynamic v) =>
    double.tryParse((v ?? '').toString().replaceAll(',', '.')) ?? 0;

/// Línea del parte de trabajo: un material con su previsión y su consumo
/// real. Mutable a propósito: la pantalla la edita en sitio.
class MaterialLinea {
  final String articulo;

  /// Tipo de instalación del que sale el material (INSTAL40, ...) o '*' si
  /// es común a todos los pedidos. Vacío si lo añadió el técnico a mano.
  final String articuloPadre;
  String descripcion;
  final String unidad; // m, ud, m/ud, -
  double cantidadPrevista;
  double cantidad; // real consumida
  final double precioUnitarioSinIva;

  /// Viene de los materiales por defecto (no del buscador).
  final bool porDefecto;

  MaterialLinea({
    required this.articulo,
    this.articuloPadre = '',
    required this.descripcion,
    this.unidad = 'ud',
    this.cantidadPrevista = 0,
    required this.cantidad,
    this.precioUnitarioSinIva = 0,
    this.porDefecto = false,
  });

  double get desviacion => cantidad - cantidadPrevista;

  /// Tiene algo que guardar: consumo real o previsión.
  bool get relevante => cantidad > 0 || cantidadPrevista > 0;

  factory MaterialLinea.fromJson(Map<String, dynamic> j,
      {bool porDefecto = false}) {
    final unidad = UiText.sanitizeDbValue(j['unidad']?.toString());
    return MaterialLinea(
      articulo: UiText.sanitizeDbValue(j['articulo']?.toString()),
      articuloPadre: UiText.sanitizeDbValue(j['articulo_padre']?.toString()),
      descripcion: UiText.sanitizeDbValue(j['descripcion']?.toString()),
      unidad: unidad.isEmpty ? 'ud' : unidad,
      cantidadPrevista: _num(j['cantidad_prevista']),
      cantidad: _num(j['cantidad']),
      precioUnitarioSinIva: _num(j['precio_unitario_sin_iva']),
      porDefecto: porDefecto,
    );
  }

  Map<String, dynamic> toJson() => {
        'articulo': articulo,
        'articulo_padre': articuloPadre,
        'descripcion': descripcion.trim(),
        'unidad': unidad,
        'cantidad_prevista': cantidadPrevista.toStringAsFixed(2),
        'cantidad': cantidad.toStringAsFixed(2),
        'precio_unitario_sin_iva': precioUnitarioSinIva.toStringAsFixed(6),
      };
}

/// Parte de un pedido tal como lo devuelve get_parte_materiales.php.
class ParteMateriales {
  final String pedido;
  final bool existe;
  final String horaInicio; // HH:MM o ''
  final String horaFinal; // HH:MM o ''
  final String usuario;
  final String equipo;
  final String fechaCreacion;
  final String fechaEdicion;
  final List<MaterialLinea> lineas;

  /// Materiales por defecto (ClimaInstal_ParteMateriales_Relacionados).
  final List<MaterialLinea> defecto;

  const ParteMateriales({
    required this.pedido,
    required this.existe,
    required this.horaInicio,
    required this.horaFinal,
    required this.usuario,
    required this.equipo,
    required this.fechaCreacion,
    required this.fechaEdicion,
    required this.lineas,
    required this.defecto,
  });

  factory ParteMateriales.fromJson(Map<String, dynamic> j) {
    List<MaterialLinea> list(String k, {bool porDefecto = false}) {
      final raw = j[k];
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map)
            MaterialLinea.fromJson(Map<String, dynamic>.from(e),
                porDefecto: porDefecto),
      ];
    }

    Map<String, dynamic> map(String k) => j[k] is Map
        ? Map<String, dynamic>.from(j[k] as Map)
        : const <String, dynamic>{};
    final horas = map('horas');
    final meta = map('meta');
    String s(Map<String, dynamic> m, String k) =>
        UiText.sanitizeDbValue(m[k]?.toString());
    return ParteMateriales(
      pedido: UiText.sanitizeDbValue(j['pedido']?.toString()),
      existe: j['existe'] == true,
      horaInicio: s(horas, 'hora_inicio'),
      horaFinal: s(horas, 'hora_final'),
      usuario: s(meta, 'usuario'),
      equipo: s(meta, 'equipo'),
      fechaCreacion: s(meta, 'fecha_creacion'),
      fechaEdicion: s(meta, 'fecha_edicion'),
      lineas: list('lineas'),
      defecto: list('defecto', porDefecto: true),
    );
  }
}

/// Resumen que viaja en get_pedido.php para saber si el parte está hecho.
class ParteMaterialesResumen {
  final int numLineas;
  final String horaInicio;
  final String horaFinal;
  final String fechaEdicion;
  final String usuario;

  const ParteMaterialesResumen({
    required this.numLineas,
    required this.horaInicio,
    required this.horaFinal,
    required this.fechaEdicion,
    required this.usuario,
  });

  factory ParteMaterialesResumen.fromJson(Map<String, dynamic> j) =>
      ParteMaterialesResumen(
        numLineas: int.tryParse('${j['num_lineas']}') ?? 0,
        horaInicio: UiText.sanitizeDbValue(j['hora_inicio']?.toString()),
        horaFinal: UiText.sanitizeDbValue(j['hora_final']?.toString()),
        fechaEdicion: UiText.sanitizeDbValue(j['fecha_edicion']?.toString()),
        usuario: UiText.sanitizeDbValue(j['usuario']?.toString()),
      );

  bool get hecho => numLineas > 0;
}

/// Entrada del histórico (un parte por pedido) de get_partes_materiales.php.
class ParteResumen {
  final String pedido;
  final String cliente;
  final String fechaCreacion;
  final String horaInicio;
  final String horaFinal;
  final String usuario;
  final String equipo;
  final int numLineas;
  final double totalSinIva;

  const ParteResumen({
    required this.pedido,
    required this.cliente,
    required this.fechaCreacion,
    required this.horaInicio,
    required this.horaFinal,
    required this.usuario,
    required this.equipo,
    required this.numLineas,
    required this.totalSinIva,
  });

  factory ParteResumen.fromJson(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());
    return ParteResumen(
      pedido: s('pedido'),
      cliente: s('cliente'),
      fechaCreacion: s('fecha_creacion'),
      horaInicio: s('hora_inicio'),
      horaFinal: s('hora_final'),
      usuario: s('usuario'),
      equipo: s('equipo'),
      numLineas: int.tryParse('${j['num_lineas']}') ?? 0,
      totalSinIva: _num(j['total_sin_iva']),
    );
  }
}

/// Total por artículo entre dos fechas.
class MaterialTotal {
  final String articulo;
  final String descripcion;
  final String unidad;
  final double cantidadPrevista;
  final double cantidad;
  final int numPartes;
  final double importeSinIva;

  const MaterialTotal({
    required this.articulo,
    required this.descripcion,
    required this.unidad,
    required this.cantidadPrevista,
    required this.cantidad,
    required this.numPartes,
    required this.importeSinIva,
  });

  double get desviacion => cantidad - cantidadPrevista;

  factory MaterialTotal.fromJson(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());
    return MaterialTotal(
      articulo: s('articulo'),
      descripcion: s('descripcion'),
      unidad: s('unidad').isEmpty ? 'ud' : s('unidad'),
      cantidadPrevista: _num(j['cantidad_prevista']),
      cantidad: _num(j['cantidad']),
      numPartes: int.tryParse('${j['num_partes']}') ?? 0,
      importeSinIva: _num(j['importe_sin_iva']),
    );
  }
}

/// Histórico + totales de un rango de fechas.
class PartesMateriales {
  final String desde;
  final String hasta;
  final bool soloUsuario;
  final List<ParteResumen> partes;
  final List<MaterialTotal> totales;

  const PartesMateriales({
    required this.desde,
    required this.hasta,
    required this.soloUsuario,
    required this.partes,
    required this.totales,
  });

  factory PartesMateriales.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) {
      final raw = j[k];
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map) f(Map<String, dynamic>.from(e)),
      ];
    }

    return PartesMateriales(
      desde: UiText.sanitizeDbValue(j['desde']?.toString()),
      hasta: UiText.sanitizeDbValue(j['hasta']?.toString()),
      soloUsuario: j['solo_usuario'] == true,
      partes: list('partes', ParteResumen.fromJson),
      totales: list('totales', MaterialTotal.fromJson),
    );
  }
}

/// Minutos entre dos horas "HH:MM"; null si alguna no es válida o el orden
/// no tiene sentido. Compartido por pantalla y resumen.
int? minutosEntre(String horaInicio, String horaFinal) {
  int? parse(String v) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final i = int.parse(m.group(2)!);
    if (h > 23 || i > 59) return null;
    return h * 60 + i;
  }

  final a = parse(horaInicio);
  final b = parse(horaFinal);
  if (a == null || b == null || b <= a) return null;
  return b - a;
}

String formatoHoras(int minutos) {
  final h = minutos ~/ 60;
  final m = minutos % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Cantidad sin decimales innecesarios: 4 → "4", 2.5 → "2,5".
String formatoCantidad(double v) =>
    (v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1))
        .replaceAll('.', ',');

/// Desviación con signo: +2, -1,5, 0.
String formatoDesviacion(double v) {
  if (v == 0) return '0';
  return '${v > 0 ? '+' : '-'}${formatoCantidad(v.abs())}';
}
