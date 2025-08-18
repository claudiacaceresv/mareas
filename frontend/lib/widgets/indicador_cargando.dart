// ================================================================
// Indicador de carga — resumen
// Qué hace:
// - Muestra fondo según MomentoDelDia y una barra de progreso animada.
// - Rota frases cortas con un Timer para feedback durante la espera.
// - Usa paleta desde TemaVisual para colores y tipografías.
// Uso: widget de pantalla completa mientras inicia o carga datos.
// Seguridad: sin datos sensibles.
// ================================================================

// frontend/mareas/lib/widgets/indicador_cargando.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_mareas/theme/tema_visual.dart';
import 'package:app_mareas/utils/momento_actual.dart';
import 'package:app_mareas/utils/fondos_por_momento.dart';

class IndicadorCargando extends StatefulWidget {
  const IndicadorCargando({super.key});

  @override
  State<IndicadorCargando> createState() => _IndicadorCargandoState();
}

class _IndicadorCargandoState extends State<IndicadorCargando>
    with SingleTickerProviderStateMixin {
  // ==========================
  // Estado y animaciones
  // ==========================
  late AnimationController _barraController;
  late Animation<double> _barraAnimation;
  late Timer _fraseTimer;
  int _fraseIndex = 0;

  // ==========================
  // Copys de carga
  // ==========================
  final List<String> frases = [
    '📦 Descargando datos...',
    '🌊 Preparando las mareas...',
    '🧭 Ubicando las boyas...',
    '🛠️ Armando tu radar de mareas...',
    '⏳ Esto suele tardar solo la primera vez...',
    '🪝 Enganchando la red de datos...',
    '📡 Afinando el sonar...',
    '🌬️ Midiendo el viento...',
    '🔭 Alineando la brújula...',
    '🐚 Buscando caracoles...',
    '🚢 Esperando al capitán...',
  ];

  // ==========================
  // Ciclo de vida
  // ==========================
  @override
  void initState() {
    super.initState();

    _barraController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _barraAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _barraController, curve: Curves.easeInOut),
    );

    _fraseTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      setState(() => _fraseIndex = (_fraseIndex + 1) % frases.length);
    });
  }

  @override
  void dispose() {
    _barraController.dispose();
    _fraseTimer.cancel();
    super.dispose();
  }

  // ==========================
  // Render
  // ==========================
  @override
  Widget build(BuildContext context) {
    final momento = obtenerMomentoDelDia();
    final tema = obtenerTemaVisual(context);
    final fondo = obtenerFondoPorMomento(momento);

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(image: AssetImage(fondo), fit: BoxFit.cover),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Título
            Text(
              'CARGANDO',
              style: TextStyle(
                fontFamily: 'PressStart',
                fontSize: 12,
                color: tema.textoEtiqueta,
              ),
            ),
            const SizedBox(height: 24),

            // Barra de progreso
            Container(
              width: 160,
              height: 12,
              decoration: BoxDecoration(
                color: tema.relleno,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: tema.textoEtiqueta, width: 1),
              ),
              child: AnimatedBuilder(
                animation: _barraAnimation,
                builder: (context, _) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _barraAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: tema.textoEtiqueta,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Frase rotativa
            Text(
              frases[_fraseIndex],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PressStart',
                fontSize: 8,
                color: tema.texto.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
