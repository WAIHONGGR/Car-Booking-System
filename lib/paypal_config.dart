import 'package:flutter/foundation.dart';

/// PayPal Sandbox credentials
/// WARNING: Do not ship real secrets in a client app. For production,
/// move the order creation/capture to a secure backend and do not
/// embed the secret in the app.
class PaypalConfig {
  static const bool sandbox = true;

  // Replace with your own Sandbox credentials (for quick demo only)
  static const String clientId =
      'ATdmAYrbrxsm1KjFdCk0W5au2ALeNT1T6ZLZxEwf03sMMLnjV64WBLX13_f4bY_UuHuOULMCUEdM3qED';

  // NOTE: Embedding secrets in apps is insecure. Use ONLY for sandbox demos.
  static const String secret =
      'EEnsfrdwtmNzNMMXw50lDP_7XVJzLb1_Wzz5vX8vcNxCow6nfopSQ-K-RbnGG82s45FVAhFECFSwjhMa';

  // Optional: Customize branding
  static const String returnURL = 'success://paypal_payment';
  static const String cancelURL = 'cancel://paypal_payment';

  // Currency to use for charges
  static const String currency = 'MYR';
}


