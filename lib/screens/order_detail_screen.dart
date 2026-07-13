import 'package:flutter/material.dart';

import '../models/marello_order.dart';
import '../services/marello_service.dart';
import '../services/pick_progress.dart';
import '../theme.dart';

/// Picking detail for a single order. Per-row flow:
///  1. While a row isn't fully picked it shows its **warehouse pick location**
///     and a `Pick` button; every unit must be picked (counter `x/qty`).
///  2. Once fully picked the row shows **Picked** plus a **dock dropdown**;
///     choosing a dock and pressing **Sort** stages the row at that dock.
///  3. After sorting the row shows its **DOCK** and is marked **Sorted**.
/// Order-level status (list + header) rolls these up. State is shared via
/// [PickProgress] and persisted on-device (not written back to Marello).
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order});

  final MarelloOrder order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

/// Shipment docks a picked row can be staged at.
const _docks = <String>['A1', 'A2', 'A3', 'B1', 'B2', 'B3', 'C1', 'C2'];

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final MarelloConfig _cfg = MarelloConfig.fromEnvironment();
  final PickProgress _progress = PickProgress.instance;
  int _expanded = -1;
  // Per-row dock selection pending confirmation via the row's Sort button.
  final Map<String, String> _pendingDock = {};

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final lineCount = order.items.length;
    return Scaffold(
      appBar: AppBar(title: Text(order.orderNumber)),
      body: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final total = order.itemCount; // total units (sum of quantities)
          final picked = _progress.pickedUnits(order.id);
          final allSorted = _progress.allSorted(order.id, lineCount);

          return Column(
            children: [
              _Header(
                order: order,
                picked: picked,
                total: total,
                sortedLocations: allSorted
                    ? _progress.sortedLocations(order.id)
                    : const [],
              ),
              const Divider(height: 1),
              Expanded(
                child: order.items.isEmpty
                    ? const Center(
                        child: Text('Geen artikelen in deze bestelling.',
                            style: TextStyle(color: Colors.black54)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: order.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final item = order.items[i];
                          return _ItemRow(
                            item: item,
                            imageUrl: item.hasImage
                                ? _cfg.imageUrlFor(item.productSku)
                                : null,
                            pickLocation: item.pickLocation ??
                                _pickLocation(item.productSku),
                            pickedQty: _progress.pickedQty(order.id, item.id),
                            sortedDock:
                                _progress.itemLocation(order.id, item.id),
                            pendingDock: _pendingDock[item.id] ?? _docks.first,
                            expanded: _expanded == i,
                            customerNote: order.customerName,
                            onPick: () => _progress.bumpPick(
                                order.id, item.id, item.quantity),
                            onDockChanged: (v) =>
                                setState(() => _pendingDock[item.id] = v),
                            onSort: () => _progress.sortItem(order.id, item.id,
                                _pendingDock[item.id] ?? _docks.first),
                            onUnsort: () =>
                                _progress.unsortItem(order.id, item.id),
                            onToggleExpand: () => setState(
                                () => _expanded = _expanded == i ? -1 : i),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Deterministic placeholder pick location (Marello has no bin data on this
  /// instance): a stable aisle+bin derived from the SKU, e.g. "A12".
  static String _pickLocation(String sku) {
    var h = 0;
    for (final c in sku.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final aisle = String.fromCharCode('A'.codeUnitAt(0) + (h % 4)); // A–D
    final bin = (h ~/ 4) % 30 + 1; // 1–30
    return '$aisle${bin.toString().padLeft(2, '0')}';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.order,
    required this.picked,
    required this.total,
    required this.sortedLocations,
  });

  final MarelloOrder order;
  final int picked;
  final int total;

  /// Non-empty only when every row is sorted; the distinct dock locations.
  final List<String> sortedLocations;

  @override
  Widget build(BuildContext context) {
    final bits = <String>[
      if (order.customerName != null) order.customerName!,
      if (order.orderDate != null) _fmtDate(order.orderDate!),
    ];
    final allPicked = total > 0 && picked >= total;

    Widget badge;
    if (sortedLocations.isNotEmpty) {
      badge = _Badge('Sorted • ${sortedLocations.join(', ')}',
          const Color(0xFF39D353));
    } else if (allPicked) {
      badge = const _Badge('Picked', Color(0xFF39D353));
    } else {
      badge = _Badge('$picked/$total picked', Colors.white24);
    }

    return Container(
      width: double.infinity,
      color: WelhofColors.brand,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
              badge,
            ],
          ),
          if (bits.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(bits.join('  ·  '),
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    final l = d.toLocal();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(l.day)}/${p(l.month)}/${l.year} ${p(l.hour)}:${p(l.minute)}';
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.imageUrl,
    required this.pickLocation,
    required this.pickedQty,
    required this.sortedDock,
    required this.pendingDock,
    required this.expanded,
    required this.onPick,
    required this.onDockChanged,
    required this.onSort,
    required this.onUnsort,
    required this.onToggleExpand,
    this.customerNote,
  });

  final MarelloOrderItem item;
  final String? imageUrl;
  final String pickLocation;
  final int pickedQty;
  final String? sortedDock; // dock if sorted, else null
  final String pendingDock;
  final bool expanded;
  final VoidCallback onPick;
  final ValueChanged<String> onDockChanged;
  final VoidCallback onSort;
  final VoidCallback onUnsort;
  final VoidCallback onToggleExpand;
  final String? customerNote;

  @override
  Widget build(BuildContext context) {
    final complete = pickedQty >= item.quantity;
    final sorted = sortedDock != null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumb(imageUrl: imageUrl, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName.isEmpty
                            ? item.productSku
                            : item.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: WelhofColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text('${item.productSku}  ·  Grade: ${item.grade ?? '—'}',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12)),
                      InkWell(
                        onTap: onToggleExpand,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Details',
                                  style: TextStyle(
                                      color: WelhofColors.brand,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              Icon(
                                  expanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 16,
                                  color: WelhofColors.brand),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Location cell: warehouse (picking) → dock dropdown (picked)
                // → dock (sorted).
                _LocationCell(
                  complete: complete,
                  sortedDock: sortedDock,
                  pickLocation: pickLocation,
                  pendingDock: pendingDock,
                  onDockChanged: onDockChanged,
                ),
                const SizedBox(width: 10),
                // Counter + action (Pick / Sort) + status.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$pickedQty/${item.quantity}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: complete
                                ? const Color(0xFF2AA745)
                                : Colors.black54)),
                    const SizedBox(height: 4),
                    if (!complete)
                      OutlinedButton(
                        onPressed: onPick,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(58, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('Pick'),
                      )
                    else if (!sorted) ...[
                      const _Tag('Picked', Color(0xFF39D353)),
                      const SizedBox(height: 4),
                      FilledButton(
                        onPressed: onSort,
                        style: FilledButton.styleFrom(
                          backgroundColor: WelhofColors.accent,
                          minimumSize: const Size(58, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Sort'),
                      ),
                    ] else ...[
                      const _Tag('Picked', Color(0xFF39D353)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: onUnsort,
                        child: const _Tag('Sorted', Color(0xFF2AA745)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (expanded)
            _DetailsPanel(
                item: item, imageUrl: imageUrl, customerNote: customerNote),
        ],
      ),
    );
  }
}

/// State-dependent location cell.
class _LocationCell extends StatelessWidget {
  const _LocationCell({
    required this.complete,
    required this.sortedDock,
    required this.pickLocation,
    required this.pendingDock,
    required this.onDockChanged,
  });

  final bool complete;
  final String? sortedDock;
  final String pickLocation;
  final String pendingDock;
  final ValueChanged<String> onDockChanged;

  @override
  Widget build(BuildContext context) {
    if (sortedDock != null) {
      return _Box(
        color: const Color(0xFFE9FBEF),
        border: const Color(0xFF39D353),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('DOCK',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2AA745))),
            Text(sortedDock!,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E7A34))),
          ],
        ),
      );
    }
    if (complete) {
      // Dock dropdown to choose the shipment dock.
      return _Box(
        color: Colors.white,
        border: WelhofColors.accent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('DOCK',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45)),
            SizedBox(
              height: 22,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: pendingDock,
                  isDense: true,
                  iconSize: 18,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: WelhofColors.ink),
                  onChanged: (v) => onDockChanged(v ?? pendingDock),
                  items: [
                    for (final d in _docks)
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    // Warehouse pick location.
    return _Box(
      color: const Color(0xFFF4F6F9),
      border: const Color(0xFFDDE1E6),
      child: Text(pickLocation,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: WelhofColors.ink)),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.color, required this.border, required this.child});
  final Color color;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl, required this.size});
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: WelhofColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.inventory_2_outlined,
          color: WelhofColors.brand, size: 22),
    );
    if (imageUrl == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
      ),
    );
  }
}

/// Inline "Details" panel: real product image, grade and category, the
/// customer note, plus the mockup's action affordances (not yet wired).
class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.item,
    required this.imageUrl,
    this.customerNote,
  });

  final MarelloOrderItem item;
  final String? imageUrl;
  final String? customerNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(imageUrl: imageUrl, size: 84),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetaRow('Grade', item.grade ?? '—'),
                    _MetaRow('Category', item.category ?? '—'),
                    _MetaRow('SKU', item.productSku),
                    _MetaRow(
                        'Klantnotitie',
                        (customerNote?.isNotEmpty ?? false)
                            ? customerNote!
                            : '—'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _ActionLink('Defect'),
              _ActionLink('Untraceable'),
              _ActionLink('Wrong input'),
              _ActionLink('Restore'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(
                    color: Colors.black54, fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  const _ActionLink(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$label — nog niet gekoppeld'),
            duration: const Duration(seconds: 1)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: WelhofColors.accent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
