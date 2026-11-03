import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/theme/money_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../reminders/presentation/pages/reminder_settings_page.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../providers/recurring_providers.dart';
import '../providers/transaction_providers.dart';
import 'recurring_form_page.dart';

/// Daftar transaksi rutin bulanan (gaji, listrik, cicilan, dll.).
class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  void _openForm(
    BuildContext context,
    WidgetRef ref, [
    RecurringTransaction? initial,
  ]) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => RecurringFormPage(
          initial: initial,
          startMonth: ref.read(selectedMonthProvider),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringProvider);
    final active = items.where((r) => r.active);
    final income = active
        .where((r) => r.isIncome)
        .fold(0.0, (sum, r) => sum + r.amount);
    final expense = active
        .where((r) => !r.isIncome)
        .fold(0.0, (sum, r) => sum + r.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi Rutin'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan pengingat',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ReminderSettingsPage(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Rutin'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(
            'Transaksi rutin muncul di dashboard setiap bulan sebagai '
            '"belum dicatat". Nominal default bisa diubah saat mencatat.',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            EmptyState(
              icon: Icons.event_repeat,
              title: 'Belum ada transaksi rutin',
              message:
                  'Tambahkan gaji, listrik, internet, atau cicilan '
                  'agar diingatkan setiap bulan.',
              actionLabel: 'Tambah rutin',
              onAction: () => _openForm(context, ref),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _TotalRow('Pemasukan rutin / bulan', income),
                    const SizedBox(height: 6),
                    _TotalRow('Pengeluaran rutin / bulan', expense),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final r in items)
                    _RecurringTile(
                      recurring: r,
                      onTap: () => _openForm(context, ref, r),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value);

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          Fmt.rupiah(value),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _RecurringTile extends StatelessWidget {
  const _RecurringTile({required this.recurring, required this.onTap});

  final RecurringTransaction recurring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = recurring;
    return Opacity(
      opacity: r.active ? 1 : .5,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: r.category.color.withValues(alpha: .15),
          child: Icon(r.category.icon, color: r.category.color, size: 20),
        ),
        title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            'Tiap tgl ${r.dayOfMonth}',
            r.category.label,
            if (!r.active) 'Nonaktif',
          ].join(' · '),
        ),
        trailing: Text(
          '${r.isIncome ? '+' : '−'} ${Fmt.rupiah(r.amount)}',
          style: TextStyle(
            color: r.isIncome ? context.incomeColor : context.expenseColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
