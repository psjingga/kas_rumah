import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';

/// "‹ November 2026 ›" untuk berpindah bulan.
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.month,
    required this.isThisMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onThisMonth,
    this.foreground,
  });

  final DateTime month;
  final bool isThisMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onThisMonth;

  /// Warna teks/ikon khusus (mis. putih di atas hero); bawaan = tema.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Bulan sebelumnya',
          onPressed: onPrevious,
          color: foreground,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                Fmt.month(month),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: foreground),
              ),
              if (!isThisMonth)
                TextButton(
                  onPressed: onThisMonth,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: foreground,
                  ),
                  child: const Text('Ke bulan ini'),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Bulan berikutnya',
          onPressed: onNext,
          color: foreground,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

/// Geser horizontal untuk pindah bulan: ke kiri = bulan berikutnya,
/// ke kanan = bulan sebelumnya (seperti membalik halaman kalender).
class MonthSwipe extends StatelessWidget {
  const MonthSwipe({
    super.key,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget child;

  /// Kecepatan minimum (px/detik) agar geseran dianggap sengaja.
  static const _minVelocity = 350.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -_minVelocity) onNext();
        if (v > _minVelocity) onPrevious();
      },
      child: child,
    );
  }
}
