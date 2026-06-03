import '../../core/ui_text.dart';

/// Contacto de facturación o entrega.
class Contacto {
  final String nombre;
  final String direccion;
  final String poblacion;
  final String telefono;
  final String email;

  const Contacto({
    required this.nombre,
    required this.direccion,
    required this.poblacion,
    required this.telefono,
    required this.email,
  });

  factory Contacto.fromJson(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());
    return Contacto(
      nombre: s('nombre'),
      direccion: s('direccion'),
      poblacion: s('poblacion'),
      telefono: s('telefono'),
      email: s('email'),
    );
  }
}

/// Equipo asignado: descripción + inicio.
class EquipoAsignado {
  final String descripcion;
  final String start;
  const EquipoAsignado({required this.descripcion, required this.start});

  factory EquipoAsignado.fromJson(Map<String, dynamic> j) => EquipoAsignado(
        descripcion: UiText.sanitizeDbValue(j['descripcion']?.toString()),
        start: UiText.sanitizeDbValue(j['start']?.toString()),
      );
}

class Finalizacion {
  final String usuario;
  final String fecha;
  const Finalizacion({required this.usuario, required this.fecha});

  factory Finalizacion.fromJson(Map<String, dynamic> j) => Finalizacion(
        usuario: UiText.sanitizeDbValue(j['Usuario']?.toString()),
        fecha: UiText.sanitizeDbValue(j['Fecha']?.toString()),
      );
}

/// Línea del detalle del pedido.
class DetalleLinea {
  final String cantidad;
  final String referencia;
  final String nombre;
  const DetalleLinea({
    required this.cantidad,
    required this.referencia,
    required this.nombre,
  });

  factory DetalleLinea.fromJson(Map<String, dynamic> j) => DetalleLinea(
        cantidad: UiText.sanitizeDbValue(j['product_quantity']?.toString()),
        referencia: UiText.sanitizeDbValue(j['product_reference']?.toString()),
        nombre: UiText.sanitizeDbValue(j['product_name']?.toString()),
      );
}

/// Comentario del instalador.
class ComentarioInstalador {
  final String fecha;
  final String usuario;
  final String texto;
  const ComentarioInstalador({
    required this.fecha,
    required this.usuario,
    required this.texto,
  });

  factory ComentarioInstalador.fromJson(Map<String, dynamic> j) =>
      ComentarioInstalador(
        fecha: UiText.sanitizeDbValue(j['Fecha']?.toString()),
        usuario: UiText.sanitizeDbValue(j['Usuario']?.toString()),
        texto: UiText.sanitizeDbValue(j['Texto']?.toString()),
      );
}

/// Listas de rutas de fotos por categoría.
class Fotografias {
  final List<String> cliente;
  final List<String> previas;
  final List<String> incidencias;
  final List<String> acabada;
  final List<String> conforme;
  final List<String> boe;
  final List<String> documentos;

  const Fotografias({
    required this.cliente,
    required this.previas,
    required this.incidencias,
    required this.acabada,
    required this.conforme,
    required this.boe,
    required this.documentos,
  });

