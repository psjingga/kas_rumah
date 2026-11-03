import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../transactions/domain/entities/transaction.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/month.dart';
import '../../../transactions/presentation/providers/recurring_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/wallet.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => throw UnimplementedError(
    'walletRepositoryProvider harus di-override di ProviderScope',
  ),
);

/// Semua dompet (termasuk yang diarsipkan). Selalu berisi minimal
/// [Wallet.main], tempat transaksi lama tanpa dompet dihitung.
final walletsProvider = NotifierProvider<WalletsNotifier, List<Wallet>>(
  WalletsNotifier.new,
);

/// Dompet aktif (tidak diarsipkan), untuk pilihan di form.
final activeWalletsProvider = Provider<List<Wallet>>(
  (ref) => [
    for (final w in ref.watch(walletsProvider))
      if (!w.archived) w,
  ],
);

/// ID → dompet.
final walletLookupProvider = Provider<Map<String, Wallet>>(
  (ref) => {for (final w in ref.watch(walletsProvider)) w.id: w},
);

/// Dompet bawaan untuk transaksi baru: dompet aktif pertama.
final defaultWalletProvider = Provider<Wallet>(
  (ref) => ref.watch(activeWalletsProvider).firstOrNull ?? Wallet.main,
);

/// Semua transfer & penyesuaian saldo (terbaru dulu).
final transfersProvider = NotifierProvider<TransfersNotifier, List<Transfer>>(
  TransfersNotifier.new,
);

/// Transfer di bulan terpilih (untuk riwayat).
final monthTransfersProvider = Provider<List<Transfer>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return [
    for (final t in ref.watch(transfersProvider))
      if (t.date.isSameMonthAs(month)) t,
  ];
});

/// Batas "saat ini" untuk saldo: akhir hari ini. Transaksi bertanggal
/// setelahnya (sudah dicatat untuk bulan depan) belum memengaruhi saldo.
DateTime _endOfToday(Ref ref) {
  final now = ref.read(clockProvider)();
  return DateTime(now.year, now.month, now.day, 23, 59, 59);
}

/// Saldo terkini tiap dompet (sampai hari ini).
final walletBalancesProvider = Provider<Map<String, double>>(
  (ref) => walletBalances(
    wallets: ref.watch(walletsProvider),
    transactions: ref.watch(transactionsProvider),
    transfers: ref.watch(transfersProvider),
    asOf: _endOfToday(ref),
  ),
);

/// Transaksi **bulan berjalan** yang sudah dicatat tetapi tanggalnya setelah
/// hari ini (mis. cicilan tgl 8 padahal hari ini tgl 3). Urut tanggal.
final upcomingThisMonthProvider = Provider<List<Transaction>>((ref) {
  final limit = _endOfToday(ref);
  return [
    for (final t in ref.watch(transactionsProvider))
      if (t.date.isAfter(limit) && t.date.isSameMonthAs(limit)) t,
  ]..sort((a, b) => a.date.compareTo(b.date));
});

/// Perkiraan uang di akhir bulan berjalan.
typedef MonthEndForecast = ({
  /// Uang saat ini (semua dompet aktif).
  double now,

  /// Transaksi terjadwal setelah hari ini s/d akhir bulan.
  double incoming,
  double outgoing,

  /// [now] + [incoming] − [outgoing].
  double forecast,

  /// Tagihan/pemasukan rutin bulan ini yang belum dicatat (tidak masuk
  /// perkiraan; hanya peringatan).
  int unrecordedCount,
  double unrecordedNet,
});

final monthEndForecastProvider = Provider<MonthEndForecast>((ref) {
  final upcoming = ref.watch(upcomingThisMonthProvider);
  final incoming = upcoming
      .where((t) => t.isIncome)
      .fold(0.0, (s, t) => s + t.amount);
  final outgoing = upcoming
      .where((t) => !t.isIncome)
      .fold(0.0, (s, t) => s + t.amount);
  final now = ref.watch(totalMoneyProvider);

  final month = ref.read(clockProvider)().firstOfMonth;
  final transactions = ref.watch(transactionsProvider);
  final unrecorded = [
    for (final r in ref.watch(recurringProvider))
      for (final o in r.occurrencesIn(month))
        if (!r.isRecordedIn(transactions, o.date)) r,
  ];
  return (
    now: now,
    incoming: incoming,
    outgoing: outgoing,
    forecast: now + incoming - outgoing,
    unrecordedCount: unrecorded.length,
    unrecordedNet: unrecorded.fold(
      0.0,
      (s, r) => s + (r.isIncome ? r.amount : -r.amount),
    ),
  );
});

/// Jumlah transaksi bertanggal setelah hari ini (belum dihitung di saldo).
final upcomingTransactionCountProvider = Provider<int>((ref) {
  final limit = _endOfToday(ref);
  return ref
      .watch(transactionsProvider)
      .where((t) => t.date.isAfter(limit))
      .length;
});

/// Total uang di semua dompet aktif.
final totalMoneyProvider = Provider<double>((ref) {
  final balances = ref.watch(walletBalancesProvider);
  return ref
      .watch(activeWalletsProvider)
      .fold(0.0, (sum, w) => sum + (balances[w.id] ?? 0));
});

