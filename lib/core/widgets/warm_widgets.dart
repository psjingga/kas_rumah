import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Ikon dalam kotak membulat berwarna pastel (pengganti CircleAvatar).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.background,
  });

  final IconData icon;
  final Color color;
  final double size;

  /// Latar khusus; bawaan = [color] tipis (pastel).
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: dark ? .22 : .14),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(icon, color: color, size: size * .55),
    );
  }
}

/// Label bagian kecil berhuruf kapital, mis. "PERLU PERHATIAN".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
                color: context.palette.inkMuted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Bar progres membulat 8px dengan latar krem.
class SoftProgress extends StatelessWidget {
  const SoftProgress({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          color: color ?? context.palette.primary,
          backgroundColor: context.palette.surfaceMuted,
        ),
      ),
    );
  }
}

/// Kartu putih membulat dengan padding standar; [onTap] opsional.
class WarmCard extends StatelessWidget {
  const WarmCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// TabBar berbentuk pil di atas latar krem (dipakai di bawah AppBar).
class PillTabBar extends StatelessWidget {
  const PillTabBar({super.key, required this.tabs});

  final List<Widget> tabs;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(99),
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: p.primary,
          borderRadius: BorderRadius.circular(99),
        ),
        labelColor: Theme.of(context).colorScheme.onPrimary,
        unselectedLabelColor: p.inkMuted,
        splashBorderRadius: BorderRadius.circular(99),
        tabs: tabs,
      ),
    );
  }
}
