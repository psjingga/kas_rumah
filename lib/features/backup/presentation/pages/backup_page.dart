import 'dart:convert';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/warm_widgets.dart';
import '../../data/backup_crypto.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/formatters.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transactions/presentation/widgets/transaction_actions.dart';
import '../../data/backup_service.dart';
import '../providers/backup_providers.dart';

/// Backup lengkap (JSON) untuk dipindah ke HP lain / disimpan di Drive,
/// pulihkan dari backup, dan ekspor CSV untuk Excel.
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  var _busy = false;

  Future<void> _run(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) showAppSnack(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Tulis [content] ke file sementara lalu buka lembar "Bagikan".
  Future<void> _shareFile(String name, String content, String text) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(content);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: text),
    );
  }

  String get _stamp =>
      DateFormat('yyyy-MM-dd').format(ref.read(clockProvider)());

  Future<void> _backup() async {
    // null = batal, '' = tanpa kata sandi.
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _NewPasswordDialog(),
    );
    if (password == null) return;
    await _run(() async {
      var json = ref
          .read(backupServiceProvider)
          .exportJson(ref.read(clockProvider)());
      final locked = password.isNotEmpty;
      if (locked) json = await const BackupCrypto().encrypt(json, password);
      await _shareFile(
        'kas-rumah-backup-$_stamp${locked ? '-terkunci' : ''}.json',
        json,
        'Backup Kas Rumah $_stamp${locked ? ' (terkunci kata sandi)' : ''}',
      );
      await ref.read(lastBackupProvider.notifier).markNow();
    });
  }

  /// Minta kata sandi untuk membuka backup terenkripsi.
  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup terkunci'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Kata sandi backup'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Buka'),
          ),
        ],
      ),
    );
  }

  Future<void> _restore() => _run(() async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Pilih file backup');
    if (files.isEmpty) return;
    var json = utf8.decode(await files.first.readAsBytes());
    final service = ref.read(backupServiceProvider);

    // Backup terenkripsi → minta kata sandi dulu.
    if (BackupCrypto.isEncrypted(json)) {
      if (!mounted) return;
      final password = await _askPassword();
      if (password == null || password.isEmpty) return;
      try {
        json = await const BackupCrypto().decrypt(json, password);
      } on WrongPasswordException catch (e) {
        if (mounted) showAppSnack(context, e.toString());
        return;
      }
    }

    final BackupSummary summary;
    try {
      summary = service.inspect(json);
    } on FormatException catch (e) {
      if (mounted) showAppSnack(context, e.message);
      return;
    }
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan backup?'),
        content: Text(
          'Backup ${Fmt.dateTime(summary.exportedAt)} berisi '
          '${summary.transactions} transaksi, ${summary.recurring} '
          'transaksi rutin, ${summary.categories} kategori, '
          '${summary.budgets} anggaran, ${summary.goals} target '
          'tabungan, ${summary.wallets} dompet, ${summary.transfers} '
          'transfer, dan ${summary.debts} utang/piutang. Foto struk tidak '
          'ikut dalam backup.\n\nSemua data di HP ini akan DIGANTI dengan isi '
          'backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ganti & pulihkan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await service.restore(json);
    reloadAllData(ref);
    if (mounted) showAppSnack(context, 'Backup berhasil dipulihkan.');
  });

  Future<void> _exportCsv({required bool thisMonth}) => _run(() async {
    final month = ref.read(selectedMonthProvider);
    final list = thisMonth
        ? ref.read(monthTransactionsProvider)
        : ref.read(transactionsProvider);
    if (list.isEmpty) {
      showAppSnack(context, 'Tidak ada transaksi untuk diekspor.');
      return;
    }
    final suffix = thisMonth
        ? DateFormat('yyyy-MM').format(month)
        : 'semua-$_stamp';
    await _shareFile(
      'transaksi-$suffix.csv',
      BackupService.transactionsCsv(list),
      'Transaksi ${thisMonth ? Fmt.month(month) : 'semua bulan'}',
    );
  });

  @override
  Widget build(BuildContext context) {
    final last = ref.watch(lastBackupProvider);
    final month = ref.watch(selectedMonthProvider);
    final scheme = Theme.of(context).colorScheme;
    final p = context.palette;
    final stale =
        last == null ||
        ref.read(clockProvider)().difference(last) > const Duration(days: 30);

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Ekspor')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (_busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            // Status backup terakhir.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: stale ? null : p.heroGradient,
                color: stale ? scheme.errorContainer : null,
                borderRadius: BorderRadius.circular(AppRadius.hero),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconTile(
                        icon: stale
                            ? Icons.warning_amber_rounded
                            : Icons.verified_rounded,
                        color: stale ? p.expense : Colors.white,
                        background: stale ? null : const Color(0x33FFFFFF),
                        size: 48,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          last == null
                              ? 'Belum pernah backup'
                              : 'Backup terakhir ${Fmt.dateTime(last)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: stale
                                ? scheme.onErrorContainer
                                : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Data hanya tersimpan di HP ini. Simpan file backup ke '
                    'Google Drive / WhatsApp secara berkala.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: stale
                          ? scheme.onErrorContainer
                          : Colors.white.withValues(alpha: .9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Backup'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Transaksi, dompet, anggaran, target & utang dalam satu file '
                      'yang bisa dikunci kata sandi. Foto struk tidak ikut.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _backup,
                      icon: const Icon(Icons.backup_rounded),
                      label: const Text('Buat backup & bagikan'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _restore,
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Pulihkan dari file backup'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Ekspor ke Excel (CSV)'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: IconTile(
                      icon: Icons.table_view_rounded,
                      color: p.income,
                    ),
                    title: Text('Transaksi ${Fmt.month(month)}'),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: p.inkMuted,
                    ),
                    onTap: () => _exportCsv(thisMonth: true),
                  ),
                  const Divider(indent: 72, endIndent: 16),
                  ListTile(
                    leading: IconTile(
                      icon: Icons.table_chart_rounded,
                      color: p.info,
                    ),
                    title: const Text('Semua transaksi'),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: p.inkMuted,
                    ),
                    onTap: () => _exportCsv(thisMonth: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog kata sandi backup baru (ketik dua kali). Mengembalikan kata sandi,
/// `''` untuk backup tanpa kata sandi, atau `null` bila batal.
class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog();

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _hidden = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kunci backup dengan kata sandi?'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Disarankan bila file disimpan di Drive atau dikirim lewat '
              'WhatsApp. Kata sandi TIDAK bisa dipulihkan bila lupa.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _hidden,
              decoration: InputDecoration(
                labelText: 'Kata sandi (min. 6 karakter)',
                suffixIcon: IconButton(
                  tooltip: _hidden ? 'Tampilkan' : 'Sembunyikan',
                  icon: Icon(
                    _hidden ? Icons.visibility_outlined : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ),
              validator: (v) =>
                  (v ?? '').length < 6 ? 'Minimal 6 karakter' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirm,
              obscureText: _hidden,
              decoration: const InputDecoration(labelText: 'Ulangi kata sandi'),
              validator: (v) =>
                  v != _password.text ? 'Kata sandi tidak sama' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Tanpa sandi'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _password.text);
            }
          },
          child: const Text('Kunci & bagikan'),
        ),
      ],
    );
  }
}
