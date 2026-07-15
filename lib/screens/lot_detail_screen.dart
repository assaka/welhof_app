import 'package:flutter/material.dart';

import '../models/marello_lot.dart';
import '../services/marello_service.dart';
import '../theme.dart';
import 'lot_capture_screen.dart';
import 'lot_common.dart';

/// Items of a lot. Tap an item to capture it (barcode + photo + qty + location).
class LotDetailScreen extends StatefulWidget {
  const LotDetailScreen({super.key, required this.lot});
  final MarelloLot lot;

  @override
  State<LotDetailScreen> createState() => _LotDetailScreenState();
}

class _LotDetailScreenState extends State<LotDetailScreen> {
  late final MarelloService _service =
      MarelloService(config: MarelloConfig.fromEnvironment());
  late Future<List<MarelloLotItem>> _future = _service.fetchLotItems(widget.lot.id);

  Future<void> _refresh() async {
    final f = _service.fetchLotItems(widget.lot.id);
    setState(() => _future = f);
    await f.catchError((_) => <MarelloLotItem>[]);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _openCapture(MarelloLotItem item) async {
    final updated = await Navigator.of(context).push<MarelloLotItem>(
      MaterialPageRoute(builder: (_) => LotCaptureScreen(item: item)),
    );
    if (updated != null) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.lot.lotNumber)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MarelloLotItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return LotMessage(
                icon: Icons.cloud_off,
                title: 'Items laden mislukt',
                detail: '${snap.error}',
                onRetry: _refresh,
              );
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return const LotMessage(
                icon: Icons.inbox_outlined,
                title: 'Geen items',
                detail: 'Dit lot heeft geen items.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ItemCard(
                item: items[i],
                onTap: () => _openCapture(items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});
  final MarelloLotItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      '${item.quantity} st.',
      if (item.barcode != null && item.barcode!.isNotEmpty) item.barcode!,
      if (item.pickLocation != null && item.pickLocation!.isNotEmpty)
        item.pickLocation!,
    ].join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Thumb(item: item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.isEmpty ? item.tempCode : item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: WelhofColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.tempCode} · $meta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              LotStatusChip(item.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item});
  final MarelloLotItem item;

  @override
  Widget build(BuildContext context) {
    final base = MarelloConfig.fromEnvironment().baseUrl;
    if (item.photoUrl != null && item.photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          '$base${item.photoUrl}',
          height: 46,
          width: 46,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: WelhofColors.brand.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.qr_code_2, color: WelhofColors.brand, size: 22),
      );
}
