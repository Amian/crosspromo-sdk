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
  HttpClient? _client;

  /// One client for the SDK's lifetime, so the TCP and TLS handshake is paid once
  /// rather than on every call. A cold ad load makes three requests back to back;
  /// building and force-closing a client per request made each of them open a new
  /// connection, which on a mobile network cost more than the requests themselves.
  HttpClient _sharedClient() {
    final existing = _client;
    if (existing != null) return existing;
    final created = HttpClient();
    created.connectionTimeout = timeout;
    created.idleTimeout = const Duration(seconds: 30);
    _client = created;
    return created;
  }

  /// Releases the pooled connections. The SDK does not call this during normal
  /// operation — the client is meant to live as long as the app.
  void close() {
    _client?.close();
    _client = null;
  }

  @override
  Future<CrossPromoHttpResponse> post(
    Uri uri,
    Map<String, Object?> body, {
    String? bearerToken,
    String? idempotencyKey,
  }) async {
    final client = _sharedClient();
    final request = await client.postUrl(uri).timeout(timeout);
    try {
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
    } on Object {
      // A `timeout` on its own does not tear down the underlying request, and the
      // client is now shared rather than force-closed per call — so a stalled
      // request would keep occupying a pooled connection. Abort releases it.
      request.abort();
      rethrow;
    }
  }
}
