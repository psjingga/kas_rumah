import 'package:flutter/material.dart';

import '../../domain/entities/transaction_category.dart';

/// Pilihan ikon dari [CategoryStyle.icons] dalam bentuk grid.
class IconPicker extends StatelessWidget {
  const IconPicker({
    super.key,
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  final String selected;
  final Color color;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final MapEntry(key: key, value: icon)
            in CategoryStyle.icons.entries)
          Semantics(
            label: 'Ikon $key',
            selected: key == selected,
            button: true,
            child: InkWell(
              onTap: () => onChanged(key),
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: key == selected
                    ? color
                    : color.withValues(alpha: .12),
                child: Icon(
                  icon,
                  size: 20,
                  color: key == selected ? Colors.white : color,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Pilihan warna dari [CategoryStyle.colors].
class ColorPicker extends StatelessWidget {
  const ColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in CategoryStyle.colors)
          Semantics(
            label: 'Warna',
            selected: c == selected,
            button: true,
            child: InkWell(
              onTap: () => onChanged(c),
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: c,
                child: c == selected
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
