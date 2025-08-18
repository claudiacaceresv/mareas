// ================================================================
// Catálogo visible de estaciones en la app.
// Qué hace:
// - Expone `estacionesHabilitadas` como lista de IDs permitidos.
// - Mantiene sincronía con el backend (marea/scripts/data/estaciones.json).
// Uso:
// - Editar la lista para mostrar/ocultar estaciones en la UI.
// - Los widgets consultan esta lista para habilitar selección.
// ================================================================

const List<String> estacionesHabilitadas = [
  'san_fernando',
  'rosario',
  'zarate',
  // Agregar o quitar estaciones según disponibilidad.
];
