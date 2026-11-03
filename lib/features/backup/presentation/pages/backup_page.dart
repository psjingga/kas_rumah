import 'dart:convert';
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

  Future<void> _backup() => _run(() async {
    final json = ref
        .read(backupServiceProvider)
        .exportJson(ref.read(clockProvider)());
    await _shareFile(
      'kas-rumah-backup-$_stamp.json',
      json,
      'Backup Kas Rumah $_stamp',
    );
    await ref.read(lastBackupProvider.notifier).markNow();
  });

  Future<void> _restore() => _run(() async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Pilih file backup');
    if (files.isEmpty) return;
    final json = utf8.decode(await files.first.readAsBytes());
    final service = ref.read(backupServiceProvider);

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
          '${summary.budgets} anggaran, dan ${summary.goals} target '
          'tabungan.\n\nSemua data di HP ini akan DIGANTI dengan isi '
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
    final stale =
        last == null ||
        ref.read(clockProvider)().difference(last) > const Duration(days: 30);

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Ekspor')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            Card(
              color: stale ? scheme.errorContainer : scheme.secondaryContainer,
              child: ListTile(
                leading: Icon(stale ? Icons.warning_amber : Icons.verified),
                title: Text(
                  last == null
                      ? 'Belum pernah backup'
                      : 'Backup terakhir ${Fmt.dateTime(last)}',
                ),
                subtitle: const Text(
                  'Data hanya tersimpan di HP ini. Simpan file backup ke '
                  'Google Drive / WhatsApp secara berkala.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _backup,
              icon: const Icon(Icons.backup_outlined),
              label: const Text('Buat backup & bagikan'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _restore,
              icon: const Icon(Icons.restore),
              label: const Text('Pulihkan dari file backup'),
            ),
            const SizedBox(height: 28),
            Text(
              'Ekspor ke Excel (CSV)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _exportCsv(thisMonth: true),
              icon: const Icon(Icons.table_view_outlined),
              label: Text('Transaksi ${Fmt.month(month)}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _exportCsv(thisMonth: false),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Semua transaksi'),
            ),
          ],
        ),
      ),
    );
  }
}
