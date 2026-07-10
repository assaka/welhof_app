import 'package:flutter/material.dart';

import '../theme.dart';
import 'scanner_screen.dart';
import 'photo_screen.dart';

/// Full-page wrapper for a leaf menu item (its own AppBar + back button).
class SectionScreen extends StatelessWidget {
  const SectionScreen({
    super.key,
    required this.title,
    required this.icon,
    this.breadcrumb,
  });

  final String title;
  final IconData icon;
  final String? breadcrumb;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SectionBody(title: title, icon: icon, breadcrumb: breadcrumb),
    );
  }
}

/// Reusable content for a module: header + the two demo tools
/// (barcode scanner, photo). Used by [SectionScreen] and by the
/// Order Picking bottom-tab pages.
class SectionBody extends StatelessWidget {
  const SectionBody({
    super.key,
    required this.title,
    required this.icon,
    this.breadcrumb,
  });

  final String title;
  final IconData icon;
  final String? breadcrumb;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: WelhofColors.brand,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (breadcrumb != null) ...[
                        Text(
                          breadcrumb!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Acties',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: WelhofColors.ink,
                ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Barcode scannen',
            subtitle: 'Scan een product- of locatiecode.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ScannerScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.photo_camera_rounded,
            title: 'Foto maken',
            subtitle: 'Leg een product of schade vast.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PhotoScreen()),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WelhofColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: WelhofColors.accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Demo-module. De scanner en camera zijn hier al werkend.',
                    style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: WelhofColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: WelhofColors.accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: WelhofColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}
