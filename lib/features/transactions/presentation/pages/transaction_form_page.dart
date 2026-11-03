import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/month.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_providers.dart';
import '../providers/recurring_providers.dart';
import '../providers/transaction_providers.dart';
import '../widgets/form_fields.dart';

/// Form transaksi dengan tiga mode:
/// - **tambah** (default): bisa sekaligus dijadikan transaksi rutin bulanan;
/// - **ubah** ([initial] diisi): mengubah transaksi yang sudah ada;
/// - **catat rutin** ([recurring] diisi): mencatat transaksi rutin untuk
///   [month] dengan nominal yang boleh berbeda dari default.
///
/// Mengembalikan `true` lewat `Navigator.pop` bila berhasil disimpan.
class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({
    super.key,
    required this.month,
    this.initial,
    this.recurring,
  }) : assert(initial == null || recurring == null);

  /// Bulan yang sedang dilihat; menentukan tanggal awal.
  final DateTime month;
  final Transaction? initial;
  final RecurringTransaction? recurring;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;

  late TransactionType _type;
  late TransactionCategory _category;
  late DateTime _date;

  /// Mode tambah: simpan juga sebagai transaksi rutin bulanan.
  var _repeatMonthly = false;

  /// Mode rutin/ubah: jadikan nominal ini default untuk bulan berikutnya.
  var _updateDefault = false;
  var _saving = false;

  bool get _isEdit => widget.initial != null;

  /// Template rutin yang terhubung (dari mode catat rutin, atau dari
  /// transaksi yang diubah bila dulu dicatat dari template).
  late final RecurringTransaction? _linked =
      widget.recurring ??
      ref
          .read(recurringProvider)
          .where((r) => r.id == widget.initial?.recurringId)
          .firstOrNull;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    final r = widget.recurring;
    final now = ref.read(clockProvider)();

    _titleController = TextEditingController(text: t?.title ?? r?.title);
    final amount = t?.amount ?? r?.amount;
    _amountController = TextEditingController(
      text: amount == null ? null : Fmt.thousands(amount),
    );
    _type = t?.type ?? r?.type ?? TransactionType.expense;
    _category = t?.category ?? r?.category ?? _firstCategory(_type);
    _date =
        t?.date ??
        r?.dueDate(widget.month) ??
        (widget.month.isSameMonthAs(now)
            ? DateUtils.dateOnly(now)
            : widget.month.firstOfMonth);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  TransactionCategory _firstCategory(TransactionType type) =>
      ref.read(categoriesOfTypeProvider(type)).first;

  /// Ganti jenis transaksi; kategori ikut di-reset ke kategori pertama
  /// yang sesuai agar tidak ada kombinasi "Gaji" sebagai pengeluaran.
  void _changeType(TransactionType type) => setState(() {
    _type = type;
    _category = _firstCategory(type);
  });

  /// Saran judul dipilih: pakai kategorinya, dan nominal terakhir bila
  /// nominal belum diisi.
  void _applySuggestion(TitleSuggestion s) => setState(() {
    if (s.category.type == _type) _category = s.category;
    if (_amountController.text.isEmpty) {
      _amountController.text = Fmt.thousands(s.amount);
    }
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(ref.read(clockProvider)().year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    // Tutup keyboard lalu jalankan semua validator.
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final amount = Fmt.parseAmount(_amountController.text)!;
    final transactions = ref.read(transactionsProvider.notifier);
    final recurring = ref.read(recurringProvider.notifier);

    setState(() => _saving = true);
    try {
      if (widget.initial case final initial?) {
        await transactions.edit(
          initial.copyWith(
            title: title,
            amount: amount,
            type: _type,
            category: _category,
            date: _date,
          ),
        );
      } else {
        // Mode tambah + "Ulangi tiap bulan": buat template dulu agar
        // transaksi pertama langsung terhubung ke template tersebut.
        var recurringId = widget.recurring?.id;
        if (_repeatMonthly) {
          final created = await recurring.add(
            title: title,
            amount: amount,
            type: _type,
            category: _category,
            dayOfMonth: _date.day,
            startMonth: _date.firstOfMonth,
          );
          recurringId = created.id;
        }
        await transactions.add(
          title: title,
          amount: amount,
          type: _type,
          category: _category,
          date: _date,
          recurringId: recurringId,
        );
      }

      if (_updateDefault && _linked != null) {
        await recurring.save(_linked.copyWith(amount: amount));
      }
      unawaited(HapticFeedback.lightImpact());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final linked = _linked;
    final title = switch ((_isEdit, widget.recurring)) {
      (true, _) => 'Ubah Transaksi',
      (_, _?) => 'Catat ${Fmt.month(widget.month)}',
      _ => 'Tambah Transaksi',
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (linked != null) ...[
              _RecurringInfo(recurring: linked),
              const SizedBox(height: 16),
            ],
            TypeSelector(value: _type, onChanged: _changeType),
            const SizedBox(height: 20),
            TitleAutocompleteField(
              controller: _titleController,
              suggestions: ref.watch(titleSuggestionsProvider(_type)),
              onSelected: _applySuggestion,
            ),
            const SizedBox(height: 16),
            AmountField(
              controller: _amountController,
              helperText: linked == null
                  ? null
                  : 'Nominal khusus bulan ini, default '
                        '${Fmt.rupiah(linked.amount)}',
            ),
            const SizedBox(height: 8),
            QuickAmountChips(controller: _amountController),
            const SizedBox(height: 16),
            CategoryField(
              type: _type,
              value: _category,
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(Fmt.date(_date)),
              ),
            ),
            const SizedBox(height: 8),
            if (linked != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Jadikan nominal default'),
                subtitle: const Text(
                  'Bulan-bulan berikutnya memakai nominal ini',
                ),
                value: _updateDefault,
                onChanged: (v) => setState(() => _updateDefault = v ?? false),
              )
            else if (!_isEdit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ulangi tiap bulan'),
                subtitle: Text(
                  'Jadi transaksi rutin tiap tanggal ${_date.day} '
                  'dengan nominal ini sebagai default',
                ),
                value: _repeatMonthly,
                onChanged: (v) => setState(() => _repeatMonthly = v),
              ),
            const SizedBox(height: 20),
            SaveButton(saving: _saving, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

/// Keterangan bahwa transaksi ini berasal dari transaksi rutin.
class _RecurringInfo extends StatelessWidget {
  const _RecurringInfo({required this.recurring});

  final RecurringTransaction recurring;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.event_repeat, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Transaksi rutin "${recurring.title}" · tiap tanggal '
              '${recurring.dayOfMonth} · default '
              '${Fmt.rupiah(recurring.amount)}',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
