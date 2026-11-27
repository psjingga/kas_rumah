import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'warm_widgets.dart';

/// Kartu kecil di Ringkasan (mis. status anggaran, tabungan) yang bisa
/// diketuk untuk membuka tab terkait.
class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.caption,
    this.progress,
    this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? caption;

  /// 0..1; `null` = tanpa bar.
  final double? progress;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final c = color ?? p.primary;
    return WarmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: icon, color: c, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: p.inkMuted),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color ?? p.ink,
            ),
          ),
          if (caption case final cap?)
            Text(
              cap,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
          if (progress case final v?) ...[
            const SizedBox(height: 10),
            SoftProgress(value: v, color: c),
          ],
        ],
      ),
    );
  }
}
