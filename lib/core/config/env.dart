/// Build with: flutter run --dart-define=API_BASE_URL=https://uat-api.cleverbill.in
class Env {
  static const apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.cleverbill.in',
  );
}
