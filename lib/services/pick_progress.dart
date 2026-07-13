import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The stage an order is in on the warehouse floor.
enum PickStage { open, picking, picked, sorted }

/// Picking progress counted in **units** (a line item of quantity 2 needs two
/// picks) with **per-row sorting** (each picked row is staged at a location).
/// Shared across the order list and detail screen and persisted on-device via
/// [SharedPreferences]. Local only — not written back to Marello.
class PickProgress extends ChangeNotifier {
  PickProgress._();
  static final PickProgress instance = PickProgress._();

  static const _prefsKey = 'welhof.pick_progress';

  // orderId -> (order-item id -> units picked for that item).
  final Map<String, Map<String, int>> _picked = {};
  // orderId -> (order-item id -> shipment location, once that row is sorted).
  final Map<String, Map<String, String>> _sorted = {};
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
        (data['picked'] as Map<String, dynamic>? ?? {}).forEach((order, items) {
          if (items is Map) {
            _picked[order] = {
              for (final e in items.entries) '${e.key}': (e.value as num).toInt(),
            };
          }
        });
        (data['sorted'] as Map<String, dynamic>? ?? {}).forEach((order, items) {
          if (items is Map) {
            _sorted[order] = {
              for (final e in items.entries) '${e.key}': '${e.value}',
            };
          }
        });
      }
    } catch (_) {
      // Absent or corrupt/old-format prefs — start from an empty state.
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'picked': {
          for (final e in _picked.entries)
            if (e.value.isNotEmpty) e.key: e.value,
        },
        'sorted': {
          for (final e in _sorted.entries)
            if (e.value.isNotEmpty) e.key: e.value,
        },
      };
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (_) {
      // Best-effort persistence; ignore write failures.
    }
  }

  // ---- Picking (per unit) ----

  int pickedQty(String orderId, String itemId) =>
      _picked[orderId]?[itemId] ?? 0;

  bool isItemComplete(String orderId, String itemId, int quantity) =>
      pickedQty(orderId, itemId) >= quantity;

  /// Total units picked across the order.
  int pickedUnits(String orderId) {
    final map = _picked[orderId];
    if (map == null) return 0;
    var sum = 0;
    for (final v in map.values) {
      sum += v;
    }
    return sum;
  }

  /// Whether every unit of the order has been picked ([totalUnits] = sum of
  /// line-item quantities).
  bool allPicked(String orderId, int totalUnits) =>
      totalUnits > 0 && pickedUnits(orderId) >= totalUnits;

  /// Advances an item's picked units by one, wrapping back to 0 once it passes
  /// [quantity]. Resetting an item also un-sorts it.
  void bumpPick(String orderId, String itemId, int quantity) {
    final map = _picked.putIfAbsent(orderId, () => <String, int>{});
    final next = (map[itemId] ?? 0) + 1;
    if (next > quantity) {
      map.remove(itemId);
      _sorted[orderId]?.remove(itemId);
    } else {
      map[itemId] = next;
    }
    if (map.isEmpty) _picked.remove(orderId);
    if (_sorted[orderId]?.isEmpty ?? false) _sorted.remove(orderId);
    notifyListeners();
    _save();
  }

  // ---- Sorting (per row) ----

  /// Location a row is staged at, or null if not yet sorted.
  String? itemLocation(String orderId, String itemId) =>
      _sorted[orderId]?[itemId];

  bool isItemSorted(String orderId, String itemId) =>
      _sorted[orderId]?.containsKey(itemId) ?? false;

  int sortedCount(String orderId) => _sorted[orderId]?.length ?? 0;

  /// Whether every line item ([lineCount] rows) has been sorted.
  bool allSorted(String orderId, int lineCount) =>
      lineCount > 0 && sortedCount(orderId) >= lineCount;

  /// Stages a fully-picked row at [location].
  void sortItem(String orderId, String itemId, String location) {
    _sorted.putIfAbsent(orderId, () => <String, String>{})[itemId] = location;
    notifyListeners();
    _save();
  }

  void unsortItem(String orderId, String itemId) {
    final map = _sorted[orderId];
    if (map != null && map.remove(itemId) != null) {
      if (map.isEmpty) _sorted.remove(orderId);
      notifyListeners();
      _save();
    }
  }

  // ---- Roll-up ----

  /// Overall stage for an order with [totalUnits] units across [lineCount] rows.
  PickStage stageOf(String orderId, int totalUnits, int lineCount) {
    if (allSorted(orderId, lineCount)) return PickStage.sorted;
    if (allPicked(orderId, totalUnits)) return PickStage.picked;
    if (pickedUnits(orderId) > 0 || sortedCount(orderId) > 0) {
      return PickStage.picking;
    }
    return PickStage.open;
  }
}
