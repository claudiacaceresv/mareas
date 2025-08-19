// ================================================================
// Centraliza la configuración de AdMob.
// Qué hace:
// - Define un switch (modoPruebaAds) para alternar IDs de prueba vs. reales.
// - Expone getters únicos para Rewarded, Interstitial y Banner.
// - Evita hardcodear IDs en widgets y simplifica cambios por entorno.
// Seguridad:
// - En repos públicos los IDs reales quedan como <REEMPLAZAR: …>.
// ================================================================

// lib/config/anuncios_config.dart

// ----- Modo de anuncios -----
// Usar true durante desarrollo para cumplir políticas de AdMob.
// Usar false en builds de producción.
bool modoPruebaAds = true;

// ----- Unidades: bonificado -----
// Retornar el ID correspondiente según el modo actual.
String get anuncioBonificadoId => modoPruebaAds
    ? 'ca-app-pub-3940256099942544/5224354917' // Test oficial de Google
    : '<REEMPLAZAR: ADMOB_REWARDED_ID>';       // ID real de anuncio bonificado

// ----- Unidades: intersticial -----
// Mantener los mismos IDs que figuran en la consola de AdMob.
String get anuncioIntersticialId => modoPruebaAds
    ? 'ca-app-pub-3940256099942544/1033173712' // Test oficial de Google
    : '<REEMPLAZAR: ADMOB_INTERSTITIAL_ID>';   // ID real intersticial

// ----- Unidades: banner -----
// Centralizar aquí para evitar hardcodear en widgets.
String get bannerAdUnitId => modoPruebaAds
    ? 'ca-app-pub-3940256099942544/6300978111' // Test oficial de Google
    : '<REEMPLAZAR: ADMOB_BANNER_ID>';         // ID real de banner
