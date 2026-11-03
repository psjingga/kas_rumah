import 'package:flutter/material.dart';

/// Tampilan saat belum ada data: ikon besar, judul, penjelasan singkat, dan
/// (opsional) tombol aksi utama.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Versi kecil untuk di dalam kartu (tanpa jarak besar).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: compact ? 16 : 48,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 56 : 88,
            height: compact ? 56 : 88,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: .6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: compact ? 28 : 44,
              color: scheme.onPrimaryContainer,
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: (compact ? textTheme.titleSmall : textTheme.titleMedium)
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (message case final m?) ...[
            const SizedBox(height: 6),
            Text(
              m,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (actionLabel case final label? when onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}
