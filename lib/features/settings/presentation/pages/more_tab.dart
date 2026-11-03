import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../backup/presentation/pages/backup_page.dart';
import '../../../reminders/presentation/pages/reminder_settings_page.dart';
import '../../../transactions/presentation/pages/categories_page.dart';
import '../../../transactions/presentation/pages/recurring_page.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../providers/settings_providers.dart';
import 'security_page.dart';

/// Tab Lainnya: pengaturan & alat bantu.
class MoreTab extends ConsumerWidget {
  const MoreTab({super.key});

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastBackup = ref.watch(lastBackupProvider);
    final staleBackup =
        lastBackup == null ||
        ref.read(clockProvider)().difference(lastBackup) >
            const Duration(days: 30);
    final hasPin = ref.watch(securityProvider).hasPin;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ListTile(
          leading: const Icon(Icons.event_repeat),
          title: const Text('Transaksi Rutin'),
          subtitle: const Text('Gaji, tagihan, cicilan tiap bulan'),
          onTap: () => _push(context, const RecurringPage()),
        ),
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text('Kategori'),
          subtitle: const Text('Tambah kategori sendiri'),
          onTap: () => _push(context, const CategoriesPage()),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Pengingat & Notifikasi'),
          onTap: () => _push(context, const ReminderSettingsPage()),
        ),
        const Divider(),
        ListTile(
          leading: Icon(
            Icons.backup_outlined,
            color: staleBackup ? scheme.error : null,
          ),
          title: const Text('Backup & Ekspor'),
          subtitle: Text(
            lastBackup == null
                ? 'Belum pernah backup'
                : 'Terakhir ${Fmt.date(lastBackup)}',
            style: staleBackup ? TextStyle(color: scheme.error) : null,
          ),
          onTap: () => _push(context, const BackupPage()),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Kunci Aplikasi'),
          subtitle: Text(hasPin ? 'Aktif' : 'Mati'),
          onTap: () => _push(context, const SecurityPage()),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Tema', style: Theme.of(context).textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Sistem'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Terang'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Gelap'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {ref.watch(themeModeProvider)},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).set(s.first),
          ),
        ),
      ],
    );
  }
}
