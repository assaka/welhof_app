// Domain models parsed from Marello's JSON:API order payload
// (`GET /api/marelloorders?include=items,customer,items.product...`).
//
// A JSON:API document keeps related resources out-of-line in a top-level
// `included` array; JsonApiDocument indexes those by `type`+`id` so an
// order can resolve its `items` relationship into full MarelloOrderItems.

/// Index over a JSON:API document's primary `data` and its `included`
/// resources, for O(1) relationship resolution.
class JsonApiDocument {
  JsonApiDocument(this.data, this._byKey);

  /// Primary resources (the `data` array). Always a list here — the order
  /// list endpoint returns a collection.
  final List<Map<String, dynamic>> data;
  final Map<String, Map<String, dynamic>> _byKey;

  static String _key(String type, String id) => '$type $id';

  factory JsonApiDocument.parse(Map<String, dynamic> json) {
    final rawData = json['data'];
    final data = <Map<String, dynamic>>[];
    if (rawData is List) {
      for (final e in rawData) {
        if (e is Map<String, dynamic>) data.add(e);
      }
    } else if (rawData is Map<String, dynamic>) {
      data.add(rawData);
    }

    final byKey = <String, Map<String, dynamic>>{};
    void indexAll(dynamic list) {
      if (list is! List) return;
      for (final e in list) {
        if (e is Map<String, dynamic> &&
            e['type'] is String &&
            e['id'] != null) {
          byKey[_key(e['type'] as String, '${e['id']}')] = e;
        }
      }
    }

    indexAll(rawData);
    indexAll(json['included']);
    return JsonApiDocument(data, byKey);
  }

  /// Resolves a `{type, id}` linkage to its full resource, if present.
  Map<String, dynamic>? resolve(dynamic linkage) {
    if (linkage is! Map || linkage['type'] == null || linkage['id'] == null) {
      return null;
    }
    return _byKey[_key('${linkage['type']}', '${linkage['id']}')];
  }
}

class MarelloOrder {
  MarelloOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.grandTotal,
    required this.currency,
    required this.items,
    this.customerName,
    this.orderDate,
  });

  final String id;
  final String orderNumber;

  /// Human-readable order-status label (e.g. `pending`, `processing`), or
  /// `null` when the enum wasn't included in the response.
  final String? status;
  final double grandTotal;
  final String currency;
  final String? customerName;

  /// The order's purchase date (Marello `purchaseDate`), or null if absent.
  final DateTime? orderDate;
  final List<MarelloOrderItem> items;

  int get itemCount => items.fold(0, (sum, it) => sum + it.quantity);

  factory MarelloOrder.fromResource(
    Map<String, dynamic> res,
    JsonApiDocument doc,
  ) {
    final attrs = (res['attributes'] as Map?)?.cast<String, dynamic>() ?? {};
    final rels = (res['relationships'] as Map?)?.cast<String, dynamic>() ?? {};

    // items: a to-many relationship of order-item linkages.
    final items = <MarelloOrderItem>[];
    final itemData = (rels['items'] as Map?)?['data'];
    if (itemData is List) {
      for (final link in itemData) {
        final r = doc.resolve(link);
        if (r != null) items.add(MarelloOrderItem.fromResource(r, doc));
      }
    }

    // Status is the order's workflow step, inlined under attributes as
    // `workflowItem.currentStep` (e.g. label "Pending Order", name "pending").
    String? status;
    final wf = attrs['workflowItem'];
    if (wf is Map) {
      final step = wf['currentStep'];
      if (step is Map) {
        status = (step['label'] ?? step['name'])?.toString();
      }
    }

    // Customer name from the included customer resource. Marello has no single
    // `name` field, so compose it from first/last (falling back to `name`).
    final customerRes = doc.resolve((rels['customer'] as Map?)?['data']);
    final ca = (customerRes?['attributes'] as Map?)?.cast<String, dynamic>();
    String? customerName;
    if (ca != null) {
      final parts = [ca['firstName'], ca['lastName']]
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty);
      customerName =
          parts.isNotEmpty ? parts.join(' ') : ca['name']?.toString();
    }

    return MarelloOrder(
      id: '${res['id']}',
      orderNumber: (attrs['orderNumber'] ?? res['id']).toString(),
      status: status,
      grandTotal: _toDouble(attrs['grandTotal']),
      currency: (attrs['currency'] ?? '').toString(),
      customerName: customerName,
      orderDate: DateTime.tryParse('${attrs['purchaseDate'] ?? ''}'),
      items: items,
    );
  }
}

class MarelloOrderItem {
  MarelloOrderItem({
    required this.id,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.rowTotal,
    this.category,
    this.grade,
    this.hasImage = false,
    this.pickLocation,
  });

  /// Order-item resource id — a stable key for per-item picking state.
  final String id;
  final String productName;
  final String productSku;
  final int quantity;
  final double rowTotal;

  /// Product category / grade names, resolved from the item's product when the
  /// response includes them (`items.product.categories` / `.grade`).
  final String? category;
  final String? grade;

  /// Whether the product has an image (so the UI only requests existing ones).
  /// Fetch it from the image endpoint keyed by [productSku].
  final bool hasImage;

  /// Warehouse pick location (Marello `inventory_level.pick_location`),
  /// injected by the proxy; null when the payload doesn't carry it.
  final String? pickLocation;

  factory MarelloOrderItem.fromResource(
    Map<String, dynamic> res,
    JsonApiDocument doc,
  ) {
    final a = (res['attributes'] as Map?)?.cast<String, dynamic>() ?? {};
    final rels = (res['relationships'] as Map?)?.cast<String, dynamic>() ?? {};

    // Resolve the item's product to read category / grade / image presence.
    String? category, grade;
    bool hasImage = false;
    final product = doc.resolve((rels['product'] as Map?)?['data']);
    if (product != null) {
      final prels =
          (product['relationships'] as Map?)?.cast<String, dynamic>() ?? {};
      final catData = (prels['categories'] as Map?)?['data'];
      if (catData is List && catData.isNotEmpty) {
        final c = doc.resolve(catData.first);
        category = (c?['attributes'] as Map?)?['name']?.toString();
      }
      final gradeRes = doc.resolve((prels['grade'] as Map?)?['data']);
      grade = (gradeRes?['attributes'] as Map?)?['name']?.toString();
      hasImage = (prels['image'] as Map?)?['data'] != null;
    }

    return MarelloOrderItem(
      id: '${res['id']}',
      productName: (a['productName'] ?? '').toString(),
      productSku: (a['productSku'] ?? '').toString(),
      quantity: _toDouble(a['quantity']).round(),
      rowTotal: _toDouble(a['rowTotalInclTax'] ?? a['rowTotalExclTax']),
      category: category,
      grade: grade,
      hasImage: hasImage,
      pickLocation: a['pickLocation']?.toString(),
    );
  }
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}
