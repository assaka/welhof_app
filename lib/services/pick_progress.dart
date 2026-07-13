import 'package:flutter/foundation.dart';

/// The stage an order is in on the warehouse floor.
enum PickStage { open, picking, picked, sorted }

/// In-memory picking progress, shared across the order list and the detail
/// screen so status stays consistent while navigating. Not persisted — state
/// resets on app restart (no write-back to Marello yet).
class PickProgress extends ChangeNotifier {
  PickProgress._();
  static final PickProgress instance = PickProgress._();

  // orderId -> set of picked order-item ids.
  final Map<String, Set<String>> _picked = {};
  // orderId -> shipment location, once the order has been sorted.
  final Map<String, String> _sorted = {};

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
    _sorted.remove(orderId);
    notifyListeners();
  }

  /// Marks the order staged at [location] for shipment (the Sort step).
  void setSorted(String orderId, String location) {
    _sorted[orderId] = location;
    notifyListeners();
  }

  void clearSorted(String orderId) {
    if (_sorted.remove(orderId) != null) notifyListeners();
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
