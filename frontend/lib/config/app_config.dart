// ================================================================
// lib/config/app_config.dart — propósito
// Centraliza la variante de producto (FREE vs PRO).
// Qué hace:
// - Expone el flag `esVersionPremium` a partir de `F.appFlavor`.
// - Permite habilitar funciones premium y desactivar anuncios desde un único punto.
// Uso:
// - Definir flavor con --dart-define=FLAVOR=free|pro y consultar `esVersionPremium` en la UI.
// ================================================================


import '../flavors.dart';

/// Indicar si la app corre en edición premium.
/// Usar este flag para habilitar o limitar funcionalidades en la UI.
final bool esVersionPremium = F.appFlavor == Flavor.pro;
