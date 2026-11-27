import 'package:flutter/material.dart';

import '../../../../core/widgets/warm_widgets.dart';
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
              borderRadius: BorderRadius.circular(14),
              child: IconTile(
                icon: icon,
                size: 46,
                color: key == selected ? Colors.white : color,
                background: key == selected ? color : null,
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c == selected
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: c == selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
