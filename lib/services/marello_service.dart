import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/marello_order.dart';
import 'marello_auth.dart';

/// Connection settings for the Marello instance.
///
/// Read from `--dart-define` at build/run time so no credentials live in
/// source, e.g.:
///
/// ```
/// flutter run \
///   --dart-define=MARELLO_BASE_URL=https://test-marello.welhof.com \
///   --dart-define=MARELLO_API_USER=apiuser \
///   --dart-define=MARELLO_API_KEY=xxxxxxxx
/// ```
class MarelloConfig {
  const MarelloConfig({
    required this.baseUrl,
    required this.apiUser,
    required this.apiKey,
  });

  final String baseUrl;
  final String apiUser;
  final String apiKey;

  factory MarelloConfig.fromEnvironment() => const MarelloConfig(
        baseUrl: String.fromEnvironment(
          'MARELLO_BASE_URL',
          // staging-marello resolves in public DNS; test-marello does not.
          // Both front the same Marello instance / order data.
          defaultValue: 'https://staging-marello.welhof.com',
        ),
        apiUser: String.fromEnvironment('MARELLO_API_USER'),
        apiKey: String.fromEnvironment('MARELLO_API_KEY'),
      );

  bool get hasCredentials => apiUser.isNotEmpty && apiKey.isNotEmpty;
}

/// Raised when a Marello API call fails; [statusCode] is null on transport
/// errors (no HTTP response).
class MarelloApiException implements Exception {
  MarelloApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'MarelloApiException'
      '${statusCode != null ? ' ($statusCode)' : ''}: $message';
}

/// Thin client over Marello's Oro JSON:API. Currently exposes order fetching.
class MarelloService {
  MarelloService({required this.config, MarelloAuth? auth, http.Client? client})
      : _auth = auth ??
            WsseAuth(username: config.apiUser, apiKey: config.apiKey),
        _client = client ?? http.Client();

  final MarelloConfig config;
  final MarelloAuth _auth;
  final http.Client _client;

  static const _jsonApi = 'application/vnd.api+json';

  /// Fetches orders (newest first), resolving their line items in one round
  /// trip via `include=items`. [pageSize] caps the page.
  ///
  /// [status] filters by workflow-step label/name — applied client-side, as
  /// the order status is a workflow step, not an API-filterable field (only
  /// `orderNumber` / `orderReference` are).
  Future<List<MarelloOrder>> fetchOrders({
    String? status,
    int pageSize = 50,
  }) async {
    if (!config.hasCredentials) {
      throw MarelloApiException(
        'Missing Marello credentials. Pass --dart-define=MARELLO_API_USER '
        'and --dart-define=MARELLO_API_KEY.',
      );
    }

    final uri = Uri.parse('${config.baseUrl}/api/marelloorders').replace(
      queryParameters: <String, String>{
        'include': 'items',
        'page[size]': '$pageSize',
        'sort': '-id',
      },
    );

    late final http.Response res;
    try {
      res = await _client.get(uri, headers: {
        'Accept': _jsonApi,
        ...await _auth.authHeaders(),
      });
    } catch (e) {
      throw MarelloApiException('Network error: $e');
    }

    if (res.statusCode != 200) {
      throw MarelloApiException(
        _describeError(res),
        statusCode: res.statusCode,
      );
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw MarelloApiException('Unexpected response shape.');
    }
    final doc = JsonApiDocument.parse(body);
    final orders = [
      for (final r in doc.data) MarelloOrder.fromResource(r, doc),
    ];
    if (status == null || status.isEmpty) return orders;
    final needle = status.toLowerCase();
    return orders
        .where((o) => (o.status ?? '').toLowerCase() == needle)
        .toList();
  }

  /// Turns an error response into a readable message, preferring the JSON:API
  /// `errors[].detail`/`title` when present.
  String _describeError(http.Response res) {
    if (res.statusCode == 401) {
      return 'Authentication failed (401). Check the API user and key.';
    }
    try {
      final body = jsonDecode(res.body);
      final errors = (body as Map)['errors'];
      if (errors is List && errors.isNotEmpty) {
        final e = errors.first as Map;
        return (e['detail'] ?? e['title'] ?? 'Request failed').toString();
      }
    } catch (_) {/* fall through to generic message */}
    return 'Request failed (${res.statusCode}).';
  }

  void dispose() => _client.close();
}
