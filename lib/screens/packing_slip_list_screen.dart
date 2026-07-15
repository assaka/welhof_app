import 'package:flutter/material.dart';

import '../models/marello_docs.dart';
import '../services/marello_service.dart';
import '../theme.dart';
import 'lot_common.dart';

/// Marello packing slips (the "Paklijsten" menu item).
class PackingSlipListScreen extends StatefulWidget {
  const PackingSlipListScreen({super.key});

  @override
  State<PackingSlipListScreen> createState() => _PackingSlipListScreenState();
}

class _PackingSlipListScreenState extends State<PackingSlipListScreen> {
  late final MarelloService _service =
      MarelloService(config: MarelloConfig.fromEnvironment());
  late Future<List<MarelloPackingSlip>> _future = _service.fetchPackingSlips();

  Future<void> _refresh() async {
    final f = _service.fetchPackingSlips();
    setState(() => _future = f);
    await f.catchError((_) => <MarelloPackingSlip>[]);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paklijsten')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MarelloPackingSlip>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return LotMessage(
                icon: Icons.cloud_off,
                title: 'Paklijsten laden mislukt',
                detail: '${snap.error}',
                onRetry: _refresh,
              );
            }
            final slips = snap.data ?? const [];
            if (slips.isEmpty) {
              return const LotMessage(
                icon: Icons.inbox_outlined,
                title: 'Geen paklijsten',
                detail: 'Er zijn geen paklijsten gevonden.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: slips.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _SlipCard(slip: slips[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SlipCard extends StatelessWidget {
  const _SlipCard({required this.slip});
  final MarelloPackingSlip slip;

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
              child: const Icon(Icons.receipt_long,
                  color: WelhofColors.brand, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                slip.number,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: WelhofColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
