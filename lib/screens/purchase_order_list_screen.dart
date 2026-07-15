import 'package:flutter/material.dart';

import '../models/marello_docs.dart';
import '../services/marello_service.dart';
import '../theme.dart';
import 'lot_common.dart';

/// Supplier purchase orders (the "Batch" menu item).
class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  State<PurchaseOrderListScreen> createState() =>
      _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen> {
  late final MarelloService _service =
      MarelloService(config: MarelloConfig.fromEnvironment());
  late Future<List<MarelloPurchaseOrder>> _future =
      _service.fetchPurchaseOrders();

  Future<void> _refresh() async {
    final f = _service.fetchPurchaseOrders();
    setState(() => _future = f);
    await f.catchError((_) => <MarelloPurchaseOrder>[]);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MarelloPurchaseOrder>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return LotMessage(
                icon: Icons.cloud_off,
                title: 'Inkooporders laden mislukt',
                detail: '${snap.error}',
                onRetry: _refresh,
              );
            }
            final pos = snap.data ?? const [];
            if (pos.isEmpty) {
              return const LotMessage(
                icon: Icons.inbox_outlined,
                title: 'Geen inkooporders',
                detail: 'Er zijn geen inkooporders gevonden.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _PoCard(po: pos[i]),
            );
          },
        ),
      ),
    );
  }
}

class _PoCard extends StatelessWidget {
  const _PoCard({required this.po});
  final MarelloPurchaseOrder po;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: WelhofColors.brand.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2,
                  color: WelhofColors.brand, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    po.poNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: WelhofColors.ink,
                    ),
                  ),
                  if (po.supplierName != null &&
                      po.supplierName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      po.supplierName!,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            if (po.orderTotal != null)
              Text(
                '€${po.orderTotal!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: WelhofColors.ink,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
