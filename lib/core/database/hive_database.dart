import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../features/transactions/data/adapters/recurring_adapter.dart';
import '../../features/transactions/data/adapters/transaction_adapter.dart';
import '../../features/transactions/domain/entities/recurring_transaction.dart';
import '../../features/transactions/domain/entities/transaction.dart';

/// Box Hive yang sudah terbuka, siap disuntikkan ke repository.
typedef HiveBoxes = ({
  Box<Transaction> transactions,
  Box<RecurringTransaction> recurring,
  Box<dynamic> settings,
});

/// Konfigurasi Hive: inisialisasi, registrasi adapter, dan pembukaan box.
abstract final class HiveDatabase {
  static const transactionsBox = 'transactions';
  static const recurringBox = 'recurring';
  static const settingsBox = 'settings';

  /// Panggil sekali di `main()` sebelum `runApp`.
  static Future<HiveBoxes> init() async {
    // Menyimpan file Hive di direktori dokumen aplikasi.
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(TransactionAdapter.id)) {
      Hive.registerAdapter(TransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(RecurringAdapter.id)) {
      Hive.registerAdapter(RecurringAdapter());
    }

    return (
      transactions: await Hive.openBox<Transaction>(transactionsBox),
      recurring: await Hive.openBox<RecurringTransaction>(recurringBox),
      settings: await Hive.openBox<dynamic>(settingsBox),
    );
  }
}
