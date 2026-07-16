class PromoCardData {
  const PromoCardData({
    required this.cardId,
    required this.appName,
    required this.iconUrl,
    required this.tagline,
    required this.cta,
    required this.clickUrl,
    required this.impressionToken,
    required this.expiresAt,
  });

  factory PromoCardData.fromJson(Map<String, Object?> json) => PromoCardData(
        cardId: json['card_id']! as String,
        appName: json['app_name']! as String,
        iconUrl: Uri.parse(json['icon_url']! as String),
        tagline: json['tagline']! as String,
        cta: json['cta']! as String,
        clickUrl: Uri.parse(json['click_url']! as String),
        impressionToken: json['impression_token']! as String,
        expiresAt: DateTime.parse(json['expires_at']! as String),
      );

  final String cardId;
  final String appName;
  final Uri iconUrl;
  final String tagline;
  final String cta;
  final Uri clickUrl;
  final String impressionToken;
  final DateTime expiresAt;
}

class CrossPromoSessionStatus {
  const CrossPromoSessionStatus({
    required this.publisherAppId,
    required this.countsEnabled,
    required this.expiresAt,
    this.reason,
  });

  final String publisherAppId;
  final bool countsEnabled;
  final DateTime expiresAt;
  final String? reason;
}

class AppContext {
  const AppContext({
    required this.installationId,
    required this.platform,
    required this.bundleId,
    required this.version,
    required this.buildNumber,
  });

  factory AppContext.fromJson(Map<Object?, Object?> json) => AppContext(
        installationId: json['installation_id']! as String,
        platform: json['platform']! as String,
        bundleId: json['bundle_id']! as String,
        version: json['version']! as String,
        buildNumber: json['build_number']! as String,
      );

  final String installationId;
  final String platform;
  final String bundleId;
  final String version;
  final String buildNumber;

  Map<String, Object?> toJson() => {
        'platform': platform,
        'bundle_id': bundleId,
        'version': version,
        'build_number': buildNumber,
      };
}

class IntegrityPreparation {
  const IntegrityPreparation({
    required this.provider,
    this.keyId,
    this.appTransactionJws,
    this.deviceVerificationId,
  });

  factory IntegrityPreparation.fromJson(Map<Object?, Object?> json) =>
      IntegrityPreparation(
        provider: json['provider']! as String,
        keyId: json['key_id'] as String?,
        appTransactionJws: json['app_transaction_jws'] as String?,
        deviceVerificationId: json['device_verification_id'] as String?,
      );

  final String provider;
  final String? keyId;
  final String? appTransactionJws;
  final String? deviceVerificationId;

  Map<String, Object?> toJson() => {
        'provider': provider,
        'key_id': keyId,
        'app_transaction_jws': appTransactionJws,
        'device_verification_id': deviceVerificationId,
      };
}

class IntegrityEvidence {
  const IntegrityEvidence({
    required this.provider,
    required this.payloadBase64,
    this.keyId,
  });

  factory IntegrityEvidence.fromJson(Map<Object?, Object?> json) =>
      IntegrityEvidence(
        provider: json['provider']! as String,
        keyId: json['key_id'] as String?,
        payloadBase64: json['payload_base64']! as String,
      );

  final String provider;
  final String? keyId;
  final String payloadBase64;

  Map<String, Object?> toJson() => {
        'provider': provider,
        'key_id': keyId,
        'payload_base64': payloadBase64,
      };
}
