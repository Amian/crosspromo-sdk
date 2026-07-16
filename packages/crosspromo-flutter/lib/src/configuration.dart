enum CrossPromoEnvironment { production, sandbox }

class CrossPromoConfiguration {
  CrossPromoConfiguration({
    required this.appKey,
    this.environment = CrossPromoEnvironment.production,
    Uri? baseUri,
    this.requestTimeout = const Duration(seconds: 10),
  }) : baseUri = baseUri ?? _uriFor(environment) {
    if (!appKey.startsWith('cp_live_') && !appKey.startsWith('cp_test_')) {
      throw ArgumentError.value(
        appKey,
        'appKey',
        'must start with cp_live_ or cp_test_',
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

  static Uri _uriFor(CrossPromoEnvironment environment) =>
      switch (environment) {
        CrossPromoEnvironment.production => Uri.parse(
            'https://api.crosspromo.app',
          ),
        CrossPromoEnvironment.sandbox => Uri.parse(
            'https://sandbox-api.crosspromo.app',
          ),
      };
}
