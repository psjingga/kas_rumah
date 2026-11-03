import 'package:flutter/material.dart';
import '../../../../core/theme/money_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../transactions/domain/entities/transaction_category.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transactions/presentation/widgets/form_fields.dart';
import '../../../transactions/presentation/widgets/style_picker.dart';
import '../../../transactions/presentation/widgets/transaction_actions.dart';
import '../../domain/savings_goal.dart';
import '../providers/goal_providers.dart';
import 'goals_tab.dart';

/// Detail target tabungan: progres, setor/tarik, dan riwayat setoran.
class GoalDetailPage extends ConsumerWidget {
  const GoalDetailPage({super.key, required this.goalId});

  final String goalId;

  Future<void> _deposit(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal, {
    required bool withdraw,
  }) async {
    final result = await showModalBottomSheet<(double, bool)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DepositSheet(goal: goal, withdraw: withdraw),
    );
    if (result == null) return;
    final (amount, record) = result;
    await ref
        .read(goalsProvider.notifier)
        .deposit(
          goal.id,
          amount: withdraw ? -amount : amount,
          date: DateUtils.dateOnly(ref.read(clockProvider)()),
          recordTransaction: record,
        );
    if (context.mounted) {
      showAppSnack(
        context,
        '${withdraw ? 'Tarik' : 'Setor'} ${Fmt.rupiah(amount)} tersimpan.',
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus "${goal.name}"?'),
        content: const Text(
          'Target dan riwayat setorannya dihapus. Transaksi tabungan yang '
          'sudah tercatat tetap ada di riwayat transaksi.',
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
    await ref.read(goalsProvider.notifier).remove(goal.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref
        .watch(goalsProvider)
        .where((g) => g.id == goalId)
        .firstOrNull;
    // Target sudah dihapus (mis. saat menutup halaman ini).
    if (goal == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            tooltip: 'Ubah target',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GoalFormPage(initial: goal),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hapus target',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref, goal),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GoalCard(goal: goal, now: ref.read(clockProvider)()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _deposit(context, ref, goal, withdraw: false),
                  icon: const Icon(Icons.add),
                  label: const Text('Setor'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: goal.saved <= 0
                      ? null
                      : () => _deposit(context, ref, goal, withdraw: true),
                  icon: const Icon(Icons.remove),
                  label: const Text('Tarik'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Riwayat', style: Theme.of(context).textTheme.titleMedium),
          if (goal.deposits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Belum ada setoran.', textAlign: TextAlign.center),
            ),
          for (final d in goal.deposits)
            Dismissible(
              key: ValueKey(d.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Theme.of(context).colorScheme.errorContainer,
                child: const Icon(Icons.delete_outline),
              ),
              onDismissed: (_) =>
                  ref.read(goalsProvider.notifier).removeDeposit(goal.id, d.id),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  d.isWithdrawal ? Icons.north_east : Icons.south_west,
                  color: d.isWithdrawal
                      ? context.expenseColor
                      : context.incomeColor,
                ),
                title: Text(d.isWithdrawal ? 'Tarik' : 'Setor'),
                subtitle: Text(
                  '${Fmt.date(d.date)}'
                  '${d.transactionId == null ? '' : ' · tercatat di transaksi'}',
                ),
                trailing: Text(
                  Fmt.rupiah(d.amount.abs()),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lembar isi nominal setor/tarik.
class _DepositSheet extends StatefulWidget {
  const _DepositSheet({required this.goal, required this.withdraw});

  final SavingsGoal goal;
  final bool withdraw;

  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  var _record = true;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final withdraw = widget.withdraw;
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
              '${withdraw ? 'Tarik dari' : 'Setor ke'} ${widget.goal.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp ',
              ),
              validator: (v) {
                final err = FormValidators.amount(v);
                if (err != null) return err;
                if (withdraw && Fmt.parseAmount(v!)! > widget.goal.saved) {
                  return 'Melebihi saldo tabungan '
                      '(${Fmt.rupiah(widget.goal.saved)})';
                }
                return null;
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Catat juga sebagai transaksi'),
              subtitle: Text(
                withdraw
                    ? 'Pemasukan kategori "Ambil Tabungan"'
                    : 'Pengeluaran kategori "Tabungan", '
                          'mengurangi sisa saldo bulan ini',
              ),
              value: _record,
              onChanged: (v) => setState(() => _record = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(context, (
                    Fmt.parseAmount(_amount.text)!,
                    _record,
                  ));
                }
              },
              child: Text(withdraw ? 'Tarik' : 'Setor'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tambah / ubah target tabungan.
class GoalFormPage extends ConsumerStatefulWidget {
  const GoalFormPage({super.key, this.initial});

  final SavingsGoal? initial;

  @override
  ConsumerState<GoalFormPage> createState() => _GoalFormPageState();
}

class _GoalFormPageState extends ConsumerState<GoalFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _target = TextEditingController(
    text: switch (widget.initial?.target) {
      final t? => Fmt.thousands(t),
      null => null,
    },
  );
  late var _iconKey = widget.initial?.iconKey ?? 'savings';
  late var _color = Color(
    widget.initial?.colorValue ?? CategoryStyle.colors[2].toARGB32(),
  );
  late var _deadline = widget.initial?.deadline;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      helpText: 'Target tercapai pada',
      initialDate: _deadline ?? DateTime(now.year + 1, now.month),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final notifier = ref.read(goalsProvider.notifier);
    final target = Fmt.parseAmount(_target.text)!;
    if (widget.initial case final g?) {
      await notifier.edit(
        g.copyWith(
          name: _name.text.trim(),
          target: target,
          iconKey: _iconKey,
          colorValue: _color.toARGB32(),
          deadline: () => _deadline,
        ),
      );
    } else {
      await notifier.add(
        name: _name.text,
        target: target,
        iconKey: _iconKey,
        colorValue: _color.toARGB32(),
        deadline: _deadline,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Target Baru' : 'Ubah Target'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nama target',
                hintText: 'Mis. Dana darurat',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              validator: FormValidators.title,
            ),
            const SizedBox(height: 16),
            AmountField(controller: _target, label: 'Target nominal'),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDeadline,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tenggat (opsional)',
                  prefixIcon: const Icon(Icons.event_outlined),
                  suffixIcon: _deadline == null
                      ? null
                      : IconButton(
                          tooltip: 'Hapus tenggat',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _deadline = null),
                        ),
                ),
                child: Text(
                  _deadline == null ? 'Tanpa tenggat' : Fmt.month(_deadline!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Warna', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            ColorPicker(
              selected: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 20),
            Text('Ikon', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            IconPicker(
              selected: _iconKey,
              color: _color,
              onChanged: (k) => setState(() => _iconKey = k),
            ),
            const SizedBox(height: 24),
            SaveButton(saving: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
