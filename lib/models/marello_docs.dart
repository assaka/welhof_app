// Back-office document models: purchase orders and packing slips, parsed from
// Marello's JSON:API (`/api/marellopurchaseorders`, `/api/marellopackingslips`),
// reachable via welhof-proxy.php (?resource=purchase-orders / packing-slips).

import 'marello_order.dart' show JsonApiDocument;

/// A supplier purchase order.
class MarelloPurchaseOrder {
  MarelloPurchaseOrder({
    required this.id,
    required this.poNumber,
    this.supplierName,
    this.orderTotal,
    this.dueDate,
  });

  final String id;
  final String poNumber;
  final String? supplierName;
  final double? orderTotal;
  final DateTime? dueDate;

  factory MarelloPurchaseOrder.fromResource(
    Map<String, dynamic> res,
    JsonApiDocument doc,
  ) {
    final a = (res['attributes'] as Map?)?.cast<String, dynamic>() ?? {};
    final rels = (res['relationships'] as Map?)?.cast<String, dynamic>() ?? {};
    final supplier = doc.resolve((rels['supplier'] as Map?)?['data']);
    final supplierName =
        (supplier?['attributes'] as Map?)?['name']?.toString();

    return MarelloPurchaseOrder(
      id: '${res['id']}',
      poNumber: (a['purchaseOrderNumber'] ?? res['id']).toString(),
      supplierName: supplierName,
      orderTotal: a['orderTotal'] == null ? null : _toDouble(a['orderTotal']),
      dueDate: DateTime.tryParse('${a['dueDate'] ?? ''}'),
    );
  }
}

/// A packing slip (fulfilment document).
class MarelloPackingSlip {
  MarelloPackingSlip({required this.id, required this.number});

  final String id;
  final String number;

  factory MarelloPackingSlip.fromResource(
    Map<String, dynamic> res,
    JsonApiDocument doc,
  ) {
    final a = (res['attributes'] as Map?)?.cast<String, dynamic>() ?? {};
    return MarelloPackingSlip(
      id: '${res['id']}',
      number: (a['packingSlipNumber'] ?? res['id']).toString(),
    );
  }
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}
