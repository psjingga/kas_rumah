import 'package:flutter/material.dart';

import '../../transactions/domain/entities/transaction.dart';

/// Jenis dompet.
enum WalletType {
  cash('Tunai', Icons.payments_outlined),
  bank('Bank', Icons.account_balance_outlined),
  ewallet('E-wallet', Icons.smartphone_outlined),
  other('Lainnya', Icons.account_balance_wallet_outlined);

  const WalletType(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Tempat uang disimpan: tunai, rekening bank, e-wallet, dll. Dicatat
/// manual (tidak tersambung ke bank).
@immutable
class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.type,
    required this.colorValue,
    this.initialBalance = 0,
    this.archived = false,
  });

  /// Dompet bawaan. Semua transaksi tanpa dompet (data lama) masuk ke sini.
  static const mainId = 'main';

  static const main = Wallet(
    id: mainId,
    name: 'Dompet Utama',
    type: WalletType.cash,
    colorValue: 0xFF00796B,
  );

  final String id;
  final String name;
  final WalletType type;
  final int colorValue;

  /// Saldo saat dompet mulai dicatat.
  final double initialBalance;

  /// Diarsipkan: tidak muncul di pilihan & daftar utama.
  final bool archived;

  Color get color => Color(colorValue);

  Wallet copyWith({
    String? name,
    WalletType? type,
    int? colorValue,
    double? initialBalance,
    bool? archived,
  }) => Wallet(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    colorValue: colorValue ?? this.colorValue,
    initialBalance: initialBalance ?? this.initialBalance,
    archived: archived ?? this.archived,
  );

  @override
  bool operator ==(Object other) =>
      other is Wallet &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.colorValue == colorValue &&
      other.initialBalance == initialBalance &&
      other.archived == archived;

  @override
  int get hashCode =>
      Object.hash(id, name, type, colorValue, initialBalance, archived);
}

/// Perpindahan uang antar-dompet, atau penyesuaian saldo bila salah satu
/// sisi kosong. **Bukan** pemasukan/pengeluaran, jadi tidak memengaruhi
/// ringkasan, grafik, maupun anggaran.
@immutable
class Transfer {
  const Transfer({
    required this.id,
    required this.amount,
    required this.date,
    this.fromWalletId,
    this.toWalletId,
    this.note = '',
    this.debtId,
  }) : assert(amount > 0),
       assert(fromWalletId != null || toWalletId != null);

  final String id;

  /// Dompet asal; `null` = penyesuaian yang menambah saldo [toWalletId].
  final String? fromWalletId;

  /// Dompet tujuan; `null` = penyesuaian yang mengurangi [fromWalletId].
  final String? toWalletId;
  final double amount;
  final DateTime date;
  final String note;

  /// Diisi bila perpindahan uang ini berasal dari utang/piutang (pinjam,
  /// meminjamkan, bayar, terima pelunasan).
  final String? debtId;

  bool get isDebt => debtId != null;

  /// Penyesuaian saldo: satu sisi kosong dan bukan dari utang/piutang.
  bool get isAdjustment =>
      !isDebt && (fromWalletId == null || toWalletId == null);

  /// Perubahan saldo [walletId] akibat transfer ini.
  double effectOn(String walletId) =>
      (toWalletId == walletId ? amount : 0) -
      (fromWalletId == walletId ? amount : 0);

  @override
  bool operator ==(Object other) =>
      other is Transfer &&
      other.id == id &&
      other.fromWalletId == fromWalletId &&
      other.toWalletId == toWalletId &&
      other.amount == amount &&
      other.date == date &&
      other.note == note &&
      other.debtId == debtId;

  @override
  int get hashCode =>
      Object.hash(id, fromWalletId, toWalletId, amount, date, note, debtId);
}

/// Hitung saldo semua dompet: saldo awal + pemasukan − pengeluaran ±
/// transfer. Transaksi tanpa dompet dihitung ke [Wallet.mainId].
///
/// Bila [asOf] diisi, transaksi & transfer **setelah** waktu itu (mis.
/// tagihan bulan depan yang sudah dicatat) belum dihitung, karena uangnya
/// belum benar-benar masuk/keluar.
Map<String, double> walletBalances({
  required Iterable<Wallet> wallets,
  required Iterable<Transaction> transactions,
  required Iterable<Transfer> transfers,
  DateTime? asOf,
}) {
  final balances = {for (final w in wallets) w.id: w.initialBalance};
  void add(String id, double v) => balances[id] = (balances[id] ?? 0) + v;
  bool counted(DateTime d) => asOf == null || !d.isAfter(asOf);

  for (final t in transactions) {
    if (counted(t.date)) add(t.walletId ?? Wallet.mainId, t.signedAmount);
  }
  for (final tr in transfers.where((t) => counted(t.date))) {
    if (tr.fromWalletId case final from?) add(from, -tr.amount);
    if (tr.toWalletId case final to?) add(to, tr.amount);
  }
  return balances;
}

/// Kontrak penyimpanan dompet & transfer.
abstract interface class WalletRepository {
  List<Wallet> getWallets();

  Future<void> replaceWallets(List<Wallet> wallets);

  List<Transfer> getTransfers();

  Future<void> saveTransfer(Transfer transfer);

  Future<void> deleteTransfer(String id);

  Future<void> replaceTransfers(List<Transfer> transfers);
}
