import 'package:flutter/material.dart';

import '../models/marello_order.dart';
import '../theme.dart';

/// Picking detail for a single order: header (order no. / customer / date)
/// plus one row per line item. Each row can be marked Picked / Sorted and
/// expanded to a Details panel (image, grade, category, notes, actions).
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order});

  final MarelloOrder order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

enum _Pick { pending, picked, sorted }

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  // Per-item picking state and which row is expanded (-1 = none).
  late final List<_Pick> _state =
      List<_Pick>.filled(widget.order.items.length, _Pick.pending);
  int _expanded = -1;

  void _cyclePick(int i) {
    setState(() {
      _state[i] = switch (_state[i]) {
        _Pick.pending => _Pick.picked,
        _Pick.picked => _Pick.sorted,
        _Pick.sorted => _Pick.pending,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      appBar: AppBar(title: Text(order.orderNumber)),
      body: Column(
        children: [
          _Header(order: order),
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
                    itemBuilder: (_, i) => _ItemRow(
                      item: order.items[i],
                      state: _state[i],
                      expanded: _expanded == i,
                      customerNote: order.customerName,
                      onPick: () => _cyclePick(i),
                      onToggleExpand: () =>
                          setState(() => _expanded = _expanded == i ? -1 : i),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order});
  final MarelloOrder order;

  @override
  Widget build(BuildContext context) {
    final bits = <String>[
      if (order.customerName != null) order.customerName!,
      if (order.orderDate != null) _fmtDate(order.orderDate!),
    ];
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
              Text(
                '${order.itemCount} artikel(en)',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          if (bits.isNotEmpty) ...[
            const SizedBox(height: 4),
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

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.state,
    required this.expanded,
    required this.onPick,
    required this.onToggleExpand,
    this.customerNote,
  });

  final MarelloOrderItem item;
  final _Pick state;
  final bool expanded;
  final VoidCallback onPick;
  final VoidCallback onToggleExpand;
  final String? customerNote;

  @override
  Widget build(BuildContext context) {
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
                  OutlinedButton(
                    onPressed: onPick,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(56, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Pick'),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      _StatusPill('Picked',
                          on: state == _Pick.picked || state == _Pick.sorted),
                      const SizedBox(height: 4),
                      _StatusPill('Sorted', on: state == _Pick.sorted),
                    ],
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.black26),
                ],
              ),
            ),
          ),
          if (expanded) _DetailsPanel(customerNote: customerNote),
        ],
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
      width: 56,
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

/// Inline "Details" panel mirroring the picking-detail mockup. The metadata
/// fields (image, grade, category, order link) aren't in the order payload,
/// so they render as labelled affordances; the customer note uses live data.
class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({this.customerNote});
  final String? customerNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Details',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: WelhofColors.ink)),
            ],
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _MetaLink('Image', Icons.image_outlined),
              _MetaLink('Grade', Icons.grade_outlined),
              _MetaLink('Category', Icons.category_outlined),
              _MetaLink('Note', Icons.sticky_note_2_outlined),
              _MetaLink('Orderlink', Icons.link),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Klantnotitie: ${customerNote != null && customerNote!.isNotEmpty ? customerNote! : '—'}',
            style: const TextStyle(color: Colors.black54, fontSize: 13),
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

class _MetaLink extends StatelessWidget {
  const _MetaLink(this.label, this.icon);
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => InkWell(
        onTap: () => _todo(context, label),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: WelhofColors.brand),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: WelhofColors.brand,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
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
      onTap: () => _todo(context, label),
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

void _todo(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label — nog niet gekoppeld'), duration: const Duration(seconds: 1)),
  );
}
