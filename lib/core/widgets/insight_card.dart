import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final c = color ?? scheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: c),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: scheme.outline),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: c,
                ),
              ),
              if (caption case final cap?)
                Text(
                  cap,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              if (progress case final p?) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p.clamp(0, 1),
                    minHeight: 6,
                    color: c,
                    backgroundColor: c.withValues(alpha: .15),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
