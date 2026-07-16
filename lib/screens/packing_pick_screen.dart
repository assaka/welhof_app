import 'package:flutter/material.dart';

import '../models/marello_pick.dart';
import '../services/marello_service.dart';
import '../theme.dart';
import 'lot_common.dart';
import 'pick_scanner_screen.dart';

/// Picks a single Marello packing slip. Each item is scanned unit-by-unit (a
/// qty-3 SKU is scanned three times), then a dock is appointed and the row
/// Sorted. When every item is fully picked the slip shows **Completed**. All
/// state is written to Marello's packing slip via the pick endpoint.
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
  final Map<int, String> _pendingDock = {};

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

  Future<ScanResult> _scan(String barcode) async {
    final r = await _service.scanPickSlip(widget.slipId, barcode);
    if (r.slip != null && mounted) setState(() => _slip = r.slip);
    return r;
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PickScannerScreen(onScan: _scan),
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
      floatingActionButton: (slip != null && !slip.completed)
          ? FloatingActionButton.extended(
              onPressed: _openScanner,
              backgroundColor: WelhofColors.accent,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scannen'),
            )
          : null,
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
                                  pendingDock:
                                      _pendingDock[item.id] ?? _docks.first,
                                  onDockChanged: (v) => setState(
                                      () => _pendingDock[item.id] = v),
                                  onSort: () => _run(() => _service.sortPickItem(
                                      item.id,
                                      _pendingDock[item.id] ?? _docks.first)),
                                  onUnsort: () => _run(
                                      () => _service.sortPickItem(item.id, '')),
                                  onPick: () => _run(
                                      () => _service.pickItemUnit(item.id)),
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
    required this.pendingDock,
    required this.onDockChanged,
    required this.onSort,
    required this.onUnsort,
    required this.onPick,
    required this.onReset,
  });

  final PickItem item;
  final String? imageUrl;
  final String pendingDock;
  final ValueChanged<String> onDockChanged;
  final VoidCallback onSort;
  final VoidCallback onUnsort;
  final VoidCallback onPick;
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
              complete: complete,
              sorted: sorted,
              dock: item.sortDock,
              pendingDock: pendingDock,
              onDockChanged: onDockChanged,
              onSort: onSort,
              onUnsort: onUnsort,
              onPick: onPick,
            ),
          ],
        ),
      ),
    );
  }
}

/// Right-hand action cell: manual Pick while unfinished → dock dropdown + Sort
/// once fully picked → DOCK badge once sorted.
class _RightCell extends StatelessWidget {
  const _RightCell({
    required this.complete,
    required this.sorted,
    required this.dock,
    required this.pendingDock,
    required this.onDockChanged,
    required this.onSort,
    required this.onUnsort,
    required this.onPick,
  });

  final bool complete;
  final bool sorted;
  final String? dock;
  final String pendingDock;
  final ValueChanged<String> onDockChanged;
  final VoidCallback onSort;
  final VoidCallback onUnsort;
  final VoidCallback onPick;

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
    if (complete) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: WelhofColors.accent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: pendingDock,
                isDense: true,
                isExpanded: true,
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
          const SizedBox(height: 4),
          FilledButton(
            onPressed: onSort,
            style: FilledButton.styleFrom(
              backgroundColor: WelhofColors.accent,
              minimumSize: const Size(64, 30),
              padding: EdgeInsets.zero,
            ),
            child: const Text('Sort'),
          ),
        ],
      );
    }
    // Not fully picked: manual +1 fallback (scanning is preferred).
    return OutlinedButton(
      onPressed: onPick,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 40),
        padding: EdgeInsets.zero,
      ),
      child: const Text('+1'),
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
