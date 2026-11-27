import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/theme/money_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/warm_widgets.dart';
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
    final transactions = ref.watch(transactionsProvider);
    // Cicilan yang sudah lunas tidak dihitung lagi.
    final active = items.where(
      (r) =>
          r.active &&
          (r.totalOccurrences == null ||
              r.recordedCount(transactions) < r.totalOccurrences!),
    );
    final income = active
        .where((r) => r.isIncome)
        .fold(0.0, (sum, r) => sum + r.monthlyEquivalent);
    final expense = active
        .where((r) => !r.isIncome)
        .fold(0.0, (sum, r) => sum + r.monthlyEquivalent);

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
        icon: const Icon(Icons.add_rounded),
        label: const Text('Rutin'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Transaksi rutin muncul di dashboard setiap bulan sebagai '
              '"belum dicatat". Nominal default bisa diubah saat mencatat.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 14),
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
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _TotalRow(
                      'Pemasukan rutin / bulan',
                      income,
                      color: context.incomeColor,
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TotalRow(
                      'Pengeluaran rutin / bulan',
                      expense,
                      color: context.expenseColor,
                      icon: Icons.trending_down_rounded,
                    ),
                  ),
                ],
              ),
            ),
            for (final (label, group) in [
              ('Pengeluaran', items.where((r) => !r.isIncome).toList()),
              ('Pemasukan', items.where((r) => r.isIncome).toList()),
            ])
              if (group.isNotEmpty) ...[
                const SizedBox(height: 20),
                SectionLabel('$label · ${group.length}'),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (i, r) in group.indexed) ...[
                        if (i > 0) const Divider(indent: 72, endIndent: 16),
                        _RecurringTile(
                          recurring: r,
                          recordedCount: r.recordedCount(transactions),
                          onTap: () => _openForm(context, ref, r),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
          ],
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(
    this.label,
    this.value, {
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(icon: icon, color: color, size: 34),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Fmt.rupiah(value),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringTile extends StatelessWidget {
  const _RecurringTile({
    required this.recurring,
    required this.recordedCount,
    required this.onTap,
  });

  final RecurringTransaction recurring;

  /// Berapa kali sudah dicatat (untuk progres cicilan).
  final int recordedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = recurring;
    return Opacity(
      opacity: r.active ? 1 : .5,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: IconTile(icon: r.category.icon, color: r.category.color),
        title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            r.scheduleLabel,
            r.category.label,
            if (r.totalOccurrences case final total?)
              recordedCount >= total
                  ? 'Lunas ✓'
                  : 'Cicilan $recordedCount/$total',
            if (!r.active) 'Nonaktif',
          ].join(' · '),
        ),
        trailing: Text(
          '${r.isIncome ? '+' : '−'} ${Fmt.rupiah(r.amount)}',
          style: TextStyle(
            color: r.isIncome ? context.incomeColor : context.expenseColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
