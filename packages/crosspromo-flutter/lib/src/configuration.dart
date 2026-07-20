import 'package:flutter/foundation.dart';

enum CrossPromoEnvironment { production, sandbox }

class CrossPromoConfiguration {
  CrossPromoConfiguration({
    required this.appKey,
    CrossPromoEnvironment? environment,
    Uri? baseUri,
    this.requestTimeout = const Duration(seconds: 10),
  })  : environment = environment ?? _automaticEnvironment,
        baseUri = baseUri ?? _uriFor(environment ?? _automaticEnvironment) {
    if (!appKey.startsWith('cp_live_') && !appKey.startsWith('cpn_live_')) {
      throw ArgumentError.value(
        appKey,
        'appKey',
        'must be the key shown in your CrossPromo dashboard',
      );
    }
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'must be positive',
      );
    }
  }

  final String appKey;
  final CrossPromoEnvironment environment;
  final Uri baseUri;
  final Duration requestTimeout;

  static CrossPromoEnvironment get _automaticEnvironment => kDebugMode
      ? CrossPromoEnvironment.sandbox
      : CrossPromoEnvironment.production;

  static Uri _uriFor(CrossPromoEnvironment environment) =>
      switch (environment) {
        CrossPromoEnvironment.production ||
        CrossPromoEnvironment.sandbox =>
          Uri.parse('https://backend-j5mh.onrender.com'),
      };
}
