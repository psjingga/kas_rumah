import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/reminder_settings.dart';
import '../providers/reminder_providers.dart';

/// Pengaturan notifikasi pengingat transaksi rutin + daftar jadwal terdekat.
class ReminderSettingsPage extends ConsumerWidget {
  const ReminderSettingsPage({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    final notifier = ref.read(reminderSettingsProvider.notifier);
    await notifier.update(
      ref.read(reminderSettingsProvider).copyWith(enabled: on),
    );
    if (!on) return;

    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermission();
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Izin notifikasi belum diberikan. Aktifkan lewat Pengaturan HP '
            '› Aplikasi › Kas Rumah › Notifikasi.',
          ),
        ),
      );
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final s = ref.read(reminderSettingsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.hour, minute: s.minute),
    );
    if (picked == null) return;
    await ref
        .read(reminderSettingsProvider.notifier)
        .update(s.copyWith(hour: picked.hour, minute: picked.minute));
  }

  Future<void> _sendTest(BuildContext context, WidgetRef ref) async {
    const title = 'Uji pengingat';
    const body = 'Notifikasi pengingat transaksi rutin sudah berfungsi.';
    final service = ref.read(notificationServiceProvider);
    await service.requestPermission();
    await service.showNow(title: title, body: body);
    await ref
        .read(notificationInboxProvider.notifier)
        .addNow(title: title, body: body);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(reminderSettingsProvider);
    final upcoming = ref.watch(plannedRemindersProvider).take(5).toList();
    final outline = Theme.of(context).colorScheme.outline;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengingat')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _PermissionBanner(),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Ingatkan transaksi rutin'),
            subtitle: const Text(
              'Notifikasi sebelum jatuh tempo, selama belum dicatat',
            ),
            value: s.enabled,
            onChanged: (on) => _toggle(context, ref, on),
          ),
          ListTile(
            enabled: s.enabled,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Kapan diingatkan'),
            trailing: DropdownButton<int>(
              value: s.daysBefore,
              underline: const SizedBox.shrink(),
              onChanged: s.enabled
                  ? (d) => ref
                        .read(reminderSettingsProvider.notifier)
                        .update(s.copyWith(daysBefore: d))
                  : null,
              items: [
                for (final d in ReminderSettings.daysBeforeOptions)
                  DropdownMenuItem(
                    value: d,
                    child: Text(ReminderSettings.daysBeforeLabel(d)),
                  ),
              ],
            ),
          ),
          ListTile(
            enabled: s.enabled,
            leading: const Icon(Icons.schedule),
            title: const Text('Jam pengingat'),
            trailing: Text(
              s.timeLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _pickTime(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.pie_chart_outline),
            title: const Text('Peringatan anggaran'),
            subtitle: const Text(
              'Notifikasi saat anggaran kategori terpakai 80% dan 100%',
            ),
            value: s.budgetAlerts,
            onChanged: (on) => ref
                .read(reminderSettingsProvider.notifier)
                .update(s.copyWith(budgetAlerts: on)),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Jadwal terdekat',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                s.enabled
                    ? 'Tidak ada pengingat terjadwal. Pengingat hanya dibuat '
                          'untuk transaksi rutin aktif yang belum dicatat.'
                    : 'Pengingat dimatikan.',
                style: TextStyle(color: outline),
              ),
            )
          else
            for (final r in upcoming)
              ListTile(
                dense: true,
                leading: const Icon(Icons.notifications_none),
                title: Text(r.title),
                subtitle: Text(Fmt.dateTime(r.fireAt)),
              ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _sendTest(context, ref),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Kirim notifikasi uji'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Peringatan bila izin notifikasi HP dimatikan, dengan tombol ke
/// pengaturan. Dicek ulang saat aplikasi kembali dari pengaturan HP.
class _PermissionBanner extends ConsumerStatefulWidget {
  const _PermissionBanner();

  @override
  ConsumerState<_PermissionBanner> createState() => _PermissionBannerState();
}

class _PermissionBannerState extends ConsumerState<_PermissionBanner> {
  late Future<bool> _granted = _check();
  late final _listener = AppLifecycleListener(
    onResume: () => setState(() => _granted = _check()),
  );

  Future<bool> _check() =>
      ref.read(notificationServiceProvider).isPermissionGranted();

  @override
  void initState() {
    super.initState();
    _listener; // Mulai mendengarkan siklus hidup aplikasi.
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: _granted,
      builder: (context, snap) {
        if (snap.data != false) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          color: scheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      color: scheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Izin notifikasi mati. Pengingat & peringatan '
                        'tidak akan muncul di HP.',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        ref.read(notificationServiceProvider).openSettings(),
                    child: const Text('Buka pengaturan'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
