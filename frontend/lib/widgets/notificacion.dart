// ================================================================
// Notificación en banner — resumen
// Qué hace: muestra un aviso breve con título, cuerpo y botón de cierre.
// Cómo funciona: toma colores desde TemaProvider/TemaVisual y escala tipografías
//                según el ancho de pantalla. Expone onCerrar para descartar.
// Uso: NotificacionBanner(titulo: '...', cuerpo: '...', onCerrar: () { ... }).
// ================================================================

// frontend/mareas/lib/widgets/notificacion.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_mareas/theme/tema_visual.dart';
import '../providers/tema_provider.dart';

class NotificacionBanner extends StatelessWidget {
  // ---------------- Props públicas ----------------
  final String titulo;        // texto del encabezado del aviso
  final String cuerpo;        // detalle del mensaje
  final VoidCallback onCerrar; // acción para descartar el banner

  const NotificacionBanner({
    super.key,
    required this.titulo,
    required this.cuerpo,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    // Obtener paleta desde el tema actual
    final tema = Provider.of<TemaProvider>(context).tema;

    // ---------------- Contenedor del banner ----------------
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.borde.withOpacity(0.15), // sugerir fondo sutil
        border: Border.all(color: tema.borde), // delinear borde
        borderRadius: BorderRadius.circular(12), // suavizar esquinas
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono informativo
          const Icon(Icons.info_outline, size: 20),
          const SizedBox(width: 10),

          // ---------------- Columna de texto ----------------
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título del aviso
                Text(
                  titulo,
                  style: TextStyle(
                    fontFamily: 'PressStart',
                    // Escalar tamaño de fuente según ancho disponible
                    fontSize: MediaQuery.of(context).size.width * 0.028,
                    color: tema.texto,
                  ),
                ),
                const SizedBox(height: 4),

                // Cuerpo del aviso
                Text(
                  cuerpo,
                  style: TextStyle(
                    // Mantener misma escala para consistencia visual
                    fontSize: MediaQuery.of(context).size.width * 0.028,
                    color: tema.texto.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // ---------------- Botón de cierre ----------------
          IconButton(
            icon: const Icon(Icons.close),
            color: tema.texto.withOpacity(0.7),
            onPressed: onCerrar, // delegar manejo al caller
            tooltip: 'Cerrar notificación',
          ),
        ],
      ),
    );
  }
}
