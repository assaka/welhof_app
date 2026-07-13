import 'package:flutter/material.dart';

import '../models/marello_order.dart';
import '../services/marello_service.dart';
import '../theme.dart';
import 'order_detail_screen.dart';

/// Fetches orders from Marello and renders them, with loading / error / empty
/// states and pull-to-refresh. Used by the Order Picking "All" tab.
class OrdersListView extends StatefulWidget {
  const OrdersListView({super.key, this.status});

  /// Optional order-status label to filter by (null = all orders).
  final String? status;

  @override
  State<OrdersListView> createState() => _OrdersListViewState();
}

class _OrdersListViewState extends State<OrdersListView> {
  late final MarelloService _service =
      MarelloService(config: MarelloConfig.fromEnvironment());
  late Future<List<MarelloOrder>> _future = _load();

  Future<List<MarelloOrder>> _load() =>
      _service.fetchOrders(status: widget.status);

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await f.catchError((_) => <MarelloOrder>[]);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<MarelloOrder>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _MessageState(
              icon: Icons.cloud_off,
              title: 'Bestellingen laden mislukt',
              detail: '${snap.error}',
              onRetry: _refresh,
              scrollable: true,
            );
          }
          final orders = snap.data ?? const [];
          if (orders.isEmpty) {
            return const _MessageState(
              icon: Icons.inbox_outlined,
              title: 'Geen bestellingen',
              detail: 'Er zijn geen bestellingen gevonden.',
              scrollable: true,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _OrderCard(order: orders[i]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final MarelloOrder order;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (order.customerName != null) order.customerName!,
      if (order.orderDate != null) _date(order.orderDate!),
      '${order.itemCount} artikel(en)',
    ].join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
        ),
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
                child: const Icon(Icons.receipt_long,
                    color: WelhofColors.brand, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: WelhofColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _money(order.grandTotal, order.currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: WelhofColors.ink,
                    ),
                  ),
                  if (order.status != null) ...[
                    const SizedBox(height: 6),
                    _StatusChip(order.status!),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime d) {
    final l = d.toLocal();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(l.day)}/${p(l.month)}/${l.year} ${p(l.hour)}:${p(l.minute)}';
  }

  static String _money(double v, String currency) {
    final symbol = switch (currency.toUpperCase()) {
      'EUR' => '€',
      'USD' => '\$',
      'GBP' => '£',
      _ => currency.isEmpty ? '' : '$currency ',
    };
    return '$symbol${v.toStringAsFixed(2)}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: WelhofColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: WelhofColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Full-height centered message (error / empty) that still scrolls, so
/// pull-to-refresh works even when there's no list.
class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
    this.scrollable = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: Colors.black26),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: WelhofColors.ink)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Opnieuw proberen'),
          ),
        ],
      ],
    );

    if (!scrollable) return Center(child: content);
    return LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: content),
        ),
      ),
    );
  }
}
