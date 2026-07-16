import 'package:flutter/material.dart';

import '../models/marello_pick.dart';
import '../services/marello_service.dart';
import '../theme.dart';
import 'lot_common.dart';
import 'packing_pick_screen.dart';

/// Marello packing slips (the "Paklijsten" menu item) — the pick queue. Each
/// slip shows its pick progress; tapping one opens the scan-to-pick screen.
class PackingSlipListScreen extends StatefulWidget {
  const PackingSlipListScreen({super.key});

  @override
  State<PackingSlipListScreen> createState() => _PackingSlipListScreenState();
}

class _PackingSlipListScreenState extends State<PackingSlipListScreen> {
  late final MarelloService _service =
      MarelloService(config: MarelloConfig.fromEnvironment());
  late Future<List<PickSlip>> _future = _service.fetchPackingSlips();

  Future<void> _refresh() async {
    final f = _service.fetchPackingSlips();
    setState(() => _future = f);
    await f.catchError((_) => <PickSlip>[]);
  }

  Future<void> _openSlip(PickSlip slip) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PackingPickScreen(
          slipId: slip.id,
          slipNumber: slip.number,
          orderNumber: slip.orderNumber,
        ),
      ),
    );
    _refresh(); // progress may have changed
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
        child: FutureBuilder<List<PickSlip>>(
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
              itemBuilder: (_, i) =>
                  _SlipCard(slip: slips[i], onTap: () => _openSlip(slips[i])),
            );
          },
        ),
      ),
    );
  }
}

class _SlipCard extends StatelessWidget {
  const _SlipCard({required this.slip, required this.onTap});
  final PickSlip slip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slip.number,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: WelhofColors.ink)),
                    if (slip.orderNumber != null) ...[
                      const SizedBox(height: 2),
                      Text(slip.orderNumber!,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              _StatusPill(slip: slip),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.slip});
  final PickSlip slip;

  @override
  Widget build(BuildContext context) {
    final completed = slip.completed;
    final label =
        completed ? 'Completed' : '${slip.pickedItemCount}/${slip.itemCount}';
    final color =
        completed ? const Color(0xFF2AA745) : WelhofColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: completed ? 1 : 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: completed ? Colors.white : color)),
    );
  }
}
