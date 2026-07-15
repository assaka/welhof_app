// Domain models parsed from Marello's JSON:API lot payload, served by the
// Welhof lot-intake bundle:
//   GET /api/welhoflots                        → lots (list)
//   GET /api/welhoflotitems?filter[lot]=<id>   → a lot's items
// (both reachable through welhof-proxy.php via ?resource=lots / lot-items).
//
// Reuses [JsonApiDocument] from marello_order.dart for relationship resolution.

import 'marello_order.dart' show JsonApiDocument;

/// A return/overstock lot (a mixed pallet described by a supplier manifest).
class MarelloLot {
  MarelloLot({
    required this.id,
    required this.lotNumber,
    this.condition,
    this.status,
    this.createdAt,
    this.postedAt,
  });

  final String id;
  final String lotNumber;
  final String? condition;

  /// Lot lifecycle: new / allocating / allocated / posted.
  final String? status;
  final DateTime? createdAt;

  /// When the lot's allocated items were posted to inventory (null if not yet).
  final DateTime? postedAt;

  bool get isPosted => status == 'posted';

  factory MarelloLot.fromResource(
    Map<String, dynamic> res,
    JsonApiDocument doc,
  ) {
    final a = (res['attributes'] as Map?)?.cast<String, dynamic>() ?? {};
    return MarelloLot(
      id: '${res['id']}',
      lotNumber: (a['lotNumber'] ?? res['id']).toString(),
      condition: a['condition']?.toString(),
      status: a['status']?.toString(),
      createdAt: DateTime.tryParse('${a['createdAt'] ?? ''}'),
      postedAt: DateTime.tryParse('${a['postedAt'] ?? ''}'),
    );
  }
}

/// One line of a lot. Starts `pending`; the floor captures it (barcode, photo,
/// qty, location → `captured`); the office allocates it to a product and posts
/// it to stock (`allocated` → `posted`).
class MarelloLotItem {
  MarelloLotItem({
    required this.id,
    required this.tempCode,
    required this.name,
    required this.quantity,
    required this.status,
    this.rawSku,
    this.barcode,
    this.cost,
    this.pickLocation,
    this.photoUrl,
    this.notes,
    this.allocatedProductSku,
    this.allocatedProductName,
  });

  final String id;

  /// Interim identity (e.g. `LOT000001-003`) — scannable before the item is a
  /// real product.
  final String tempCode;
  final String name;
  final int quantity;

  /// pending / captured / allocated / posted.
  final String status;
  final String? rawSku;

  /// Barcode/EAN scanned off the physical item on the floor.
  final String? barcode;
  final double? cost;

  /// Put-away pick/bin location.
  final String? pickLocation;

  /// Web path of the floor-captured photo (served from Marello), or null.
  final String? photoUrl;
  final String? notes;

  /// The catalog product this item has been allocated to (Marello product SKU is
  /// its JSON:API id), or null while unallocated.
  final String? allocatedProductSku;
  final String? allocatedProductName;

  bool get isPending => status == 'pending';
  bool get isCaptured => status == 'captured';
  bool get isAllocated => allocatedProductSku != null;

  factory MarelloLotItem.fromResource(
    Map<String, dynamic> res,
    JsonApiDocument doc,
  ) {
    final a = (res['attributes'] as Map?)?.cast<String, dynamic>() ?? {};
    final rels = (res['relationships'] as Map?)?.cast<String, dynamic>() ?? {};

    // allocatedProduct: a to-one linkage whose id is the product SKU.
    final apLink = (rels['allocatedProduct'] as Map?)?['data'];
    final apSku = (apLink is Map && apLink['id'] != null)
        ? '${apLink['id']}'
        : null;
    final apRes = doc.resolve(apLink);
    final apName =
        (apRes?['attributes'] as Map?)?['denormalizedDefaultName']?.toString();

    return MarelloLotItem(
      id: '${res['id']}',
      tempCode: (a['tempCode'] ?? res['id']).toString(),
      name: (a['name'] ?? '').toString(),
      quantity: _toDouble(a['quantity']).round(),
      status: (a['status'] ?? 'pending').toString(),
      rawSku: a['rawSku']?.toString(),
      barcode: a['barcode']?.toString(),
      cost: a['cost'] == null ? null : _toDouble(a['cost']),
      pickLocation: a['pickLocation']?.toString(),
      photoUrl: a['photoUrl']?.toString(),
      notes: a['notes']?.toString(),
      allocatedProductSku: apSku,
      allocatedProductName: apName,
    );
  }

  /// Parses the flat (non-JSON:API) object returned by the capture endpoint
  /// (`POST welhof-proxy.php?resource=capture`).
  factory MarelloLotItem.fromCaptureJson(Map<String, dynamic> j) =>
      MarelloLotItem(
        id: '${j['id']}',
        tempCode: (j['tempCode'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        quantity: _toDouble(j['quantity']).round(),
        status: (j['status'] ?? 'captured').toString(),
        barcode: j['barcode']?.toString(),
        pickLocation: j['pickLocation']?.toString(),
        photoUrl: j['photoUrl']?.toString(),
      );
}

/// A product hit from the barcode/name search endpoint
/// (`GET welhof-proxy.php?resource=products&barcode=|name=`), which returns a
/// plain `{data:[{sku,name,barcode}]}` list rather than a JSON:API document.
class MarelloProductHit {
  MarelloProductHit({required this.sku, required this.name, this.barcode});

  final String sku;
  final String name;
  final String? barcode;

  factory MarelloProductHit.fromJson(Map<String, dynamic> j) => MarelloProductHit(
        sku: (j['sku'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        barcode: j['barcode']?.toString(),
      );
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}
