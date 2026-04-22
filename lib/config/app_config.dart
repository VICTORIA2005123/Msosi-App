/// Build-time configuration for production and staging.
///
/// Example:
/// `flutter run --dart-define=API_BASE_URL=https://api.yourcampus.edu/api --dart-define=WS_URL=wss://api.yourcampus.edu/ws`
class AppConfig {
  AppConfig._();

  /// REST API base URL (no trailing slash).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://your-campus-api.com/api',
  );

  /// WebSocket URL for real-time order and menu updates. Leave empty to disable.
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: '',
  );

  /// Payment gateway to use in-app: `razorpay` or `stripe`.
  static const String paymentGateway = String.fromEnvironment(
    'PAYMENT_GATEWAY',
    defaultValue: 'razorpay',
  );

  /// Stripe publishable key (required when using Stripe in mobile builds).
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// Razorpay key id (required when using Razorpay).
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );
}
