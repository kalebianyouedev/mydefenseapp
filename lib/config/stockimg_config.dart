/// Configuration for the StockImg file storage API
/// (https://storage.mrsergio.dev/docs).
///
/// Firebase (Auth, Firestore) keeps managing accounts and app data;
/// StockImg only stores files (images/PDF) and hands back a public URL
/// that gets saved as a normal string field in Firestore.
class StockImgConfig {
  /// Get your key from https://storage.mrsergio.dev/register, then the
  /// dashboard's "Générer ma clé API". Either edit the fallback below, or
  /// override at build/run time with:
  ///   flutter run --dart-define=STOCKIMG_API_KEY=your_key
  static const String apiKey = String.fromEnvironment(
    'STOCKIMG_API_KEY',
    defaultValue: '7|cWy9zIBKv0uAHUXQ6XNVPLRyUVLplyZIc1GuiBrk51562198',
  );

  static const String baseUrl = String.fromEnvironment(
    'STOCKIMG_BASE_URL',
    defaultValue: 'https://storage.mrsergio.dev',
  );
}
