import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/marello_pick.dart';
import '../theme.dart';

/// Continuous barcode scanner for picking: each scan calls [onScan] (which picks
/// one unit server-side) and shows feedback, staying open so a qty-3 SKU can be
/// scanned three times. Allows repeat scans of the same code (with a short
/// cooldown) — unlike the one-shot [ScannerScreen].
class PickScannerScreen extends StatefulWidget {
  const PickScannerScreen({
    super.key,
    required this.onScan,
    this.title = 'Scan om te picken',
  });

  final Future<ScanResult> Function(String barcode) onScan;
  final String title;

  @override
  State<PickScannerScreen> createState() => _PickScannerScreenState();
}

class _PickScannerScreenState extends State<PickScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal, // allow the same code repeatedly
  );
  bool _busy = false;
  String? _msg;
  Color _msgColor = WelhofColors.ink;
  int _picks = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    ScanResult result;
    try {
      result = await widget.onScan(code);
    } catch (e) {
      result = ScanResult.failed('$e');
    }
    if (!mounted) return;

    setState(() {
      if (result.matched && !result.alreadyComplete) {
        _picks++;
        final done = result.complete ? '  ✓' : '';
        _msg = '${result.productSku}   ${result.pickedQty}/${result.quantity}$done';
        _msgColor = const Color(0xFF2AA745);
      } else if (result.matched && result.alreadyComplete) {
        _msg = '${result.productSku} is al volledig gepickt';
        _msgColor = const Color(0xFFB8860B);
        HapticFeedback.heavyImpact();
      } else {
        _msg = result.error == 'not_in_slip'
            ? 'Barcode hoort niet bij deze paklijst'
            : 'Scan mislukt (${result.error ?? 'onbekend'})';
        _msgColor = const Color(0xFFC62828);
        HapticFeedback.heavyImpact();
      }
    });
    // Cooldown so one physical scan counts once.
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
                border: Border.all(color: WelhofColors.accent, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_picks gepickt in deze sessie',
                      style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    _msg ?? 'Richt op een barcode om te picken',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _msg == null ? WelhofColors.ink : _msgColor),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: WelhofColors.brand,
                    ),
                    child: const Text('Klaar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
