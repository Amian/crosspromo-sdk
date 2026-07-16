import 'package:flutter/services.dart';

import 'models.dart';

abstract interface class CrossPromoPlatform {
  Future<AppContext> getAppContext();

  Future<IntegrityPreparation> prepareIntegrity();

  Future<IntegrityEvidence> generateEvidence({
    required String challengeBase64,
    required String mode,
    int? cloudProjectNumber,
  });

  Future<void> openUrl(Uri url);

  Future<void> resetInstallationId();
}

class MethodChannelCrossPromoPlatform implements CrossPromoPlatform {
  static const _channel = MethodChannel('app.crosspromo/sdk');

  @override
  Future<AppContext> getAppContext() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'getAppContext',
    );
    if (result == null) {
      throw StateError('Native app context was unavailable');
    }
    return AppContext.fromJson(result);
  }

  @override
  Future<IntegrityPreparation> prepareIntegrity() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'prepareIntegrity',
    );
    if (result == null) {
      throw StateError('Native integrity provider was unavailable');
    }
    return IntegrityPreparation.fromJson(result);
  }

  @override
  Future<IntegrityEvidence> generateEvidence({
    required String challengeBase64,
    required String mode,
    int? cloudProjectNumber,
  }) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'generateEvidence',
      <String, Object?>{
        'challenge_base64': challengeBase64,
        'mode': mode,
        'cloud_project_number': cloudProjectNumber,
      },
    );
    if (result == null) {
      throw StateError('Native integrity evidence was unavailable');
    }
    return IntegrityEvidence.fromJson(result);
  }

  @override
  Future<void> openUrl(Uri url) =>
      _channel.invokeMethod<void>('openUrl', {'url': url.toString()});

  @override
  Future<void> resetInstallationId() =>
      _channel.invokeMethod<void>('resetInstallationId');
}