class WalletsNotifier extends Notifier<List<Wallet>> {
  static const _uuid = Uuid();

  WalletRepository get _repository => ref.read(walletRepositoryProvider);

  @override
  List<Wallet> build() {
    final stored = ref.watch(walletRepositoryProvider).getWallets();
    return stored.isEmpty ? const [Wallet.main] : stored;
  }

  Future<void> _save(List<Wallet> wallets) async {
    await _repository.replaceWallets(wallets);
    state = wallets;
  }

  Future<Wallet> add({
    required String name,
    required WalletType type,
    required int colorValue,
    double initialBalance = 0,
  }) async {
    final wallet = Wallet(
      id: 'w-${_uuid.v4()}',
      name: name.trim(),
      type: type,
      colorValue: colorValue,
      initialBalance: initialBalance,
    );
    await _save([...state, wallet]);
    return wallet;
  }

  Future<void> edit(Wallet wallet) =>
      _save([for (final w in state) w.id == wallet.id ? wallet : w]);

  /// Apakah dompet pernah dipakai transaksi, transaksi rutin, atau transfer.
  bool isUsed(String id) {
    bool own(String? walletId) => (walletId ?? Wallet.mainId) == id;
    return ref.read(transactionsProvider).any((t) => own(t.walletId)) ||
        ref.read(recurringProvider).any((r) => own(r.walletId)) ||
        ref
            .read(transfersProvider)
            .any((t) => t.fromWalletId == id || t.toWalletId == id);
  }

  /// Hapus dompet yang belum pernah dipakai. Dompet yang sudah dipakai
  /// cukup diarsipkan agar riwayatnya tetap utuh.
  Future<void> remove(String id) {
    if (isUsed(id)) {
      throw StateError('Dompet sudah dipakai; arsipkan saja');
    }
    if (state.length <= 1) {
      throw StateError('Minimal harus ada satu dompet');
    }
    return _save([
      for (final w in state)
        if (w.id != id) w,
    ]);
  }

  /// Pindahkan dompet ke urutan pertama (menjadi dompet bawaan).
  Future<void> makeDefault(String id) => _save([
    ...state.where((w) => w.id == id),
    ...state.where((w) => w.id != id),
  ]);
}

class TransfersNotifier extends Notifier<List<Transfer>> {
  static const _uuid = Uuid();

  WalletRepository get _repository => ref.read(walletRepositoryProvider);

  @override
  List<Transfer> build() => ref.watch(walletRepositoryProvider).getTransfers();

  Future<void> _put(Transfer t) async {
    await _repository.saveTransfer(t);
    state = [t, ...state.where((x) => x.id != t.id)]
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Pindahkan uang dari [fromWalletId] ke [toWalletId].
  Future<Transfer> transfer({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    if (fromWalletId == toWalletId) {
      throw ArgumentError('Dompet asal dan tujuan harus berbeda');
    }
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    final t = Transfer(
      id: _uuid.v4(),
      fromWalletId: fromWalletId,
      toWalletId: toWalletId,
      amount: amount,
      date: date,
      note: note.trim(),
    );
    await _put(t);
    return t;
  }

  /// Cocokkan saldo [walletId] dengan saldo sebenarnya [actualBalance].
  /// Selisihnya dicatat sebagai penyesuaian; `null` bila sudah sama.
  Future<Transfer?> adjust(
    String walletId, {
    required double actualBalance,
    required DateTime date,
  }) async {
    // Dihitung langsung dari `state` (bukan walletBalancesProvider) agar
    // tidak terjadi ketergantungan melingkar dengan provider ini sendiri.
    final current =
        walletBalances(
          wallets: ref.read(walletsProvider),
          transactions: ref.read(transactionsProvider),
          transfers: state,
          asOf: _endOfToday(ref),
        )[walletId] ??
        0;
    final diff = actualBalance - current;
    if (diff.abs() < 0.5) return null;
    final t = Transfer(
      id: _uuid.v4(),
      fromWalletId: diff < 0 ? walletId : null,
      toWalletId: diff > 0 ? walletId : null,
      amount: diff.abs(),
      date: date,
      note: 'Penyesuaian saldo',
    );
    await _put(t);
    return t;
  }

  /// Catat uang masuk ([incoming]) / keluar dari [walletId] karena
  /// utang/piutang. Tidak dihitung sebagai pemasukan/pengeluaran.
  Future<Transfer> recordDebtMovement({
    required String walletId,
    required double amount,
    required bool incoming,
    required DateTime date,
    required String note,
    required String debtId,
  }) async {
    final t = Transfer(
      id: _uuid.v4(),
      fromWalletId: incoming ? null : walletId,
      toWalletId: incoming ? walletId : null,
      amount: amount,
      date: date,
      note: note,
      debtId: debtId,
    );
    await _put(t);
    return t;
  }

  Future<Transfer?> remove(String id) async {
    final target = state.where((t) => t.id == id).firstOrNull;
    if (target == null) return null;
    state = [
      for (final t in state)
        if (t.id != id) t,
    ];
    await _repository.deleteTransfer(id);
    return target;
  }

  Future<void> restore(Transfer t) => _put(t);
}
