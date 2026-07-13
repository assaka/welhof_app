import 'package:flutter/material.dart';

import '../models/marello_order.dart';
import '../services/marello_service.dart';
import '../services/pick_progress.dart';
import '../theme.dart';

/// Picking detail for a single order. Workflow:
///  1. Pick each line item unit-by-unit (a line of quantity 2 needs 2 picks)
///     → header counter `X/N picked` where N is the total number of units.
///  2. Once a row is fully picked its **Pick** button becomes a **Sort**
///     button; pressing it stages that row at the location chosen in the bar.
///  3. When every row is sorted the order is **Sorted**.
/// Each row expands to a Details panel with the product image, grade, category
/// and notes. State is shared via [PickProgress] so the order list reflects it.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order});

  final MarelloOrder order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

const _locations = <String>['A1', 'B1', 'B2', 'C1'];

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final MarelloConfig _cfg = MarelloConfig.fromEnvironment();
  final PickProgress _progress = PickProgress.instance;
  int _expanded = -1;
  String _pendingLocation = _locations.first;

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
          final anyToSort = order.items.any((it) =>
              _progress.isItemComplete(order.id, it.id, it.quantity) &&
              !_progress.isItemSorted(order.id, it.id));

          return Column(
            children: [
              _Header(
                order: order,
                picked: picked,
                total: total,
                sortedLocations:
                    allSorted ? _progress.sortedLocations(order.id) : const [],
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
                            pickedQty: _progress.pickedQty(order.id, item.id),
                            location:
                                _progress.itemLocation(order.id, item.id),
                            expanded: _expanded == i,
                            customerNote: order.customerName,
                            onPick: () => _progress.bumpPick(
                                order.id, item.id, item.quantity),
                            onSort: () => _progress.sortItem(
                                order.id, item.id, _pendingLocation),
                            onUnsort: () =>
                                _progress.unsortItem(order.id, item.id),
                            onToggleExpand: () => setState(
                                () => _expanded = _expanded == i ? -1 : i),
                          );
                        },
                      ),
              ),
              _SortBar(
                allSorted: allSorted,
                anyToSort: anyToSort,
                selected: _pendingLocation,
                onSelect: (v) => setState(() => _pendingLocation = v),
                onSortAll: () {
                  for (final it in order.items) {
                    if (_progress.isItemComplete(order.id, it.id, it.quantity) &&
                        !_progress.isItemSorted(order.id, it.id)) {
                      _progress.sortItem(order.id, it.id, _pendingLocation);
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
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

  /// Non-empty only when every row is sorted; the distinct staging locations.
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
    required this.pickedQty,
    required this.location,
    required this.expanded,
    required this.onPick,
    required this.onSort,
    required this.onUnsort,
    required this.onToggleExpand,
    this.customerNote,
  });

  final MarelloOrderItem item;
  final String? imageUrl;
  final int pickedQty;
  final String? location; // sorted location, or null
  final bool expanded;
  final VoidCallback onPick;
  final VoidCallback onSort;
  final VoidCallback onUnsort;
  final VoidCallback onToggleExpand;
  final String? customerNote;

  @override
  Widget build(BuildContext context) {
    final complete = pickedQty >= item.quantity;
    final sorted = location != null;

    // Action button: Pick (while picking) → Sort (when picked) → location chip.
    Widget action;
    if (sorted) {
      action = OutlinedButton(
        onPressed: onUnsort,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(60, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: const Color(0xFF2AA745),
          side: const BorderSide(color: Color(0xFF39D353)),
        ),
        child: Text(location!),
      );
    } else if (complete) {
      action = FilledButton(
        onPressed: onSort,
        style: FilledButton.styleFrom(
          backgroundColor: WelhofColors.accent,
          minimumSize: const Size(60, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: const Text('Sort'),
      );
    } else {
      action = OutlinedButton(
        onPressed: onPick,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(60, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: const Text('Pick'),
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggleExpand,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
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
                        Text(
                          '${item.productSku}   ·   ${item.quantity}×',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$pickedQty/${item.quantity}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: complete
                              ? const Color(0xFF2AA745)
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      action,
                    ],
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      _StatusPill('Picked', on: complete),
                      const SizedBox(height: 4),
                      _StatusPill('Sorted', on: sorted),
                    ],
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.black26),
                ],
              ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label, {required this.on});
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: on ? const Color(0xFF39D353) : const Color(0xFFEDEFF2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: on ? Colors.white : Colors.black45,
        ),
      ),
    );
  }
}

/// Bottom bar for the Sort step: a location dropdown that per-row Sort buttons
/// use, plus a "Sorteer alles" shortcut for the remaining picked rows.
class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.allSorted,
    required this.anyToSort,
    required this.selected,
    required this.onSelect,
    required this.onSortAll,
  });

  final bool allSorted;
  final bool anyToSort;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onSortAll;

  @override
  Widget build(BuildContext context) {
    if (allSorted) {
      return Material(
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          color: const Color(0xFFE9FBEF),
          child: const SafeArea(
            top: false,
            child: Row(
              children: [
                Icon(Icons.local_shipping, color: Color(0xFF2AA745), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Alle rijen gesorteerd — klaar voor verzending',
                    style: TextStyle(
                        color: Color(0xFF1E7A34), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Locatie',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selected,
                      isExpanded: true,
                      onChanged: (v) => onSelect(v ?? selected),
                      items: [
                        for (final loc in _locations)
                          DropdownMenuItem(value: loc, child: Text(loc)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: anyToSort ? onSortAll : null,
                icon: const Icon(Icons.sort),
                label: const Text('Sorteer alles'),
                style: FilledButton.styleFrom(
                  backgroundColor: WelhofColors.accent,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Details',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: WelhofColors.ink)),
          const SizedBox(height: 10),
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
