import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/warm_widgets.dart';
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
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengingat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const _PermissionBanner(),
          const SectionLabel('Tagihan & rutin'),
          _Group([
            SwitchListTile(
              secondary: IconTile(
                icon: Icons.notifications_active_rounded,
                color: p.primary,
              ),
              title: const Text('Ingatkan transaksi rutin'),
              subtitle: const Text(
                'Notifikasi sebelum jatuh tempo, selama belum dicatat',
              ),
              value: s.enabled,
              onChanged: (on) => _toggle(context, ref, on),
            ),
            ListTile(
              enabled: s.enabled,
              leading: IconTile(icon: Icons.event_rounded, color: p.info),
              title: const Text('Kapan diingatkan'),
              trailing: DropdownButton<int>(
                value: s.daysBefore,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(14),
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
              leading: IconTile(
                icon: Icons.schedule_rounded,
                color: p.inkMuted,
              ),
              title: const Text('Jam pengingat'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: p.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  s.timeLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              onTap: () => _pickTime(context, ref),
            ),
          ]),
          const SizedBox(height: 20),
          const SectionLabel('Anggaran'),
          _Group([
            SwitchListTile(
              secondary: IconTile(
                icon: Icons.pie_chart_rounded,
                color: p.warning,
              ),
              title: const Text('Peringatan anggaran'),
              subtitle: const Text(
                'Notifikasi saat anggaran kategori terpakai 80% dan 100%',
              ),
              value: s.budgetAlerts,
              onChanged: (on) => ref
                  .read(reminderSettingsProvider.notifier)
                  .update(s.copyWith(budgetAlerts: on)),
            ),
          ]),
          const SizedBox(height: 20),
          const SectionLabel('Jadwal terdekat'),
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                s.enabled
                    ? 'Tidak ada pengingat terjadwal. Pengingat hanya dibuat '
                          'untuk transaksi rutin aktif yang belum dicatat.'
                    : 'Pengingat dimatikan.',
                style: TextStyle(color: outline),
              ),
            )
          else
            _Group([
              for (final r in upcoming)
                ListTile(
                  leading: Container(
                    width: 44,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: p.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Fmt.shortMonth(r.fireAt).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: p.primary,
                          ),
                        ),
                        Text(
                          '${r.fireAt.day}',
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  title: Text(r.title),
                  subtitle: Text(Fmt.dateTime(r.fireAt)),
                ),
            ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _sendTest(context, ref),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Kirim notifikasi uji'),
          ),
        ],
      ),
    );
  }
}

/// Kartu berisi beberapa baris pengaturan dengan garis pemisah.
class _Group extends StatelessWidget {
  const _Group(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, w) in children.indexed) ...[
            if (i > 0) const Divider(indent: 72, endIndent: 16),
            w,
          ],
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
          margin: const EdgeInsets.only(bottom: 16),
          color: scheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_off_rounded,
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
