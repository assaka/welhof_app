import 'package:flutter/material.dart';

import '../models/marello_pick.dart';
import '../services/marello_service.dart';
import '../theme.dart';
import 'lot_common.dart';
import 'pick_item_scan_screen.dart';

/// Picks a single Marello packing slip. Each row is scanned on its own: tapping
/// **Scan** opens the per-row scanner, where the line's units are scanned (a
/// qty-3 SKU is scanned three times), a dock is appointed once every unit is in,
/// and the pick is confirmed. Cancelling a scan writes nothing. When every item
/// is fully picked the slip shows **Completed**. All state lives on Marello's
/// packing slip via the pick endpoint.
class PackingPickScreen extends StatefulWidget {
  const PackingPickScreen({
    super.key,
    required this.slipId,
    required this.slipNumber,
    this.orderNumber,
  });

  final int slipId;
  final String slipNumber;
  final String? orderNumber;

  @override
  State<PackingPickScreen> createState() => _PackingPickScreenState();
}

/// Shipment docks a picked row can be staged at.
const _docks = <String>['A1', 'A2', 'A3', 'B1', 'B2', 'B3', 'C1', 'C2'];

class _PackingPickScreenState extends State<PackingPickScreen> {
  final MarelloService _service =
      MarelloService(config: MarelloConfig.fromEnvironment());
  PickSlip? _slip;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slip = await _service.fetchPickSlip(widget.slipId);
      if (mounted) setState(() => _slip = slip);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanRow(PickItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PickItemScanScreen(
          item: item,
          docks: _docks,
          onVerify: (barcode) => _service.verifyPickItem(item.id, barcode),
          onCommit: (pickedQty, dock) async {
            final slip = await _service.commitPickItem(item.id, pickedQty, dock);
            if (mounted) setState(() => _slip = slip);
          },
        ),
      ),
    );
    await _load(); // reconcile after the scanning session
  }

  Future<void> _run(Future<PickSlip> Function() action) async {
    try {
      final slip = await action();
      if (mounted) setState(() => _slip = slip);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mislukt: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slip = _slip;
    return Scaffold(
      appBar: AppBar(title: Text('Paklijst ${widget.slipNumber}')),
      body: _loading && slip == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? LotMessage(
                  icon: Icons.cloud_off,
                  title: 'Paklijst laden mislukt',
                  detail: '$_error',
                  onRetry: _load,
                )
              : slip == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        _Header(slip: slip),
                        const Divider(height: 1),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: slip.items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final item = slip.items[i];
                                return _ItemRow(
                                  item: item,
                                  imageUrl:
                                      _service.config.imageUrlFor(item.productSku),
                                  onScan: () => _scanRow(item),
                                  onUnsort: () => _run(
                                      () => _service.sortPickItem(item.id, '')),
                                  onReset: () => _run(
                                      () => _service.resetPickItem(item.id)),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.slip});
  final PickSlip slip;

  @override
  Widget build(BuildContext context) {
    Widget badge;
    if (slip.completed) {
      badge = const _Badge('Completed', Color(0xFF2AA745));
    } else {
      badge = _Badge('${slip.pickedItemCount}/${slip.itemCount} gepickt',
          Colors.white24);
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
                child: Text('Paklijst ${slip.number}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              badge,
            ],
          ),
          if (slip.orderNumber != null) ...[
            const SizedBox(height: 6),
            Text('Bestelling ${slip.orderNumber}',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ],
      ),
    );
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
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
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
    required this.onScan,
    required this.onUnsort,
    required this.onReset,
  });

  final PickItem item;
  final String? imageUrl;
  final VoidCallback onScan;
  final VoidCallback onUnsort;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final complete = item.complete;
    final sorted = item.sorted;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(imageUrl: imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName.isEmpty ? item.productSku : item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: WelhofColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(item.productSku,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12)),
                  if (item.pickLocation != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 14, color: WelhofColors.brand),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text('Loc ${item.pickLocation}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: WelhofColors.brand,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Unit progress bar.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.quantity == 0
                          ? 0
                          : item.pickedQty / item.quantity,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE9ECEF),
                      color: complete
                          ? const Color(0xFF2AA745)
                          : WelhofColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('${item.pickedQty}/${item.quantity} gepickt',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: complete
                                  ? const Color(0xFF2AA745)
                                  : Colors.black54)),
                      const Spacer(),
                      if (item.pickedQty > 0)
                        GestureDetector(
                          onTap: onReset,
                          child: const Text('reset',
                              style: TextStyle(
                                  color: Colors.black38,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _RightCell(
              sorted: sorted,
              dock: item.sortDock,
              onScan: onScan,
              onUnsort: onUnsort,
            ),
          ],
        ),
      ),
    );
  }
}

/// Right-hand action cell: a **Scan** button until the row is sorted, then a
/// DOCK badge (tap to release the dock and re-scan/re-dock).
class _RightCell extends StatelessWidget {
  const _RightCell({
    required this.sorted,
    required this.dock,
    required this.onScan,
    required this.onUnsort,
  });

  final bool sorted;
  final String? dock;
  final VoidCallback onScan;
  final VoidCallback onUnsort;

  @override
  Widget build(BuildContext context) {
    if (sorted) {
      return GestureDetector(
        onTap: onUnsort,
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE9FBEF),
            border: Border.all(color: const Color(0xFF39D353)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('DOCK',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2AA745))),
              Text(dock ?? '',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E7A34))),
            ],
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onScan,
      icon: const Icon(Icons.qr_code_scanner, size: 18),
      label: const Text('Scan'),
      style: OutlinedButton.styleFrom(
        foregroundColor: WelhofColors.accent,
        side: const BorderSide(color: WelhofColors.accent),
        minimumSize: const Size(84, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = 46.0;
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
      child: Image.network(imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : placeholder),
    );
  }
}
