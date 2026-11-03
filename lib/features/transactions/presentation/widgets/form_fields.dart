import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_providers.dart';

/// Validator bersama untuk form transaksi & form transaksi rutin.
abstract final class FormValidators {
  static String? title(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Judul wajib diisi';
    if (text.length > 60) return 'Judul maksimal 60 karakter';
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nominal wajib diisi';
    final amount = Fmt.parseAmount(value);
    if (amount == null) return 'Nominal harus berupa angka';
    if (amount <= 0) return 'Nominal harus lebih dari 0';
    return null;
  }
}

/// Pilihan Pengeluaran / Pemasukan.
class TypeSelector extends StatelessWidget {
  const TypeSelector({super.key, required this.value, required this.onChanged});

  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TransactionType>(
      segments: const [
        ButtonSegment(
          value: TransactionType.expense,
          label: Text('Pengeluaran'),
          icon: Icon(Icons.north_east),
        ),
        ButtonSegment(
          value: TransactionType.income,
          label: Text('Pemasukan'),
          icon: Icon(Icons.south_west),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Field judul / deskripsi.
class TitleField extends StatelessWidget {
  const TitleField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Judul / Deskripsi',
        hintText: 'Mis. Belanja sayur',
        prefixIcon: Icon(Icons.notes),
      ),
      validator: FormValidators.title,
    );
  }
}

/// Field nominal: hanya digit, otomatis diberi titik ribuan.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.label = 'Nominal',
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: const [ThousandsInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixText: 'Rp ',
        prefixIcon: const Icon(Icons.payments_outlined),
      ),
      validator: FormValidators.amount,
    );
  }
}

/// Dropdown kategori (bawaan + buatan sendiri) untuk [type].
class CategoryField extends ConsumerWidget {
  const CategoryField({
    super.key,
    required this.type,
    required this.value,
    required this.onChanged,
  });

  final TransactionType type;
  final TransactionCategory value;
  final ValueChanged<TransactionCategory> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(categoriesOfTypeProvider(type));
    return DropdownButtonFormField<TransactionCategory>(
      // Key berubah saat jenis berganti supaya pilihan ikut ter-reset.
      key: ValueKey(type),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Kategori',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: [
        // Kategori yang sudah dihapus tetap ditampilkan untuk data lama.
        for (final c in [
          if (!options.contains(value) && value.type == type) value,
          ...options,
        ])
          DropdownMenuItem(
            value: c,
            child: Row(
              children: [
                Icon(c.icon, color: c.color, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(c.label, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      onChanged: (c) => c == null ? null : onChanged(c),
    );
  }
}

/// Tombol simpan selebar layar dengan indikator loading.
class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check),
      label: const Text('Simpan'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }
}
