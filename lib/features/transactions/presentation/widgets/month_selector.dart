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
  });

  final DateTime month;
  final bool isThisMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onThisMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Bulan sebelumnya',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                Fmt.month(month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!isThisMonth)
                TextButton(
                  onPressed: onThisMonth,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Ke bulan ini'),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Bulan berikutnya',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
