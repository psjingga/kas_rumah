import 'dart:convert';

import '../../wallets/domain/wallet.dart';
import '../../wallets/data/hive_wallet_repository.dart';
import 'package:intl/intl.dart';

import '../../budgets/domain/budget_repository.dart';
import '../../goals/data/hive_goal_repository.dart';
import '../../goals/domain/goal_repository.dart';
import '../../goals/domain/savings_goal.dart';
import '../../reminders/domain/entities/reminder_settings.dart';
import '../../reminders/domain/repositories/reminder_settings_repository.dart';
import '../../transactions/data/repositories/hive_category_repository.dart';
import '../../transactions/domain/entities/recurring_transaction.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/domain/repositories/category_repository.dart';
import '../../transactions/domain/repositories/recurring_repository.dart';
import '../../transactions/domain/repositories/transaction_repository.dart';

/// Jumlah data di dalam sebuah backup.
typedef BackupSummary = ({
  DateTime exportedAt,
  int transactions,
  int recurring,
  int categories,
  int budgets,
  int goals,
  int wallets,
  int transfers,
});

/// Membuat & memulihkan backup lengkap (JSON) serta ekspor CSV.
///
/// Backup berisi semua data: transaksi, transaksi rutin, kategori buatan
/// sendiri, anggaran, target tabungan, dompet & transfer, dan pengaturan
/// pengingat. Versi 1 (sebelum ada dompet) tetap bisa dipulihkan.
class BackupService {
  const BackupService({
    required this.transactions,
    required this.recurring,
    required this.categories,
    required this.budgets,
    required this.goals,
    required this.reminderSettings,
    required this.wallets,
  });

  final TransactionRepository transactions;
  final RecurringRepository recurring;
  final CategoryRepository categories;
  final BudgetRepository budgets;
  final GoalRepository goals;
  final ReminderSettingsRepository reminderSettings;
  final WalletRepository wallets;

  static const _app = 'keuangan_rumah_tangga';

  /// 2 = menambahkan dompet & transfer.
  static const formatVersion = 2;

  // ---------- Backup JSON ----------

  String exportJson(DateTime now) {
    final r = reminderSettings.load();
    return const JsonEncoder.withIndent(' ').convert({
      'app': _app,
      'version': formatVersion,
      'exportedAt': now.toIso8601String(),
      'categories': [
        for (final c in categories.getAll()) HiveCategoryRepository.toMap(c),
      ],
      'transactions': [for (final t in transactions.getAll()) _txToMap(t)],
      'recurring': [for (final x in recurring.getAll()) _recurringToMap(x)],
      'budgets': budgets.getLimits(),
      'goals': [for (final g in goals.getAll()) HiveGoalRepository.toMap(g)],
      'wallets': [
        for (final w in wallets.getWallets())
          HiveWalletRepository.walletToMap(w),
      ],
      'transfers': [
        for (final t in wallets.getTransfers())
          HiveWalletRepository.transferToMap(t),
      ],
      'reminderSettings': {
        'enabled': r.enabled,
        'daysBefore': r.daysBefore,
        'hour': r.hour,
        'minute': r.minute,
        'budgetAlerts': r.budgetAlerts,
      },
    });
  }

  /// Baca ringkasan isi backup tanpa mengubah data.
  /// Melempar [FormatException] (pesan bahasa Indonesia) bila tidak valid.
  BackupSummary inspect(String json) {
    final d = _Decoded.parse(json);
    return (
      exportedAt: d.exportedAt,
      transactions: d.transactions.length,
      recurring: d.recurring.length,
      categories: d.categories.length,
      budgets: d.budgets.length,
      goals: d.goals.length,
      wallets: d.wallets.length,
      transfers: d.transfers.length,
    );
  }

  /// **Ganti** seluruh data dengan isi backup. Semua data diurai dulu, jadi
  /// file yang rusak tidak mengubah apa pun.
  Future<BackupSummary> restore(String json) async {
    final d = _Decoded.parse(json);
    await categories.replaceAll(d.categories);
    await transactions.replaceAll(d.transactions);
    await recurring.replaceAll(d.recurring);
    await budgets.replaceLimits(d.budgets);
    await budgets.saveSentAlerts(const {});
    await goals.replaceAll(d.goals);
    await wallets.replaceWallets(d.wallets);
    await wallets.replaceTransfers(d.transfers);
    if (d.reminderSettings case final s?) await reminderSettings.save(s);
    return inspect(json);
  }

  // ---------- CSV ----------

