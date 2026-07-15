import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import 'registration_screen.dart';
import 'order_picking_screen.dart';
import 'lot_list_screen.dart';
import 'section_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // A `drawer` makes the AppBar show the hamburger icon automatically;
      // it slides in from the left.
      drawer: WelhofDrawer(phoneNumber: phoneNumber),
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.asset('assets/images/welhof_logo.png', height: 26),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 88,
                  width: 88,
                  decoration: BoxDecoration(
                    color: WelhofColors.brand,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.warehouse_rounded,
                      color: Colors.white, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welkom',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: WelhofColors.ink,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open het menu linksboven om een module te kiezen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 24),
                Builder(
                  builder: (context) => FilledButton.icon(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu),
                    label: const Text('Menu openen'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(200, 52),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The left navigation drawer.
class WelhofDrawer extends StatelessWidget {
  const WelhofDrawer({super.key, required this.phoneNumber});

  final String phoneNumber;

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RegistrationScreen()),
      (route) => false,
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).pop(); // close the drawer first
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Header with the signed-in user.
          Container(
            width: double.infinity,
            color: WelhofColors.brand,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset(
                    'assets/images/welhof_logo.png',
                    height: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: WelhofColors.accent,
                  child: Icon(Icons.person, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Ingelogd als',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  phoneNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _tile(context, Icons.shopping_cart_checkout, 'Orderverzamelen',
                    () => _open(context, const OrderPickingScreen())),
                // Incoming products → its single child (Returns) as a
                // collapsible sub-item.
                ExpansionTile(
                  leading: const Icon(Icons.move_to_inbox,
                      color: WelhofColors.brand),
                  title: const Text('Inkomende producten',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  childrenPadding: const EdgeInsets.only(left: 16),
                  children: [
                    _tile(context, Icons.inventory_2, 'Batch',
                        () => _open(
                            context,
                            const SectionScreen(
                              title: 'Batch',
                              icon: Icons.inventory_2,
                              breadcrumb: 'Inkomende producten',
                            ))),
                    _tile(context, Icons.assignment_return, 'Retouren',
                        () => _open(context, const LotListScreen())),
                  ],
                ),
                _tile(context, Icons.edit_location_alt, 'Locaties wijzigen',
                    () => _open(
                        context,
                        const SectionScreen(
                          title: 'Locaties wijzigen',
                          icon: Icons.edit_location_alt,
                        ))),
                _tile(context, Icons.build, 'Reparaties',
                    () => _open(
                        context,
                        const SectionScreen(
                            title: 'Reparaties', icon: Icons.build))),
                _tile(context, Icons.warehouse, 'Voorraad',
                    () => _open(
                        context,
                        const SectionScreen(
                            title: 'Voorraad', icon: Icons.warehouse))),
                _tile(context, Icons.help_outline, 'Veelgestelde vragen',
                    () => _open(
                        context,
                        const SectionScreen(
                            title: 'Veelgestelde vragen', icon: Icons.help_outline))),
                _tile(context, Icons.badge, 'HRM',
                    () => _open(
                        context,
                        const SectionScreen(
                            title: 'HRM', icon: Icons.badge))),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.black54),
            title: const Text('Uitloggen'),
            onTap: () => _signOut(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _tile(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: WelhofColors.brand),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}
