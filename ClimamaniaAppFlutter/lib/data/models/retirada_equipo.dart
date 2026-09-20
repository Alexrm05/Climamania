/// Componente que el cliente puede quedarse cuando no se retira el equipo
/// completo. `clave` es lo que se persistirá; `etiqueta`, lo que se muestra.
class ComponenteConservado {
  final String clave;
  final String etiqueta;
  const ComponenteConservado(this.clave, this.etiqueta);

  static const otros = ComponenteConservado('otros', 'Otros');

  static const todos = [
    ComponenteConservado('equipo_completo', 'Equipo completo'),
    ComponenteConservado('unidad_interior', 'Unidad interior'),
    ComponenteConservado('unidad_exterior', 'Unidad exterior'),
    ComponenteConservado('compresor', 'Compresor'),
    ComponenteConservado('placas', 'Placa/s electrónica/s'),
    ComponenteConservado('motores', 'Motor/es'),
    otros,
  ];
}

/// Estado del apartado "Equipo desinstalado / Retirada" de una instalación.
///
/// Solo aplica a pedidos con líneas DESINTDO / DESINSTDO. Es mutable a
/// propósito: la pantalla lo va rellenando con setState, igual que el resto
/// de formularios de instalación.
class RetiradaEquipo {
  /// Respuesta a "¿ClimaMania retira el equipo completo?". `null` mientras el
  /// instalador no haya elegido.
  bool? retiraCompleto;

  // Rama SÍ.
  bool unidadInteriorRetirada = false;
  bool unidadExteriorRetirada = false;

  // Rama NO: claves de ComponenteConservado marcadas, y detalle si hay "otros".
  final Set<String> conserva = {};
  String otrosDetalle = '';

  bool get conservaOtros => conserva.contains(ComponenteConservado.otros.clave);

  /// Mensaje que impide firmar la declaración: la selección de componentes
  /// debe estar completa antes de generar el documento.
  String? get errorParaDeclaracion {
    if (retiraCompleto != false) {
      return 'La declaración solo aplica si el cliente conserva el equipo.';
    }
    if (conserva.isEmpty) {
      return 'Indica qué conserva el cliente.';
    }
    if (conservaOtros && otrosDetalle.trim().isEmpty) {
      return 'Especifica qué otros componentes conserva el cliente.';
    }
    return null;
  }

  /// Mensaje que impide finalizar la instalación, o `null` si el apartado
  /// está completo. Las fotos y la declaración las conoce la pantalla
  /// (vienen del servidor), por eso se pasan como flags.
  String? errorParaFinalizar({
    required bool tieneFotoRetirado,
    required bool tieneFotoConservado,
    bool tieneDeclaracionFirmada = false,
  }) {
    switch (retiraCompleto) {
      case null:
        return 'Indica si ClimaMania retira el equipo completo.';
      case true:
        if (!(unidadInteriorRetirada && unidadExteriorRetirada)) {
          return 'Marca la retirada de la unidad interior y de la exterior.';
        }
        if (!tieneFotoRetirado) {
          return 'Falta la foto obligatoria del equipo retirado.';
        }
        return null;
      case false:
        final errorSeleccion = errorParaDeclaracion;
        if (errorSeleccion != null) {
          return errorSeleccion;
        }
        if (!tieneFotoConservado) {
          return 'Falta la foto obligatoria de los componentes que conserva el cliente.';
        }
        if (!tieneDeclaracionFirmada) {
          return 'Falta la firma del cliente en la declaración sobre el equipo desinstalado.';
        }
        return null;
    }
  }
}
