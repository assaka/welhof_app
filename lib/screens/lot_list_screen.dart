import 'package:flutter/material.dart';

import '../models/marello_lot.dart';
import '../services/marello_service.dart';
import '../theme.dart';
import 'lot_common.dart';
import 'lot_detail_screen.dart';

/// Returns/overstock lots to process on the floor. Tap one to see its items.
class LotListScreen extends StatefulWidget {
  const LotListScreen({super.key});

  @override
  State<LotListScreen> createState() => _LotListScreenState();
}

class _LotListScreenState extends State<LotListScreen> {
  late final MarelloService _service =
      MarelloService(config: MarelloConfig.fromEnvironment());
  late Future<List<MarelloLot>> _future = _service.fetchLots();

  Future<void> _refresh() async {
    final f = _service.fetchLots();
    setState(() => _future = f);
    await f.catchError((_) => <MarelloLot>[]);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Retouren')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MarelloLot>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return LotMessage(
                icon: Icons.cloud_off,
                title: 'Lots laden mislukt',
                detail: '${snap.error}',
                onRetry: _refresh,
              );
            }
            final lots = snap.data ?? const [];
            if (lots.isEmpty) {
              return const LotMessage(
                icon: Icons.inbox_outlined,
                title: 'Geen lots',
                detail: 'Er zijn geen retour-/overstocklots gevonden.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _LotCard(
                lot: lots[i],
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LotDetailScreen(lot: lots[i]),
                  ));
                  _refresh();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  const _LotCard({required this.lot, required this.onTap});
  final MarelloLot lot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (lot.condition != null && lot.condition!.isNotEmpty) lot.condition!,
      if (lot.createdAt != null) _date(lot.createdAt!),
    ].join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
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
                      lot.lotNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: WelhofColors.ink,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              LotStatusChip(lot.status ?? 'new'),
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime d) {
    final l = d.toLocal();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(l.day)}/${p(l.month)}/${l.year}';
  }
}