  factory Fotografias.fromJson(Map<String, dynamic> j) {
    List<String> l(String k) {
      final raw = j[k];
      if (raw is List) {
        return raw
            .map((e) => UiText.sanitizeDbValue(e?.toString()))
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    return Fotografias(
      cliente: l('cliente'),
      previas: l('previas'),
      incidencias: l('incidencias'),
      acabada: l('acabada'),
      conforme: l('conforme'),
      boe: l('boe'),
      documentos: l('documentos'),
    );
  }

  List<String> byCategoria(String cat) {
    switch (cat) {
      case 'cliente':
        return cliente;
      case 'previas':
        return previas;
      case 'incidencias':
        return incidencias;
      case 'acabada':
        return acabada;
      case 'conforme':
        return conforme;
      case 'boe':
        return boe;
      case 'documentos':
        return documentos;
      default:
        return const [];
    }
  }
}

/// Datos de conformidad del cliente (para la firma).
class ConformidadCliente {
  final String nombre;
  final String apellidos;
  final String dni;
  final String direccion;
  final String cp;
  final String poblacion;
  final String provincia;
  final String direccionInstalacion;

  const ConformidadCliente({
    required this.nombre,
    required this.apellidos,
    required this.dni,
    required this.direccion,
    required this.cp,
    required this.poblacion,
    required this.provincia,
    required this.direccionInstalacion,
  });

  factory ConformidadCliente.fromJson(Map<String, dynamic> j) {
    final cli = j['cliente'];
    final inst = j['instalacion'];
    final c = cli is Map ? Map<String, dynamic>.from(cli) : <String, dynamic>{};
    final i =
        inst is Map ? Map<String, dynamic>.from(inst) : <String, dynamic>{};
    String s(Map<String, dynamic> m, String k) =>
        UiText.sanitizeDbValue(m[k]?.toString());
    return ConformidadCliente(
      nombre: s(c, 'nombre'),
      apellidos: s(c, 'apellidos'),
      dni: s(c, 'dni'),
      direccion: s(c, 'direccion'),
      cp: s(c, 'cp'),
      poblacion: s(c, 'poblacion'),
      provincia: s(c, 'provincia'),
      direccionInstalacion: s(i, 'direccion'),
    );
  }
}

/// Ficha completa del pedido (respuesta de get_pedido.php).
class Pedido {
  final String referencia;
  final String cliente;
  final String emailCliente;
  final List<EquipoAsignado> equipoAsignado;
  final List<Finalizacion> finalizaciones;
  final String detalles; // articulos_agenda.detalles
  final String comentariosAgenda; // articulos_agenda.comentarios
  final String direccionInstalacion;
  final Contacto? facturacion;
  final Contacto? entrega;
  final List<DetalleLinea> detallePedido;
  final String observaciones;
  final List<ComentarioInstalador> comentarios;
  final Fotografias fotografias;
  final ConformidadCliente? conformidad;

  const Pedido({
    required this.referencia,
    required this.cliente,
    required this.emailCliente,
    required this.equipoAsignado,
    required this.finalizaciones,
    required this.detalles,
    required this.comentariosAgenda,
    required this.direccionInstalacion,
    required this.facturacion,
    required this.entrega,
    required this.detallePedido,
    required this.observaciones,
    required this.comentarios,
    required this.fotografias,
    this.conformidad,
  });

  factory Pedido.fromJson(Map<String, dynamic> j) {
    String s(String k) => UiText.sanitizeDbValue(j[k]?.toString());

    List<T> list<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = j[key];
      final out = <T>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) out.add(fromJson(Map<String, dynamic>.from(e)));
        }
      }
      return out;
    }

    Contacto? contacto(String key) {
      final raw = j[key];
      if (raw is Map) return Contacto.fromJson(Map<String, dynamic>.from(raw));
      return null;
    }

    final agenda = j['articulos_agenda'];
    final agendaMap =
        agenda is Map ? Map<String, dynamic>.from(agenda) : <String, dynamic>{};

    final fotosRaw = j['fotografias'];
    final fotos = fotosRaw is Map
        ? Fotografias.fromJson(Map<String, dynamic>.from(fotosRaw))
        : const Fotografias(
            cliente: [], previas: [], incidencias: [], acabada: [],
            conforme: [], boe: [], documentos: []);

    return Pedido(
      referencia: s('referencia'),
      cliente: s('cliente'),
      emailCliente: s('email_cliente'),
      equipoAsignado: list('equipo_asignado', EquipoAsignado.fromJson),
      finalizaciones: list('finalizaciones', Finalizacion.fromJson),
      detalles: UiText.sanitizeDbValue(agendaMap['detalles']?.toString()),
      comentariosAgenda:
          UiText.sanitizeDbValue(agendaMap['comentarios']?.toString()),
      direccionInstalacion: s('direccion_instalacion'),
      facturacion: contacto('facturacion'),
      entrega: contacto('entrega'),
      detallePedido: list('detalle_pedido', DetalleLinea.fromJson),
      observaciones: s('observaciones_pedido'),
      comentarios: list('comentarios_instalador', ComentarioInstalador.fromJson),
      fotografias: fotos,
      conformidad: j['conformidad'] is Map
          ? ConformidadCliente.fromJson(
              Map<String, dynamic>.from(j['conformidad'] as Map))
          : null,
    );
  }
}
