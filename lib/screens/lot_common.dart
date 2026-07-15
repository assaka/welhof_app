import 'package:flutter/material.dart';

import '../theme.dart';

/// Colour for a lot / lot-item status.
Color lotStatusColor(String status) {
  switch (status) {
    case 'posted':
      return const Color(0xFF39D353);
    case 'allocated':
      return const Color(0xFF1BA39C);
    case 'captured':
      return WelhofColors.accent;
    case 'allocating':
      return const Color(0xFFE08A00);
    default: // pending / new
      return const Color(0xFF8A94A6);
  }
}

/// Dutch label for a status.
String lotStatusLabel(String status) {
  switch (status) {
    case 'posted':
      return 'Geboekt';
    case 'allocated':
      return 'Gekoppeld';
    case 'captured':
      return 'Vastgelegd';
    case 'allocating':
      return 'Bezig';
    case 'new':
      return 'Nieuw';
    default:
      return 'Open';
  }
}

class LotStatusChip extends StatelessWidget {
  const LotStatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = lotStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        lotStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Full-height centered message (error / empty) that still scrolls, so
/// pull-to-refresh works even when there's no list.
class LotMessage extends StatelessWidget {
  const LotMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: Colors.black26),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: WelhofColors.ink)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Opnieuw proberen'),
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: content),
        ),
      ),
    );
  }
}
