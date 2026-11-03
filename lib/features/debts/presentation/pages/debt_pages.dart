import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/money_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/insight_card.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transactions/presentation/widgets/form_fields.dart';
import '../../../transactions/presentation/widgets/transaction_actions.dart';
import '../../../wallets/presentation/providers/wallet_providers.dart';
import '../../../wallets/presentation/widgets/wallet_widgets.dart';
import '../../domain/debt.dart';
import '../providers/debt_providers.dart';

/// Warna arah: utang (uang harus keluar) merah, piutang (akan masuk) hijau.
Color debtColor(BuildContext context, Debt d) =>
    d.iOwe ? context.expenseColor : context.incomeColor;

/// "Jatuh tempo 5 Nov" / "Lewat 3 hari" / "Lunas".
String debtStatus(Debt d, DateTime now) {
  if (d.isSettled) return 'Lunas';
  final due = d.dueDate;
  if (due == null) return 'Tanpa jatuh tempo';
  final days = DateUtils.dateOnly(due).difference(DateUtils.dateOnly(now));
  return switch (days.inDays) {
    < 0 => 'Lewat ${-days.inDays} hari',
    0 => 'Jatuh tempo hari ini',
    1 => 'Jatuh tempo besok',
    _ => 'Jatuh tempo ${Fmt.date(due)}',
  };
}

/// Daftar utang & piutang dengan ringkasan sisa.
class DebtsPage extends ConsumerStatefulWidget {
  const DebtsPage({super.key});

