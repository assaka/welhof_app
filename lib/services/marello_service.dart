import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/marello_docs.dart';
import '../models/marello_lot.dart';
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
    this.ordersEndpoint = '',
  });

  final String baseUrl;
  final String apiUser;
  final String apiKey;

  /// Full URL of a server-side orders proxy. When set (e.g. for the public
  /// web build), the app calls it directly and sends NO credentials — the
  /// proxy holds the Marello key and handles WSSE + CORS server-side.
  final String ordersEndpoint;

  factory MarelloConfig.fromEnvironment() => const MarelloConfig(
        baseUrl: String.fromEnvironment(
          'MARELLO_BASE_URL',
          // staging-marello resolves in public DNS; test-marello does not.
          // Both front the same Marello instance / order data.
          defaultValue: 'https://staging-marello.welhof.com',
        ),
        apiUser: String.fromEnvironment('MARELLO_API_USER'),
        apiKey: String.fromEnvironment('MARELLO_API_KEY'),
        ordersEndpoint: String.fromEnvironment('MARELLO_ORDERS_ENDPOINT'),
      );

  /// Whether to route through the server-side proxy instead of calling
  /// Marello directly with WSSE credentials.
  bool get usesProxy => ordersEndpoint.isNotEmpty;

  bool get hasCredentials => apiUser.isNotEmpty && apiKey.isNotEmpty;

  /// Base URL of the product-image endpoint (sibling of the orders proxy),
  /// or empty when not proxying. Call as `$imageEndpoint?product=<sku>`.
  String get imageEndpoint => usesProxy
      ? ordersEndpoint.replaceFirst(
          RegExp(r'welhof-proxy\.php$'), 'welhof-image.php')
      : '';

  /// Image URL for a product SKU, or null when unavailable.
  String? imageUrlFor(String sku) => imageEndpoint.isEmpty
      ? null
      : '$imageEndpoint?product=${Uri.encodeQueryComponent(sku)}';
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
      : _auth =
            auth ?? WsseAuth(username: config.apiUser, apiKey: config.apiKey),
        _client = client ?? http.Client();

  final MarelloConfig config;
  final MarelloAuth _auth;
  final http.Client _client;

  static const _jsonApi = 'application/vnd.api+json';

  /// Fetches orders (newest first), resolving line items (and, via the proxy,
  /// product/customer data) in one round trip. [pageSize] caps the page.
  ///
  /// [status] filters by workflow-step label/name — applied client-side, as
  /// the order status is a workflow step, not an API-filterable field.
  Future<List<MarelloOrder>> fetchOrders({
    String? status,
    int pageSize = 50,
  }) async {
    if (!config.usesProxy && !config.hasCredentials) {
      throw MarelloApiException(
        'Marello connection not configured. Set MARELLO_ORDERS_ENDPOINT '
        '(proxy) or MARELLO_API_USER + MARELLO_API_KEY (direct).',
      );
    }

    // Proxy mode calls the server-side endpoint verbatim (it injects auth);
    // direct mode hits Marello's JSON:API with a client-side WSSE header.
    final base = config.usesProxy
        ? config.ordersEndpoint
        : '${config.baseUrl}/api/marelloorders';
    final uri = Uri.parse(base).replace(
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
        if (!config.usesProxy) ...await _auth.authHeaders(),
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

  /// Fetches return/overstock lots (newest first) for the floor-capture flow.
  Future<List<MarelloLot>> fetchLots({int pageSize = 50}) async {
    _ensureConfigured();
    final base = config.usesProxy
        ? config.ordersEndpoint
        : '${config.baseUrl}/api/welhoflots';
    final uri = Uri.parse(base).replace(queryParameters: <String, String>{
      if (config.usesProxy) 'resource': 'lots',
      'sort': '-id',
      'page[size]': '$pageSize',
    });
    final doc = await _fetchDoc(uri);
    return [for (final r in doc.data) MarelloLot.fromResource(r, doc)];
  }

  /// Fetches a lot's items, optionally filtered by [status] (e.g. `pending`).
  Future<List<MarelloLotItem>> fetchLotItems(
    String lotId, {
    String? status,
    int pageSize = 100,
  }) async {
    _ensureConfigured();
    final hasStatus = status != null && status.isNotEmpty;
    final base = config.usesProxy
        ? config.ordersEndpoint
        : '${config.baseUrl}/api/welhoflotitems';
    final uri = Uri.parse(base).replace(queryParameters: <String, String>{
      if (config.usesProxy) ...{
        'resource': 'lot-items',
        'lot': lotId,
        if (hasStatus) 'status': status,
      } else ...{
        'include': 'allocatedProduct',
        'filter[lot]': lotId,
        if (hasStatus) 'filter[status]': status,
      },
      'sort': 'tempCode',
      'page[size]': '$pageSize',
    });
    final doc = await _fetchDoc(uri);
    return [for (final r in doc.data) MarelloLotItem.fromResource(r, doc)];
  }

  /// Searches products by [barcode] (exact) or [name] (fuzzy) for the capture
  /// match cascade. Proxy-only for now (the barcode index lives server-side);
  /// returns [] if neither term is given.
  Future<List<MarelloProductHit>> searchProducts({
    String? barcode,
    String? name,
  }) async {
    final bc = barcode?.trim() ?? '';
    final nm = name?.trim() ?? '';
    if (bc.isEmpty && nm.isEmpty) return [];
    if (!config.usesProxy) {
      throw MarelloApiException('Product search is available in proxy mode only.');
    }
    final uri = Uri.parse(config.ordersEndpoint).replace(
      queryParameters: <String, String>{
        'resource': 'products',
        if (bc.isNotEmpty) 'barcode': bc,
        if (nm.isNotEmpty) 'name': nm,
      },
    );

    late final http.Response res;
    try {
      res = await _client.get(uri, headers: {'Accept': 'application/json'});
    } catch (e) {
      throw MarelloApiException('Network error: $e');
    }
    if (res.statusCode != 200) {
      throw MarelloApiException(_describeError(res), statusCode: res.statusCode);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    final data = (body is Map ? body['data'] : null);
    if (data is! List) return [];
    return [
      for (final e in data)
        if (e is Map<String, dynamic>) MarelloProductHit.fromJson(e),
    ];
  }

  /// Captures a lot item from the floor: barcode / quantity / pick location and
  /// an optional [photoBytes]. Proxy-only (the write path injects auth
  /// server-side). Returns the updated item.
  Future<MarelloLotItem> captureLotItem(
    String itemId, {
    String? barcode,
    int? quantity,
    String? pickLocation,
    List<int>? photoBytes,
    String photoFilename = 'photo.jpg',
  }) async {
    if (!config.usesProxy) {
      throw MarelloApiException('Capture is available in proxy mode only.');
    }
    final uri = Uri.parse(config.ordersEndpoint).replace(
      queryParameters: <String, String>{'resource': 'capture', 'item': itemId},
    );
    final req = http.MultipartRequest('POST', uri);
    if (barcode != null && barcode.isNotEmpty) req.fields['barcode'] = barcode;
    if (quantity != null) req.fields['quantity'] = '$quantity';
    if (pickLocation != null && pickLocation.isNotEmpty) {
      req.fields['pickLocation'] = pickLocation;
    }
    if (photoBytes != null && photoBytes.isNotEmpty) {
      req.files.add(
        http.MultipartFile.fromBytes('photo', photoBytes, filename: photoFilename),
      );
    }

    late final http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(req));
    } catch (e) {
      throw MarelloApiException('Network error: $e');
    }
    if (res.statusCode != 200) {
      throw MarelloApiException(_describeError(res), statusCode: res.statusCode);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw MarelloApiException('Unexpected capture response.');
    }
    return MarelloLotItem.fromCaptureJson(body);
  }

  /// Fetches supplier purchase orders (newest first).
  Future<List<MarelloPurchaseOrder>> fetchPurchaseOrders({int pageSize = 50}) async {
    _ensureConfigured();
    final base = config.usesProxy
        ? config.ordersEndpoint
        : '${config.baseUrl}/api/marellopurchaseorders';
    final uri = Uri.parse(base).replace(queryParameters: <String, String>{
      if (config.usesProxy) 'resource': 'purchase-orders',
      if (!config.usesProxy) 'include': 'supplier',
      'sort': '-id',
      'page[size]': '$pageSize',
    });
    final doc = await _fetchDoc(uri);
    return [for (final r in doc.data) MarelloPurchaseOrder.fromResource(r, doc)];
  }

  /// Fetches packing slips (newest first).
  Future<List<MarelloPackingSlip>> fetchPackingSlips({int pageSize = 50}) async {
    _ensureConfigured();
    final base = config.usesProxy
        ? config.ordersEndpoint
        : '${config.baseUrl}/api/marellopackingslips';
    final uri = Uri.parse(base).replace(queryParameters: <String, String>{
      if (config.usesProxy) 'resource': 'packing-slips',
      'sort': '-id',
      'page[size]': '$pageSize',
    });
    final doc = await _fetchDoc(uri);
    return [for (final r in doc.data) MarelloPackingSlip.fromResource(r, doc)];
  }

  /// OCRs a photo of a product's name (server-side tesseract) and returns the
  /// best-guess text, for feeding the name search. Proxy-only.
  Future<String> ocrProductName(
    List<int> photoBytes, {
    String filename = 'name.jpg',
  }) async {
    if (!config.usesProxy) {
      throw MarelloApiException('OCR is available in proxy mode only.');
    }
    final uri = Uri.parse(config.ordersEndpoint).replace(
      queryParameters: <String, String>{'resource': 'ocr'},
    );
    final req = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes('photo', photoBytes,
          filename: filename));

    late final http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(req));
    } catch (e) {
      throw MarelloApiException('Network error: $e');
    }
    if (res.statusCode != 200) {
      throw MarelloApiException(_describeError(res), statusCode: res.statusCode);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    return (body is Map && body['text'] is String) ? body['text'] as String : '';
  }

  void _ensureConfigured() {
    if (!config.usesProxy && !config.hasCredentials) {
      throw MarelloApiException(
        'Marello connection not configured. Set MARELLO_ORDERS_ENDPOINT '
        '(proxy) or MARELLO_API_USER + MARELLO_API_KEY (direct).',
      );
    }
  }

  /// GETs a JSON:API document (proxy injects auth; direct adds a WSSE header).
  Future<JsonApiDocument> _fetchDoc(Uri uri) async {
    late final http.Response res;
    try {
      res = await _client.get(uri, headers: {
        'Accept': _jsonApi,
        if (!config.usesProxy) ...await _auth.authHeaders(),
      });
    } catch (e) {
      throw MarelloApiException('Network error: $e');
    }
    if (res.statusCode != 200) {
      throw MarelloApiException(_describeError(res), statusCode: res.statusCode);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw MarelloApiException('Unexpected response shape.');
    }
    return JsonApiDocument.parse(body);
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
