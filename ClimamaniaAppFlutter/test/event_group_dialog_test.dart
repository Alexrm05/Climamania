import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:climamania_app/data/models/evento.dart';
import 'package:climamania_app/features/calendar/widgets/event_group_dialog.dart';

Evento _ev(String ref, String cliente) => Evento.fromJson({
      'start': '2026-06-03 08:00:00',
      'end': '2026-06-03 09:00:00',
      'referencia': ref,
      'nombrecliente': cliente,
      'equipo_instaladores': 'CLM1',
      'direccion': 'C/ Test 1',
      'estado': 'Pendiente',
    });

void main() {
  // Regresión: en el calendario, cuando dos instalaciones coinciden en la
  // misma franja se abre el diálogo de grupo. Al pulsar "Detalle" la app se
  // quedaba completamente en negro porque el diálogo se cerraba con el
  // Navigator de la rama del shell (lo vaciaba) en lugar del Navigator raíz.
  testWidgets(
      'pulsar "Detalle" cierra el diálogo y NO vacía la rama del shell',
      (tester) async {
    Evento? seleccionado;
    // Marca el contenido de la rama del shell (un Navigator anidado), igual
    // que la pantalla de calendario vive dentro de StatefulShellRoute.
    const branchMarker = Key('branch-content');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (branchCtx) => Center(
              key: branchMarker,
              child: ElevatedButton(
                onPressed: () => showEventGroupDialog(
                  branchCtx,
                  group: [_ev('PED-1003', 'Luis'), _ev('PED-1004', 'Marta')],
                  hora: '08:00',
                  onDetail: (ev) => seleccionado = ev,
                ),
                child: const Text('abrir-grupo'),
              ),
            ),
          ),
        ),
      ),
    ));

    // Abrir el diálogo de grupo (la "ventana para seleccionar cuál").
    await tester.tap(find.text('abrir-grupo'));
    await tester.pumpAndSettle();
    expect(find.text('08:00 · 2 eventos'), findsOneWidget);
    expect(find.text('Detalle'), findsNWidgets(2));

    // Pulsar "Detalle" del primer evento.
    await tester.tap(find.text('Detalle').first);
    await tester.pumpAndSettle();

    // El diálogo se cerró...
    expect(find.text('08:00 · 2 eventos'), findsNothing);
    // ...se navegó con el evento correcto...
    expect(seleccionado?.referencia, 'PED-1003');
    // ...y la rama del shell SIGUE viva (no hay pantalla en negro).
    expect(find.byKey(branchMarker), findsOneWidget);
  });
}
