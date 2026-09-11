/// Build-time configuration for the optional sync backend.
///
/// Supplied with --dart-define so no URL is baked into the repository:
///
/// ```
/// flutter run \
///   --dart-define=NEON_AUTH_BASE_URL=https://ENDPOINT.neonauth.REGION.aws.neon.tech/neondb/auth \
///   --dart-define=NEON_DATA_API_URL=https://ENDPOINT.apirest.REGION.aws.neon.tech/neondb/rest/v1
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

  /// False in a plain `flutter run`, which is the normal local-first case.
  /// Every sync surface stays hidden rather than offering a button that cannot
  /// work.
  static bool get syncConfigured =>
      authBaseUrl.isNotEmpty && dataApiUrl.isNotEmpty;
}
