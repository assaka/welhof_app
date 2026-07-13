import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The stage an order is in on the warehouse floor.
enum PickStage { open, picking, picked, sorted }

/// Picking progress, shared across the order list and the detail screen so
/// status stays consistent while navigating, and persisted on-device via
/// [SharedPreferences] so it survives app restarts. State is local only — it
/// is NOT written back to Marello.
class PickProgress extends ChangeNotifier {
  PickProgress._();
  static final PickProgress instance = PickProgress._();

  static const _prefsKey = 'welhof.pick_progress';

  // orderId -> set of picked order-item ids.
  final Map<String, Set<String>> _picked = {};
  // orderId -> shipment location, once the order has been sorted.
  final Map<String, String> _sorted = {};
  bool _loaded = false;

  /// Loads persisted progress from disk. Idempotent; call once at startup.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        (data['picked'] as Map<String, dynamic>? ?? {}).forEach((order, ids) {
          _picked[order] = {for (final id in (ids as List)) '$id'};
        });
        (data['sorted'] as Map<String, dynamic>? ?? {})
            .forEach((order, loc) => _sorted[order] = '$loc');
      }
    } catch (_) {
      // Absent or corrupt prefs — start from an empty state.
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'picked': {
          for (final e in _picked.entries)
            if (e.value.isNotEmpty) e.key: e.value.toList(),
        },
        'sorted': _sorted,
      };
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (_) {
      // Best-effort persistence; ignore write failures.
    }
  }

  Set<String> _setFor(String orderId) =>
      _picked.putIfAbsent(orderId, () => <String>{});

  bool isItemPicked(String orderId, String itemId) =>
      _picked[orderId]?.contains(itemId) ?? false;

  int pickedCount(String orderId) => _picked[orderId]?.length ?? 0;

  bool allPicked(String orderId, int total) =>
      total > 0 && pickedCount(orderId) >= total;

  String? sortedLocation(String orderId) => _sorted[orderId];

  /// Toggles an item's picked state. Un-picking anything reverts a prior
  /// "sorted" (the order is no longer complete).
  void toggleItem(String orderId, String itemId) {
    final set = _setFor(orderId);
    if (!set.remove(itemId)) set.add(itemId);
    if (set.isEmpty) _picked.remove(orderId);
    _sorted.remove(orderId);
    notifyListeners();
    _save();
  }

  /// Marks the order staged at [location] for shipment (the Sort step).
  void setSorted(String orderId, String location) {
    _sorted[orderId] = location;
    notifyListeners();
    _save();
  }

  void clearSorted(String orderId) {
    if (_sorted.remove(orderId) != null) {
      notifyListeners();
      _save();
    }
  }

  /// Overall stage for an order with [total] line items.
  PickStage stageOf(String orderId, int total) {
    if (_sorted.containsKey(orderId)) return PickStage.sorted;
    final n = pickedCount(orderId);
    if (total > 0 && n >= total) return PickStage.picked;
    if (n > 0) return PickStage.picking;
    return PickStage.open;
  }
}
