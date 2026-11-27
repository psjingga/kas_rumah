import 'package:flutter/material.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/warm_widgets.dart';
import '../../domain/services/reminder_planner.dart';
import '../../../debts/presentation/providers/debt_providers.dart';
import '../../../debts/presentation/pages/debt_pages.dart';
import '../../../../core/theme/money_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/month.dart';
import '../../../transactions/presentation/providers/recurring_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transactions/presentation/widgets/transaction_actions.dart';
import '../../domain/entities/notification_entry.dart';
import '../providers/reminder_providers.dart';
import 'reminder_settings_page.dart';

/// Riwayat notifikasi yang sudah diterima. Pengingat transaksi rutin
/// menampilkan status "Belum dicatat" / "Sudah dicatat"; ketuk yang belum
/// dicatat untuk langsung mencatatnya.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  /// `true` bila transaksi rutin [e] sudah dicatat di bulan jatuh temponya.
  /// ID utang/piutang bila [e] pengingat utang/piutang.
  static String? _debtId(NotificationEntry e) =>
      e.recurringId?.startsWith(debtReminderPrefix) ?? false
      ? e.recurringId!.substring(debtReminderPrefix.length)
      : null;

  static bool _isRecorded(WidgetRef ref, NotificationEntry e) {
    final due = e.dueDate;
    if (e.recurringId == null || due == null) return false;
    // Utang/piutang: "selesai" bila sudah lunas.
    if (_debtId(e) case final id?) {
      return ref
              .watch(debtsProvider)
              .where((d) => d.id == id)
              .firstOrNull
              ?.isSettled ??
          true;
    }
    final transactions = ref.watch(transactionsProvider);
    final recurring = ref
        .watch(recurringProvider)
        .where((r) => r.id == e.recurringId)
        .firstOrNull;
    // Template sudah dihapus → cocokkan per bulan saja.
    return recurring?.isRecordedIn(transactions, due) ??
        transactions.any(
          (t) => t.recurringId == e.recurringId && t.date.isSameMonthAs(due),
        );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    NotificationEntry e,
  ) async {
    await ref.read(notificationInboxProvider.notifier).markRead(e.id);
    if (_debtId(e) case final id? when context.mounted) {
      if (ref.read(debtsProvider).any((d) => d.id == id)) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => DebtDetailPage(debtId: id)),
        );
      } else {
        showAppSnack(context, 'Catatan utang/piutang ini sudah dihapus.');
      }
      return;
    }
    final due = e.dueDate;
    if (e.recurringId == null || due == null || !context.mounted) return;

    if (_isRecorded(ref, e)) {
      showAppSnack(context, 'Transaksi ini sudah dicatat.');
      return;
    }
    final recurring = ref
        .read(recurringProvider)
        .where((r) => r.id == e.recurringId)
        .firstOrNull;
    if (recurring == null) {
      showAppSnack(context, 'Transaksi rutin ini sudah dihapus.');
      return;
    }
    await openTransactionForm(
      context,
      month: due.firstOfMonth,
      recurring: recurring,
      occurrenceDate: due,
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus semua notifikasi?'),
        content: const Text(
          'Riwayat notifikasi dihapus. Pengingat yang akan datang tetap '
          'dikirim.',
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
    if (ok == true) await ref.read(notificationInboxProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(notificationInboxProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (unread > 0)
            IconButton(
              tooltip: 'Tandai semua dibaca',
              icon: const Icon(Icons.done_all),
              onPressed: () =>
                  ref.read(notificationInboxProvider.notifier).markAllRead(),
            ),
          if (entries.isNotEmpty)
            IconButton(
              tooltip: 'Hapus semua',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context, ref),
            ),
          IconButton(
            tooltip: 'Pengaturan pengingat',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ReminderSettingsPage(),
              ),
            ),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTile(
                      icon: Icons.notifications_none_rounded,
                      color: context.palette.primary,
                      size: 72,
                    ),
                    const SizedBox(height: 12),
                    const Text('Belum ada notifikasi.'),
                    const SizedBox(height: 4),
                    Text(
                      'Pengingat transaksi rutin yang sudah dikirim akan '
                      'muncul di sini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.outline),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (i, e) in entries.indexed) ...[
                        if (i > 0) const Divider(indent: 72, endIndent: 16),
                        _entryTile(context, ref, e),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _entryTile(BuildContext context, WidgetRef ref, NotificationEntry e) {
    final p = context.palette;
    final isReminder = e.recurringId != null;
    final isDebt = _debtId(e) != null;
    final recorded = _isRecorded(ref, e);
    final (icon, color) = isDebt
        ? (Icons.handshake_rounded, const Color(0xFF8E5BB5))
        : isReminder
        ? (Icons.event_repeat_rounded, p.warning)
        : (Icons.notifications_rounded, p.primary);
    return ListTile(
      key: ValueKey(e.id),
      tileColor: e.read ? null : p.primarySoft.withValues(alpha: .45),
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      onTap: () => _open(context, ref, e),
      leading: IconTile(icon: icon, color: color),
      title: Row(
        children: [
          Expanded(
            child: Text(
              e.title,
              style: TextStyle(
                fontWeight: e.read ? FontWeight.w600 : FontWeight.w800,
              ),
            ),
          ),
          if (!e.read)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: p.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(e.body),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  Fmt.dateTime(e.time),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (isReminder) _StatusChip(recorded: recorded, debt: isDebt),
            ],
          ),
        ],
      ),
      isThreeLine: true,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.recorded, this.debt = false});

  final bool recorded;

  /// Pengingat utang/piutang: label Lunas / Belum lunas.
  final bool debt;

  @override
  Widget build(BuildContext context) {
    final color = recorded ? context.incomeColor : context.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        switch ((debt, recorded)) {
          (true, true) => 'Lunas',
          (true, false) => 'Belum lunas',
          (false, true) => 'Sudah dicatat',
          (false, false) => 'Belum dicatat',
        },
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
