// ================================================================
// Pantalla de carga inicial tipo “splash”.
// Qué hace:
// - Muestra `IndicadorCargando` sobre fondo negro.
// - Espera ~3 s y navega con `pushReplacement` a `PantallaMarea`.
// Uso:
// - Definirla como pantalla de arranque antes de la principal.
// ================================================================


import 'package:flutter/material.dart';
import '../widgets/indicador_cargando.dart';
import '../pantallas/principal.dart';

/// Vista de cargando mostrada al iniciar la app.
/// Presenta un indicador y navega a la pantalla principal.
class PantallaInstalando extends StatefulWidget {
  const PantallaInstalando({super.key});

  @override
  State<PantallaInstalando> createState() => _PantallaInstalandoState();
}

class _PantallaInstalandoState extends State<PantallaInstalando> {
  @override
  void initState() {
    super.initState();

    // Programar navegación a la pantalla principal tras 3 segundos.
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PantallaMarea()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar indicador centrado sobre fondo negro.
    return const Scaffold(
      backgroundColor: Colors.black,
      body: IndicadorCargando(),
    );
  }
}
