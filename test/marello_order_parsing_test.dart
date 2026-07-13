import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:welhof_app/models/marello_order.dart';

/// Parses a real `GET /api/marelloorders?include=items` payload captured from
/// the Marello instance (test/fixtures/marello_orders_sample.json) to lock the
/// JSON:API mapping against the actual API shape.
void main() {
  late List<MarelloOrder> orders;

  setUpAll(() {
    final raw =
        File('test/fixtures/marello_orders_sample.json').readAsStringSync();
    final doc = JsonApiDocument.parse(
        jsonDecode(raw) as Map<String, dynamic>);
    orders = [for (final r in doc.data) MarelloOrder.fromResource(r, doc)];
  });

  test('parses the collection', () {
    expect(orders, isNotEmpty);
  });

  test('maps the newest order (TEST-00040) correctly', () {
    final o = orders.firstWhere((o) => o.orderNumber == 'TEST-00040');
    expect(o.id, '40');
    expect(o.currency, 'EUR');
    expect(o.grandTotal, closeTo(31.98, 0.001));
    expect(o.status, 'Pending Order'); // workflowItem.currentStep.label
  });

  test('resolves included line items', () {
    final o = orders.firstWhere((o) => o.orderNumber == 'TEST-00040');
    expect(o.items, isNotEmpty);
    final item = o.items.first;
    expect(item.productSku, 'HBS-TS-1102Z-N');
    expect(item.quantity, 2);
    expect(item.rowTotal, closeTo(31.98, 0.001));
    expect(o.itemCount, 2); // summed quantities
  });
}
