import 'package:flutter/material.dart';

import '../theme.dart';
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
    _PickTab('All', Icons.list_alt),
    _PickTab('Pick', Icons.touch_app),
    _PickTab('Sort', Icons.sort),
    _PickTab('Exchange', Icons.swap_horiz),
  ];

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_index];
    return Scaffold(
      appBar: AppBar(title: const Text('Order Picking')),
      body: SectionBody(
        key: ValueKey(tab.label),
        title: tab.label,
        icon: tab.icon,
        breadcrumb: 'Order Picking',
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