  @override
  ConsumerState<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends ConsumerState<DebtsPage> {
  var _showSettled = false;

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider);
    final totals = ref.watch(debtTotalsProvider);
    final now = ref.read(clockProvider)();
    final shown = [
      for (final d in debts)
        if (d.isSettled == _showSettled) d,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Utang & Piutang')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const DebtFormPage())),
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _TotalTile(
                    label: 'Utang saya',
                    caption: 'Harus dibayar',
                    value: totals.iOwe,
                    color: context.expenseColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TotalTile(
                    label: 'Piutang',
                    caption: 'Akan diterima',
                    value: totals.theyOwe,
                    color: context.incomeColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Belum lunas')),
              ButtonSegment(value: true, label: Text('Lunas')),
            ],
            selected: {_showSettled},
            onSelectionChanged: (s) => setState(() => _showSettled = s.first),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            EmptyState(
              icon: Icons.handshake_outlined,
              title: _showSettled
                  ? 'Belum ada yang lunas'
                  : 'Tidak ada utang/piutang aktif',
              message: _showSettled
                  ? null
                  : 'Catat pinjaman ke/dari keluarga, teman, atau tetangga '
                        'agar tidak lupa. Kamu akan diingatkan saat jatuh '
                        'tempo.',
              compact: true,
            )
          else
            for (final d in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DebtCard(
                  debt: d,
                  now: now,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DebtDetailPage(debtId: d.id),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.caption,
    required this.value,
    required this.color,
  });

  final String label;
  final String caption;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: textTheme.labelLarge),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Fmt.rupiah(value),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            Text(caption, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Kartu ringkas satu utang/piutang.
class DebtCard extends StatelessWidget {
  const DebtCard({
    super.key,
    required this.debt,
    required this.now,
    this.onTap,
  });

  final Debt debt;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = debt;
    final color = debtColor(context, d);
    final textTheme = Theme.of(context).textTheme;
    final overdue = d.isOverdue(now);
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
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .15),
                    child: Icon(
                      d.iOwe ? Icons.call_received : Icons.call_made,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.person,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(d.direction.label, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Fmt.rupiah(d.remaining),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: d.isSettled ? null : color,
                        ),
                      ),
                      Text('sisa', style: textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: d.progress,
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: .15),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dibayar ${Fmt.rupiah(d.paid)} dari ${Fmt.rupiah(d.amount)}',
                      style: textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    debtStatus(d, now),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: overdue
                          ? context.expenseColor
                          : d.isSettled
                          ? context.incomeColor
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail utang/piutang: progres, catat pembayaran, riwayat pembayaran.
class DebtDetailPage extends ConsumerWidget {
  const DebtDetailPage({super.key, required this.debtId});

  final String debtId;

  Future<void> _pay(BuildContext context, WidgetRef ref, Debt d) async {
    final result = await showModalBottomSheet<(double, String?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PaySheet(debt: d),
    );
    if (result == null) return;
    final (amount, walletId) = result;
    await ref
        .read(debtsProvider.notifier)
        .pay(
          d.id,
          amount: amount,
          date: DateUtils.dateOnly(ref.read(clockProvider)()),
          walletId: walletId,
        );
    unawaited(HapticFeedback.lightImpact());
    if (!context.mounted) return;
    final settled = ref
        .read(debtsProvider)
        .firstWhere((x) => x.id == d.id)
        .isSettled;
    showAppSnack(
      context,
      settled ? 'Lunas! 🎉' : 'Pembayaran ${Fmt.rupiah(amount)} tercatat.',
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Debt d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus catatan dengan ${d.person}?'),
        content: const Text(
          'Catatan dan riwayat pembayarannya dihapus. Perpindahan uang di '
          'dompet yang terkait ikut dibatalkan.',
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
    await ref.read(debtsProvider.notifier).remove(d.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(debtsProvider).where((x) => x.id == debtId).firstOrNull;
    if (d == null) return const Scaffold();
    final now = ref.read(clockProvider)();
    final wallet = ref.watch(walletLookupProvider)[d.walletId];
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(d.person),
        actions: [
          IconButton(
            tooltip: 'Ubah',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => DebtFormPage(initial: d)),
            ),
          ),
          IconButton(
            tooltip: 'Hapus',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref, d),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DebtCard(debt: d, now: now),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.event_outlined),
                  title: Text('${d.direction.personLabel} ${d.person}'),
                  subtitle: Text('Tanggal pinjam ${Fmt.date(d.date)}'),
                ),
                if (wallet != null)
                  ListTile(
                    dense: true,
                    leading: Icon(wallet.type.icon, color: wallet.color),
                    title: Text(
                      d.iOwe
                          ? 'Uang masuk ke ${wallet.name}'
                          : 'Uang keluar dari ${wallet.name}',
                    ),
                  ),
                if (d.note.isNotEmpty)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.sticky_note_2_outlined),
                    title: Text(d.note),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (!d.isSettled)
            FilledButton.icon(
              onPressed: () => _pay(context, ref, d),
              icon: const Icon(Icons.payments_outlined),
              label: Text(d.iOwe ? 'Catat pembayaran' : 'Catat penerimaan'),
            ),
          const SizedBox(height: 20),
          Text('Riwayat pembayaran', style: textTheme.titleMedium),
          if (d.payments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Belum ada pembayaran.', textAlign: TextAlign.center),
            ),
          for (final p in d.payments)
            Dismissible(
              key: ValueKey(p.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Theme.of(context).colorScheme.errorContainer,
                child: const Icon(Icons.delete_outline),
              ),
              onDismissed: (_) =>
                  ref.read(debtsProvider.notifier).removePayment(d.id, p.id),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.check_circle_outline,
                  color: debtColor(context, d),
                ),
                title: Text(Fmt.rupiah(p.amount)),
                subtitle: Text(
                  '${Fmt.date(p.date)}'
                  '${p.transferId == null ? '' : ' · tercatat di dompet'}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lembar catat pembayaran: nominal (default sisa) & dompet.
class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet({required this.debt});

  final Debt debt;

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: Fmt.thousands(widget.debt.remaining),
  );
  late var _record = widget.debt.walletId != null;
  late var _walletId =
      widget.debt.walletId ?? ref.read(defaultWalletProvider).id;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.debt;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              d.iOwe
                  ? 'Bayar utang ke ${d.person}'
                  : 'Terima pelunasan dari ${d.person}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Sisa ${Fmt.rupiah(d.remaining)}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp ',
              ),
              validator: (v) {
                final err = FormValidators.amount(v);
                if (err != null) return err;
                if (Fmt.parseAmount(v!)! > d.remaining + 0.5) {
                  return 'Melebihi sisa ${Fmt.rupiah(d.remaining)}';
                }
                return null;
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Catat ke dompet'),
              subtitle: Text(
                d.iOwe ? 'Saldo dompet berkurang' : 'Saldo dompet bertambah',
              ),
              value: _record,
              onChanged: (v) => setState(() => _record = v),
            ),
            if (_record)
              WalletField(
                value: _walletId,
                onChanged: (w) => setState(() => _walletId = w),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(context, (
                  Fmt.parseAmount(_amount.text)!,
                  _record ? _walletId : null,
                ));
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Catat utang/piutang baru, atau ubah nama/catatan/jatuh tempo.
class DebtFormPage extends ConsumerStatefulWidget {
  const DebtFormPage({super.key, this.initial});

  final Debt? initial;

  @override
  ConsumerState<DebtFormPage> createState() => _DebtFormPageState();
}

class _DebtFormPageState extends ConsumerState<DebtFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _person = TextEditingController(text: widget.initial?.person);
  final _amount = TextEditingController();
  late final _note = TextEditingController(text: widget.initial?.note);
  late var _direction = widget.initial?.direction ?? DebtDirection.iOwe;
  late var _date =
      widget.initial?.date ?? DateUtils.dateOnly(ref.read(clockProvider)());
  late var _dueDate = widget.initial?.dueDate;
  var _record = true;
  late var _walletId = ref.read(defaultWalletProvider).id;
  var _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(initial.year + 30),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final notifier = ref.read(debtsProvider.notifier);
    if (widget.initial case final d?) {
      await notifier.edit(
        d.copyWith(
          person: _person.text.trim(),
          note: _note.text.trim(),
          dueDate: () => _dueDate,
        ),
      );
    } else {
      await notifier.add(
        person: _person.text,
        direction: _direction,
        amount: Fmt.parseAmount(_amount.text)!,
        date: _date,
        dueDate: _dueDate,
        note: _note.text,
        walletId: _record ? _walletId : null,
      );
    }
    unawaited(HapticFeedback.lightImpact());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final iOwe = _direction == DebtDirection.iOwe;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah Catatan' : 'Utang / Piutang Baru'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_isEdit) ...[
              SegmentedButton<DebtDirection>(
                segments: const [
                  ButtonSegment(
                    value: DebtDirection.iOwe,
                    icon: Icon(Icons.call_received),
                    label: Text('Saya pinjam'),
                  ),
                  ButtonSegment(
                    value: DebtDirection.theyOwe,
                    icon: Icon(Icons.call_made),
                    label: Text('Saya pinjamkan'),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (s) => setState(() => _direction = s.first),
              ),
              const SizedBox(height: 20),
            ],
            TextFormField(
              controller: _person,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: iOwe ? 'Pinjam dari siapa' : 'Dipinjam oleh siapa',
                hintText: 'Mis. Bu RT',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            if (!_isEdit) ...[
              AmountField(controller: _amount),
              const SizedBox(height: 8),
              QuickAmountChips(controller: _amount),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final p = await _pick(_date);
                  if (p != null) setState(() => _date = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal pinjam',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(Fmt.date(_date)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            InkWell(
              onTap: () async {
                final p = await _pick(
                  _dueDate ?? _date.add(const Duration(days: 30)),
                );
                if (p != null) setState(() => _dueDate = p);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Jatuh tempo (opsional)',
                  prefixIcon: const Icon(Icons.event_outlined),
                  suffixIcon: _dueDate == null
                      ? null
                      : IconButton(
                          tooltip: 'Hapus jatuh tempo',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _dueDate = null),
                        ),
                ),
                child: Text(
                  _dueDate == null ? 'Tanpa jatuh tempo' : Fmt.date(_dueDate!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
            ),
            if (!_isEdit) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Catat ke dompet'),
                subtitle: Text(
                  iOwe
                      ? 'Uang pinjaman masuk ke dompet (bukan pemasukan)'
                      : 'Uang keluar dari dompet (bukan pengeluaran)',
                ),
                value: _record,
                onChanged: (v) => setState(() => _record = v),
              ),
              if (_record)
                WalletField(
                  value: _walletId,
                  onChanged: (w) => setState(() => _walletId = w),
                ),
            ],
            const SizedBox(height: 24),
            SaveButton(saving: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// Kartu ringkas di tab Ringkasan; tidak tampil bila tidak ada yang aktif.
class DebtsOverviewCard extends ConsumerWidget {
  const DebtsOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(debtTotalsProvider);
    if (totals.iOwe < 0.5 && totals.theyOwe < 0.5) {
      return const SizedBox.shrink();
    }
    final now = ref.read(clockProvider)();
    final overdue = ref.watch(debtsProvider).where((d) => d.isOverdue(now));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InsightCard(
        icon: Icons.handshake_outlined,
        title: 'Utang & Piutang',
        value:
            'Utang ${Fmt.rupiah(totals.iOwe)} · Piutang ${Fmt.rupiah(totals.theyOwe)}',
        caption: overdue.isEmpty
            ? 'Ketuk untuk detail'
            : '${overdue.length} lewat jatuh tempo',
        color: overdue.isEmpty ? null : context.expenseColor,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const DebtsPage())),
      ),
    );
  }
}
