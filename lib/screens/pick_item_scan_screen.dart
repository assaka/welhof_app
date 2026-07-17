import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/marello_pick.dart';
import '../theme.dart';

/// Per-row pick scanner. Scans one line's units, staged on the device: each scan
/// is VERIFIED against this item (no server write), counting up to its quantity.
/// The dock chooser only appears once **every** unit is scanned; the pick is
/// COMMITTED (units + dock) only on Confirm. Cancelling writes nothing.
class PickItemScanScreen extends StatefulWidget {
  const PickItemScanScreen({
    super.key,
    required this.item,
    required this.docks,
    required this.onVerify,
    required this.onCommit,
  });

  final PickItem item;
  final List<String> docks;

  /// Verifies a scanned barcode belongs to this item (no commit).
  final Future<VerifyResult> Function(String barcode) onVerify;

  /// Commits the full pick: [pickedQty] units staged at [dock].
  final Future<void> Function(int pickedQty, String dock) onCommit;

  @override
  State<PickItemScanScreen> createState() => _PickItemScanScreenState();
}

class _PickItemScanScreenState extends State<PickItemScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal, // allow the same code repeatedly
  );

  /// Units already picked before this session (usually 0).
  late final int _baseline = widget.item.pickedQty;

  /// Units scanned in this session (not yet committed).
  int _staged = 0;
  bool _busy = false;
  bool _committing = false;
  String? _msg;
  Color _msgColor = WelhofColors.ink;
  String? _dock;

  int get _quantity => widget.item.quantity;
  int get _picked => _baseline + _staged;
  bool get _fullyScanned => _picked >= _quantity;

  @override
  void initState() {
    super.initState();
    // An item opened already fully picked (e.g. re-docking) jumps straight to
    // the dock chooser.
    if (_fullyScanned) _dock = widget.docks.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _fullyScanned || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    VerifyResult result;
    try {
      result = await widget.onVerify(code);
    } catch (e) {
      result = VerifyResult.failed('$e');
    }
    if (!mounted) return;

    setState(() {
      if (result.match) {
        _staged++;
        _msg = 'Gescand  $_picked/$_quantity';
        _msgColor = const Color(0xFF2AA745);
        if (_fullyScanned) {
          _dock ??= widget.docks.first;
          HapticFeedback.mediumImpact();
        }
      } else {
        _msg = result.error == 'no_barcode'
            ? 'Geen barcode herkend'
            : 'Verkeerd product — hoort niet bij deze regel';
        _msgColor = const Color(0xFFC62828);
        HapticFeedback.heavyImpact();
      }
    });
    // Cooldown so one physical scan counts once.
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirm() async {
    final dock = _dock;
    if (!_fullyScanned || dock == null || _committing) return;
    setState(() => _committing = true);
    try {
      await widget.onCommit(_quantity, dock);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _committing = false;
          _msg = 'Bevestigen mislukt: $e';
          _msgColor = const Color(0xFFC62828);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final title = item.productName.isEmpty ? item.productSku : item.productName;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Flits',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Camera niet beschikbaar:\n${error.errorCode.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                    color: _fullyScanned
                        ? const Color(0xFF39D353)
                        : WelhofColors.accent,
                    width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Panel(
              sku: item.productSku,
              picked: _picked,
              quantity: _quantity,
              fullyScanned: _fullyScanned,
              msg: _msg,
              msgColor: _msgColor,
              docks: widget.docks,
              dock: _dock,
              committing: _committing,
              onDockChanged: (v) => setState(() => _dock = v),
              onConfirm: _confirm,
              onCancel: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.sku,
    required this.picked,
    required this.quantity,
    required this.fullyScanned,
    required this.msg,
    required this.msgColor,
    required this.docks,
    required this.dock,
    required this.committing,
    required this.onDockChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  final String sku;
  final int picked;
  final int quantity;
  final bool fullyScanned;
  final String? msg;
  final Color msgColor;
  final List<String> docks;
  final String? dock;
  final bool committing;
  final ValueChanged<String> onDockChanged;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sku, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: quantity == 0 ? 0 : picked / quantity,
              minHeight: 8,
              backgroundColor: const Color(0xFFE9ECEF),
              color: fullyScanned
                  ? const Color(0xFF2AA745)
                  : WelhofColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            msg ?? '$picked/$quantity gescand — richt op een barcode',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: msg == null ? WelhofColors.ink : msgColor),
          ),
          const SizedBox(height: 14),
          if (!fullyScanned)
            OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Annuleren'),
            )
          else ...[
            Row(
              children: [
                const Text('Dock',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: WelhofColors.ink)),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: WelhofColors.accent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: dock ?? docks.first,
                        isExpanded: true,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: WelhofColors.ink),
                        onChanged: committing
                            ? null
                            : (v) => onDockChanged(v ?? docks.first),
                        items: [
                          for (final d in docks)
                            DropdownMenuItem(value: d, child: Text(d)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: committing ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Annuleren'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: committing ? null : onConfirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF2AA745),
                    ),
                    child: committing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Bevestigen'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
