// Packing-slip picking models, parsed from the Welhof pick endpoint (plain JSON
// via welhof-proxy.php ?resource=pick). Pick state lives on Marello's packing
// slip, so both the app and Marello see the same picked_qty / dock / status.

/// A packing slip being picked: its items and roll-up pick state.
class PickSlip {
  PickSlip({
    required this.id,
    required this.number,
    required this.orderNumber,
    required this.pickStatus,
    required this.completed,
    required this.itemCount,
    required this.pickedItemCount,
    required this.items,
  });

  final int id;
  final String number;
  final String? orderNumber;
  final String pickStatus; // 'in_progress' | 'completed'
  final bool completed;
  final int itemCount;
  final int pickedItemCount;
  final List<PickItem> items;

  factory PickSlip.fromJson(Map<String, dynamic> j) {
    final rawItems = (j['items'] as List?) ?? const [];
    return PickSlip(
      id: (j['id'] as num?)?.toInt() ?? 0,
      number: '${j['packingSlipNumber'] ?? j['id'] ?? ''}',
      orderNumber: j['orderNumber']?.toString(),
      pickStatus: '${j['pickStatus'] ?? 'in_progress'}',
      completed: j['completed'] == true,
      itemCount: (j['itemCount'] as num?)?.toInt() ?? rawItems.length,
      pickedItemCount: (j['pickedItemCount'] as num?)?.toInt() ?? 0,
      items: [
        for (final i in rawItems)
          if (i is Map<String, dynamic>) PickItem.fromJson(i),
      ],
    );
  }
}

/// One packing-slip line: how many of its [quantity] units are picked, and the
/// dock it's staged at once sorted.
class PickItem {
  PickItem({
    required this.id,
    required this.productSku,
    required this.productName,
    required this.quantity,
    required this.pickedQty,
    required this.sortDock,
  });

  final int id;
  final String productSku;
  final String productName;
  final int quantity;
  final int pickedQty;
  final String? sortDock;

  bool get complete => pickedQty >= quantity;
  bool get sorted => sortDock != null && sortDock!.isNotEmpty;

  factory PickItem.fromJson(Map<String, dynamic> j) => PickItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        productSku: '${j['productSku'] ?? ''}',
        productName: '${j['productName'] ?? ''}',
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        pickedQty: (j['pickedQty'] as num?)?.toInt() ?? 0,
        sortDock: (j['sortDock'] == null || '${j['sortDock']}'.isEmpty)
            ? null
            : '${j['sortDock']}',
      );
}

/// Outcome of scanning a barcode against a slip.
class ScanResult {
  ScanResult({
    required this.matched,
    required this.slip,
    this.error,
    this.productSku,
    this.pickedQty,
    this.quantity,
    this.complete = false,
    this.alreadyComplete = false,
  });

  /// True when the barcode matched an item in the slip (whether or not it was
  /// already fully picked).
  final bool matched;

  /// Server error code when unmatched, e.g. 'not_in_slip', 'no_barcode'.
  final String? error;

  final String? productSku;
  final int? pickedQty;
  final int? quantity;
  final bool complete;
  final bool alreadyComplete;

  /// Fresh slip state after the scan (null on error).
  final PickSlip? slip;

  factory ScanResult.matched(Map<String, dynamic> j) => ScanResult(
        matched: true,
        productSku: j['productSku']?.toString(),
        pickedQty: (j['pickedQty'] as num?)?.toInt(),
        quantity: (j['quantity'] as num?)?.toInt(),
        complete: j['complete'] == true,
        alreadyComplete: j['alreadyComplete'] == true,
        slip: j['slip'] is Map<String, dynamic>
            ? PickSlip.fromJson(j['slip'] as Map<String, dynamic>)
            : null,
      );

  factory ScanResult.failed(String error) =>
      ScanResult(matched: false, slip: null, error: error);
}
