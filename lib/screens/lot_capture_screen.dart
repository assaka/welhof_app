import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/marello_lot.dart';
import '../services/marello_service.dart';
import '../theme.dart';
import 'scanner_screen.dart';

/// Captures a lot item on the floor: scan the barcode (→ tries to match a
/// product), or search by name; then confirm qty + location + a photo and save.
/// Productization stays an office step — this only records what's in hand.
class LotCaptureScreen extends StatefulWidget {
  const LotCaptureScreen({super.key, required this.item});
  final MarelloLotItem item;

  @override
  State<LotCaptureScreen> createState() => _LotCaptureScreenState();
}

class _LotCaptureScreenState extends State<LotCaptureScreen> {
  late final MarelloService _service =
      MarelloService(config: MarelloConfig.fromEnvironment());
  final _picker = ImagePicker();

  late final TextEditingController _barcodeCtrl =
      TextEditingController(text: widget.item.barcode ?? '');
  late final TextEditingController _qtyCtrl =
      TextEditingController(text: '${widget.item.quantity}');
  late final TextEditingController _locCtrl =
      TextEditingController(text: widget.item.pickLocation ?? '');
  final _nameCtrl = TextEditingController();

  Uint8List? _photoBytes;
  List<MarelloProductHit> _matches = const [];
  bool _searching = false;
  bool _submitting = false;

  @override
  void dispose() {
    _service.dispose();
    _barcodeCtrl.dispose();
    _qtyCtrl.dispose();
    _locCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code != null && code.isNotEmpty) {
      _barcodeCtrl.text = code;
      await _search(barcode: code);
    }
  }

  Future<void> _search({String? barcode, String? name}) async {
    setState(() => _searching = true);
    try {
      final hits = await _service.searchProducts(barcode: barcode, name: name);
      if (mounted) setState(() => _matches = hits);
    } catch (e) {
      if (mounted) {
        setState(() => _matches = const []);
        _snack('Zoeken mislukt: $e');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => _photoBytes = bytes);
      }
    } catch (e) {
      _snack('Kon foto niet openen: $e');
    }
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qtyCtrl.text.trim());
    setState(() => _submitting = true);
    try {
      final updated = await _service.captureLotItem(
        widget.item.id,
        barcode: _barcodeCtrl.text.trim(),
        quantity: qty,
        pickLocation: _locCtrl.text.trim(),
        photoBytes: _photoBytes,
      );
      if (!mounted) return;
      _snack('Vastgelegd: ${updated.tempCode}');
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) _snack('Vastleggen mislukt: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(title: Text(item.tempCode)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              item.name.isEmpty ? 'Onbekend item' : item.name,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: WelhofColors.ink),
            ),
            const SizedBox(height: 16),

            // Barcode + scan
            _label('Barcode'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Scan of typ de barcode',
                    ),
                    onSubmitted: (v) => _search(barcode: v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _submitting ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Name search
            _label('Zoek op naam (indien geen barcode)'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Productnaam',
                    ),
                    onSubmitted: (v) => _search(name: v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => _search(name: _nameCtrl.text.trim()),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 52),
                  ),
                  child: const Text('Zoek'),
                ),
              ],
            ),
            _matchResults(),
            const SizedBox(height: 16),

            // Quantity + location
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Aantal'),
                      TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Aantal'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Locatie'),
                      TextField(
                        controller: _locCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(hintText: 'Bijv. A1'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Photo
            _label('Foto'),
            _photoArea(),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_submitting ? 'Bezig…' : 'Vastleggen'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchResults() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: LinearProgressIndicator(),
      );
    }
    if (_matches.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mogelijke producten (ter info):',
              style: TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 6),
          for (final m in _matches)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: WelhofColors.brand.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF1BA39C), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${m.sku} — ${m.name}',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDE1E6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: _photoBytes == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined,
                          size: 44, color: Colors.black26),
                      SizedBox(height: 8),
                      Text('Nog geen foto',
                          style: TextStyle(color: Colors.black45)),
                    ],
                  ),
                )
              : Image.memory(_photoBytes!, fit: BoxFit.cover),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    _submitting ? null : () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _submitting ? null : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Galerij'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: WelhofColors.brand),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: WelhofColors.ink)),
      );
}
