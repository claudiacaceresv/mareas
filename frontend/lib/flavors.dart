// ================================================================
// Flavors — resumen
// Qué hace: define variantes FREE y PRO para alternar features y branding.
// Cómo funciona: enum Flavor; F.appFlavor se setea en main() con
// --dart-define=FLAVOR. F.name y F.title exponen identificadores para la UI.
// Uso: establecer F.appFlavor en main() antes de runApp.
// ================================================================

// frontend/mareas/lib/flavors.dart

/// Variantes de compilación.
enum Flavor {
  free,
  pro,
}

/// Accesos estáticos al flavor activo.
class F {
  /// Se inicializa en main() leyendo String.fromEnvironment('FLAVOR').
  static late final Flavor appFlavor;

  /// Devolver nombre técnico del flavor (“free” | “pro”).
  static String get name => appFlavor.name;

  /// Devolver título de marca para UI.
  static String get title {
    switch (appFlavor) {
      case Flavor.free:
        return 'Mareas';
      case Flavor.pro:
        return 'Mareas Pro';
    }
  }
}