  /// CSV transaksi (pemisah `;` agar langsung rapi di Excel berbahasa
  /// Indonesia). Nominal tanpa pemisah ribuan.
  static String transactionsCsv(Iterable<Transaction> list) {
    String cell(String v) =>
        v.contains(RegExp(r'[;"\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
    final date = DateFormat('yyyy-MM-dd');
    return [
      'Tanggal;Jenis;Kategori;Judul;Nominal',
      for (final t in list)
        [
          date.format(t.date),
          t.type.label,
          cell(t.category.label),
          cell(t.title),
          t.amount.toStringAsFixed(0),
        ].join(';'),
    ].join('\n');
  }

  // ---------- Kode map ----------

  static Map<String, Object?> _txToMap(Transaction t) => {
    'id': t.id,
    'title': t.title,
    'amount': t.amount,
    'type': t.type.name,
    'category': t.category.id,
    'date': t.date.millisecondsSinceEpoch,
    'recurringId': t.recurringId,
    'walletId': t.walletId,
  };

  static Map<String, Object?> _recurringToMap(RecurringTransaction r) => {
    'id': r.id,
    'title': r.title,
    'amount': r.amount,
    'type': r.type.name,
    'category': r.category.id,
    'dayOfMonth': r.dayOfMonth,
    'startMonth': r.startMonth.millisecondsSinceEpoch,
    'active': r.active,
    'walletId': r.walletId,
  };
}

/// Isi backup yang sudah diurai & divalidasi.
class _Decoded {
  _Decoded._(
    this.exportedAt,
    this.categories,
    this.transactions,
    this.recurring,
    this.budgets,
    this.goals,
    this.reminderSettings,
    this.wallets,
    this.transfers,
  );

  final DateTime exportedAt;
  final List<TransactionCategory> categories;
  final List<Transaction> transactions;
  final List<RecurringTransaction> recurring;
  final Map<String, double> budgets;
  final List<SavingsGoal> goals;
  final ReminderSettings? reminderSettings;
  final List<Wallet> wallets;
  final List<Transfer> transfers;

  static _Decoded parse(String json) {
    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException {
      throw const FormatException('File bukan backup yang valid.');
    }
    if (root is! Map || root['app'] != BackupService._app) {
      throw const FormatException('File ini bukan backup Kas Rumah.');
    }
    if ((root['version'] as int? ?? 0) > BackupService.formatVersion) {
      throw const FormatException(
        'Backup dibuat oleh versi aplikasi yang lebih baru. '
        'Perbarui aplikasi dulu.',
      );
    }

    List<Map<dynamic, dynamic>> list(String key) => (root as Map)[key] is List
        ? (root[key] as List).whereType<Map<dynamic, dynamic>>().toList()
        : const [];

    try {
      final r = root['reminderSettings'];
      return _Decoded._(
        DateTime.tryParse(root['exportedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        [for (final m in list('categories')) HiveCategoryRepository.fromMap(m)],
        [
          for (final m in list('transactions'))
            Transaction(
              id: m['id'] as String,
              title: m['title'] as String,
              amount: (m['amount'] as num).toDouble(),
              type: _type(m),
              category: TransactionCategory.byId(
                m['category'] as String,
                _type(m),
              ),
              date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
              recurringId: m['recurringId'] as String?,
              walletId: m['walletId'] as String?,
            ),
        ],
        [
          for (final m in list('recurring'))
            RecurringTransaction(
              id: m['id'] as String,
              title: m['title'] as String,
              amount: (m['amount'] as num).toDouble(),
              type: _type(m),
              category: TransactionCategory.byId(
                m['category'] as String,
                _type(m),
              ),
              dayOfMonth: m['dayOfMonth'] as int,
              startMonth: DateTime.fromMillisecondsSinceEpoch(
                m['startMonth'] as int,
              ),
              active: m['active'] as bool? ?? true,
              walletId: m['walletId'] as String?,
            ),
        ],
        {
          for (final MapEntry(:key, :value)
              in ((root['budgets'] as Map?) ?? const {}).entries)
            key as String: (value as num).toDouble(),
        },
        [for (final m in list('goals')) HiveGoalRepository.fromMap(m)],
        r is Map
            ? ReminderSettings(
                enabled: r['enabled'] as bool? ?? true,
                daysBefore: r['daysBefore'] as int? ?? 1,
                hour: r['hour'] as int? ?? 8,
                minute: r['minute'] as int? ?? 0,
                budgetAlerts: r['budgetAlerts'] as bool? ?? true,
              )
            : null,
        // v1 belum punya dompet → kosong (dipakai Dompet Utama bawaan).
        [
          for (final m in list('wallets'))
            HiveWalletRepository.walletFromMap(m),
        ],
        [
          for (final m in list('transfers'))
            HiveWalletRepository.transferFromMap(m),
        ],
      );
    } on Object catch (e) {
      // Data di dalamnya tidak lengkap / tipe salah.
      throw FormatException('Isi backup rusak atau tidak lengkap ($e).');
    }
  }

  static TransactionType _type(Map<dynamic, dynamic> m) =>
      TransactionType.values.byName(m['type'] as String);
}
