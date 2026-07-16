import 'dart:convert';
import 'dart:io';

class CrossPromoHttpResponse {
  const CrossPromoHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

abstract interface class CrossPromoTransport {
  Future<CrossPromoHttpResponse> post(
    Uri uri,
    Map<String, Object?> body, {
    String? bearerToken,
    String? idempotencyKey,
  });
}

class IoCrossPromoTransport implements CrossPromoTransport {
  IoCrossPromoTransport(this.timeout);

  final Duration timeout;

  @override
  Future<CrossPromoHttpResponse> post(
    Uri uri,
    Map<String, Object?> body, {
    String? bearerToken,
    String? idempotencyKey,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (bearerToken != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $bearerToken',
        );
      }
      if (idempotencyKey != null) {
        request.headers.set('Idempotency-Key', idempotencyKey);
      }
      request.write(jsonEncode(body));
      final response = await request.close().timeout(timeout);
      final responseBody =
          await utf8.decoder.bind(response).join().timeout(timeout);
      return CrossPromoHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: true);
    }
  }
}
