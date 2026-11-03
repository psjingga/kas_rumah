import 'package:flutter/material.dart';
import '../../../wallets/presentation/widgets/wallet_widgets.dart';
import '../../../wallets/presentation/providers/wallet_providers.dart';
import '../../../wallets/domain/wallet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_providers.dart';
import '../providers/recurring_providers.dart';
import '../widgets/form_fields.dart';

/// Form tambah / ubah transaksi rutin bulanan.
///
/// Mengubah nominal default hanya berpengaruh ke bulan yang belum dicatat;
/// transaksi yang sudah tercatat tetap seperti semula.
class RecurringFormPage extends ConsumerStatefulWidget {
  const RecurringFormPage({super.key, this.initial, required this.startMonth});

  final RecurringTransaction? initial;

  /// Bulan mulai berlaku untuk template baru.
  final DateTime startMonth;

  @override
  ConsumerState<RecurringFormPage> createState() => _RecurringFormPageState();
}

class _RecurringFormPageState extends ConsumerState<RecurringFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: widget.initial?.title,
  );
  late final _amountController = TextEditingController(
    text: switch (widget.initial?.amount) {
      final a? => Fmt.thousands(a),
      null => null,
    },
  );

  late var _type = widget.initial?.type ?? TransactionType.expense;
  late var _category =
      widget.initial?.category ??
      ref.read(categoriesOfTypeProvider(_type)).first;
  late var _day = widget.initial?.dayOfMonth ?? 1;
  late var _active = widget.initial?.active ?? true;
  late var _walletId = widget.initial == null
      ? ref.read(defaultWalletProvider).id
      : widget.initial!.walletId ?? Wallet.mainId;
  var _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final amount = Fmt.parseAmount(_amountController.text)!;
    final notifier = ref.read(recurringProvider.notifier);

    setState(() => _saving = true);
    try {
      if (widget.initial case final initial?) {
        await notifier.save(
          initial.copyWith(
            title: title,
            amount: amount,
            type: _type,
            category: _category,
            dayOfMonth: _day,
            active: _active,
            walletId: _walletId,
          ),
        );
      } else {
        await notifier.add(
          title: title,
          amount: amount,
          type: _type,
          category: _category,
          dayOfMonth: _day,
          startMonth: widget.startMonth,
          walletId: _walletId,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  Future<void> _delete(RecurringTransaction recurring) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi rutin?'),
        content: Text(
          '"${recurring.title}" tidak akan muncul lagi tiap bulan. '
          'Transaksi yang sudah tercatat tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(recurringProvider.notifier).remove(recurring.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    return Scaffold(
      appBar: AppBar(
        title: Text(initial == null ? 'Tambah Rutin' : 'Ubah Rutin'),
        actions: [
          if (initial != null)
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(initial),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TypeSelector(
              value: _type,
              onChanged: (t) => setState(() {
                _type = t;
                _category = ref.read(categoriesOfTypeProvider(t)).first;
              }),
            ),
            const SizedBox(height: 20),
            TitleField(controller: _titleController),
            const SizedBox(height: 16),
            AmountField(
              controller: _amountController,
              label: 'Nominal default',
              helperText: 'Bisa diubah saat mencatat tiap bulan',
            ),
            const SizedBox(height: 16),
            CategoryField(
              type: _type,
              value: _category,
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(
                labelText: 'Tanggal tiap bulan',
                helperText: 'Tanggal 29–31 memakai akhir bulan bila tidak ada',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(value: d, child: Text('Tanggal $d')),
              ],
              onChanged: (d) => setState(() => _day = d ?? _day),
            ),
            const SizedBox(height: 16),
            WalletField(
              value: _walletId,
              onChanged: (w) => setState(() => _walletId = w),
            ),
            if (initial != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                subtitle: const Text('Nonaktif = tidak muncul tiap bulan'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            const SizedBox(height: 24),
            SaveButton(saving: _saving, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
