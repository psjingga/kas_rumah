import 'package:flutter/material.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../debts/presentation/pages/debt_pages.dart';
import '../../../wallets/presentation/pages/wallet_pages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/warm_widgets.dart';
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

    final p = context.palette;

    Widget item({
      required IconData icon,
      required Color color,
      required String title,
      String? subtitle,
      Color? subtitleColor,
      required Widget page,
    }) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: IconTile(icon: icon, color: color),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: subtitleColor == null
                  ? null
                  : TextStyle(color: subtitleColor),
            ),
      trailing: Icon(Icons.chevron_right_rounded, color: p.inkMuted),
      onTap: () => _push(context, page),
    );

    Widget group(List<Widget> items) => Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, w) in items.indexed) ...[
            if (i > 0) const Divider(indent: 72, endIndent: 16),
            w,
          ],
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // Kartu identitas aplikasi.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: p.heroGradient,
            borderRadius: BorderRadius.circular(AppRadius.hero),
          ),
          child: Row(
            children: [
              // Bingkai putih agar logo madu tetap terlihat di atas
              // kartu bergradasi madu.
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 52,
                    height: 52,
                    errorBuilder: (_, _, _) => const IconTile(
                      icon: Icons.home_rounded,
                      color: Colors.white,
                      background: Color(0x33FFFFFF),
                      size: 52,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kas Rumah',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Semua data tersimpan di HP ini',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .85),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionLabel('Keuangan'),
        group([
          item(
            icon: Icons.insights_rounded,
            color: p.info,
            title: 'Laporan',
            subtitle: 'Tahunan, bandingkan bulan, PDF/gambar',
            page: const ReportsPage(),
          ),
          item(
            icon: Icons.account_balance_wallet_rounded,
            color: p.primary,
            title: 'Dompet',
            subtitle: 'Tunai, bank, e-wallet & transfer',
            page: const WalletsPage(),
          ),
          item(
            icon: Icons.handshake_rounded,
            color: const Color(0xFF8E5BB5),
            title: 'Utang & Piutang',
            subtitle: 'Pinjam & meminjamkan uang',
            page: const DebtsPage(),
          ),
          item(
            icon: Icons.event_repeat_rounded,
            color: const Color(0xFF2A9D8F),
            title: 'Transaksi Rutin',
            subtitle: 'Gaji, tagihan, cicilan: mingguan s/d tahunan',
            page: const RecurringPage(),
          ),
          item(
            icon: Icons.category_rounded,
            color: const Color(0xFFD45A8A),
            title: 'Kategori',
            subtitle: 'Tambah kategori sendiri',
            page: const CategoriesPage(),
          ),
        ]),
        const SizedBox(height: 22),
        const SectionLabel('Pengaturan'),
        group([
          item(
            icon: Icons.notifications_rounded,
            color: p.warning,
            title: 'Pengingat & Notifikasi',
            subtitle: 'Tagihan, anggaran, utang & target',
            page: const ReminderSettingsPage(),
          ),
          item(
            icon: Icons.backup_rounded,
            color: staleBackup ? p.expense : p.income,
            title: 'Backup & Ekspor',
            subtitle: lastBackup == null
                ? 'Belum pernah backup'
                : 'Terakhir ${Fmt.date(lastBackup)}',
            subtitleColor: staleBackup ? p.expense : null,
            page: const BackupPage(),
          ),
          item(
            icon: Icons.lock_rounded,
            color: const Color(0xFF5C6BC0),
            title: 'Kunci Aplikasi',
            subtitle: hasPin ? 'Aktif' : 'Mati',
            page: const SecurityPage(),
          ),
        ]),
        const SizedBox(height: 22),
        const SectionLabel('Tampilan'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Sistem'),
                  icon: Icon(Icons.brightness_auto_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Terang'),
                  icon: Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Gelap'),
                  icon: Icon(Icons.dark_mode_rounded),
                ),
              ],
              selected: {ref.watch(themeModeProvider)},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
        ),
      ],
    );
  }
}
