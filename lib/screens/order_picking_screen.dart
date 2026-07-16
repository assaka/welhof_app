import 'package:flutter/material.dart';

import '../theme.dart';
import 'orders_list_view.dart';
import 'section_screen.dart';

/// Order Picking module. Its sub-items (All, Pick, Sort, Exchange) live in a
/// bottom navigation bar rather than in the drawer.
class OrderPickingScreen extends StatefulWidget {
  const OrderPickingScreen({super.key});

  @override
  State<OrderPickingScreen> createState() => _OrderPickingScreenState();
}

class _OrderPickingScreenState extends State<OrderPickingScreen> {
  int _index = 0;

  static const _tabs = <_PickTab>[
    _PickTab('Alle', Icons.list_alt),
    _PickTab('Picken', Icons.touch_app),
    _PickTab('Sorteren', Icons.sort),
    _PickTab('Ruilen', Icons.swap_horiz),
  ];

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_index];
    return Scaffold(
      appBar: AppBar(title: const Text('Orderverzamelen')),
      // "All" shows live orders from Marello; the other tabs remain the demo
      // tools until their status filters are defined.
      body: _index == 0
          ? const OrdersListView(key: ValueKey('orders-all'))
          : SectionBody(
              key: ValueKey(tab.label),
              title: tab.label,
              icon: tab.icon,
              breadcrumb: 'Orderverzamelen',
            ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: WelhofColors.accent.withValues(alpha: 0.20),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final t in _tabs)
              NavigationDestination(
                icon: Icon(t.icon),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _PickTab {
  const _PickTab(this.label, this.icon);
  final String label;
  final IconData icon;
}
