import 'package:flutter/material.dart';
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
  static bool _isRecorded(WidgetRef ref, NotificationEntry e) {
    final due = e.dueDate;
    if (e.recurringId == null || due == null) return false;
    return ref
        .watch(transactionsProvider)
        .any(
          (t) => t.recurringId == e.recurringId && t.date.isSameMonthAs(due),
        );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    NotificationEntry e,
  ) async {
    await ref.read(notificationInboxProvider.notifier).markRead(e.id);
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
                    Icon(
                      Icons.notifications_none,
                      size: 56,
                      color: scheme.outline,
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
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = entries[i];
                final isReminder = e.recurringId != null;
                final recorded = _isRecorded(ref, e);
                return ListTile(
                  key: ValueKey(e.id),
                  tileColor: e.read
                      ? null
                      : scheme.primaryContainer.withValues(alpha: .35),
                  onTap: () => _open(context, ref, e),
                  leading: CircleAvatar(
                    backgroundColor: scheme.secondaryContainer,
                    child: Icon(
                      isReminder ? Icons.event_repeat : Icons.notifications,
                      color: scheme.onSecondaryContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    e.title,
                    style: TextStyle(
                      fontWeight: e.read ? FontWeight.w400 : FontWeight.w700,
                    ),
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
                          if (isReminder) _StatusChip(recorded: recorded),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                );
              },
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.recorded});

  final bool recorded;

  @override
  Widget build(BuildContext context) {
    final color = recorded ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        recorded ? 'Sudah dicatat' : 'Belum dicatat',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
