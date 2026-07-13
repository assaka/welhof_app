// ignore_for_file: avoid_print
//
// Exercises the app's real Marello fetch path (MarelloConfig + MarelloService)
// against the live instance, printing what the Order Picking "All" tab shows.
//
// Run (credentials come from --dart-define, e.g. sourced from .marello_env):
//   dart run \
//     --define=MARELLO_API_USER=<user> \
//     --define=MARELLO_API_KEY=<plaintext key> \
//     tool/fetch_orders_demo.dart
import 'package:welhof_app/services/marello_service.dart';

Future<void> main() async {
  final config = MarelloConfig.fromEnvironment();
  final service = MarelloService(config: config);
  try {
    print('Fetching orders from ${config.baseUrl} as "${config.apiUser}" …\n');
    final orders = await service.fetchOrders(pageSize: 5);
    print('✓ Fetched ${orders.length} order(s):\n');
    for (final o in orders) {
      final total = '${o.currency} ${o.grandTotal.toStringAsFixed(2)}';
      print('  • ${o.orderNumber.padRight(12)} '
          '${(o.status ?? '-').padRight(16)} '
          '${total.padRight(12)}  ${o.itemCount} item(s)');
      for (final it in o.items) {
        print('       – ${it.quantity}× ${it.productSku}  ${it.productName}');
      }
    }
  } on MarelloApiException catch (e) {
    print('✗ Marello API error: $e');
  } finally {
    service.dispose();
  }
}
