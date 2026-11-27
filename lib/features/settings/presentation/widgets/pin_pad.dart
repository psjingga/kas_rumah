import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Keypad angka + titik indikator PIN.
///
/// [onCompleted] dipanggil otomatis saat panjang mencapai [length]; bila
/// [length] `null` (membuat PIN baru, 4–6 digit), muncul tombol "Lanjut".
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onCompleted,
    this.length,
    this.minLength = 4,
    this.maxLength = 6,
    this.error,
    this.onBiometric,
  });

  final ValueChanged<String> onCompleted;
  final int? length;
  final int minLength;
  final int maxLength;

  /// Pesan galat di bawah titik (mis. "PIN salah").
  final String? error;

  /// Bila diisi, muncul tombol sidik jari di kiri bawah.
  final VoidCallback? onBiometric;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> {
  var _pin = '';

  /// Kosongkan isian (mis. setelah PIN salah).
  void clear() => setState(() => _pin = '');

  int get _max => widget.length ?? widget.maxLength;

  void _tap(String digit) {
    if (_pin.length >= _max) return;
    setState(() => _pin += digit);
    if (widget.length != null && _pin.length == widget.length) {
      final pin = _pin;
      _pin = '';
      widget.onCompleted(pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dots = widget.length ?? _pin.length.clamp(widget.minLength, _max);

    final p = context.palette;
    // Tombol angka bulat putih; tombol ikon (sidik jari/hapus) tanpa latar.
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: SizedBox.square(
        dimension: 72,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            shape: const CircleBorder(),
            foregroundColor: p.ink,
            backgroundColor: child == null ? p.surface : Colors.transparent,
            elevation: 0,
            side: child == null ? BorderSide(color: p.border) : null,
          ),
          child:
              child ??
              Text(
                label,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${_pin.length} digit dimasukkan',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < dots; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? scheme.primary : null,
                    border: Border.all(
                      color: i < _pin.length ? scheme.primary : p.border,
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 32,
          child: Center(
            child: Text(
              widget.error ?? '',
              style: TextStyle(color: scheme.error),
            ),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final d in row) key(d, onTap: () => _tap(d))],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onBiometric case final bio?)
              key(
                '',
                onTap: bio,
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: 34,
                  color: scheme.primary,
                  semanticLabel: 'Sidik jari',
                ),
              )
            else
              const SizedBox(width: 92),
            key('0', onTap: () => _tap('0')),
            key(
              '',
              onTap: _pin.isEmpty
                  ? null
                  : () => setState(
                      () => _pin = _pin.substring(0, _pin.length - 1),
                    ),
              child: const Icon(
                Icons.backspace_rounded,
                semanticLabel: 'Hapus',
              ),
            ),
          ],
        ),
        if (widget.length == null) ...[
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
            onPressed: _pin.length >= widget.minLength
                ? () {
                    final pin = _pin;
                    setState(() => _pin = '');
                    widget.onCompleted(pin);
                  }
                : null,
            child: const Text('Lanjut'),
          ),
        ],
      ],
    );
  }
}
