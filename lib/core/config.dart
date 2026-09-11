/// Build-time configuration for the optional sync backend.
///
/// Supplied at build time so no URL is baked into the repository. Copy
/// `config/neon.example.json` to `config/neon.json` (gitignored), then:
///
/// ```
/// flutter run --dart-define-from-file=config/neon.json
/// ```
///
/// These are not secrets — the Data API URL is a public endpoint and RLS is what
/// protects the rows behind it. They are configuration, kept out of the source
/// tree so a fork does not inherit someone else's project.
abstract final class TraceConfig {
  static const authBaseUrl =
      String.fromEnvironment('NEON_AUTH_BASE_URL');

  static const dataApiUrl =
      String.fromEnvironment('NEON_DATA_API_URL');

  /// Sent as `Origin` on auth POSTs; must be one of the project's trusted
  /// domains. The default works only while "Allow Localhost" is on, which is
  /// fine for development and what Neon's production checklist turns off.
  static const authOrigin = String.fromEnvironment(
    'NEON_AUTH_ORIGIN',
    defaultValue: 'http://localhost:3000',
  );

  /// False in a plain `flutter run`, which is the normal local-first case.
  /// Every sync surface stays hidden rather than offering a button that cannot
  /// work.
  static bool get syncConfigured =>
      authBaseUrl.isNotEmpty && dataApiUrl.isNotEmpty;
}
