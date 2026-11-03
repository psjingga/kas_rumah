import 'package:flutter/material.dart' show DateUtils, immutable;

/// Arah utang-piutang.
enum DebtDirection {
  /// Saya meminjam uang (harus membayar).
  iOwe('Utang saya', 'Saya pinjam dari'),

  /// Orang lain meminjam uang saya (akan menerima).
  theyOwe('Piutang', 'Dipinjam oleh');

  const DebtDirection(this.label, this.personLabel);

  final String label;

  /// Awalan nama orang: "Saya pinjam dari Bu RT" / "Dipinjam oleh Pak Budi".
  final String personLabel;
}

/// Satu pembayaran (cicilan pelunasan) utang/piutang.
@immutable
class DebtPayment {
  const DebtPayment({
    required this.id,
    required this.amount,
    required this.date,
    this.transferId,
  });

  final String id;
  final double amount;
  final DateTime date;

  /// Perpindahan uang di dompet, bila pembayaran dicatat ke dompet.
  final String? transferId;

  @override
  bool operator ==(Object other) =>
      other is DebtPayment &&
      other.id == id &&
      other.amount == amount &&
      other.date == date &&
      other.transferId == transferId;

  @override
  int get hashCode => Object.hash(id, amount, date, transferId);
}

/// Utang (saya pinjam) atau piutang (orang pinjam ke saya).
@immutable
class Debt {
  const Debt({
    required this.id,
    required this.person,
    required this.direction,
    required this.amount,
    required this.date,
    this.dueDate,
    this.note = '',
    this.walletId,
    this.transferId,
    this.payments = const [],
  }) : assert(amount > 0);

  final String id;

  /// Nama orang/pihak, mis. "Bu RT".
  final String person;
  final DebtDirection direction;

  /// Nominal pinjaman awal.
  final double amount;

  /// Tanggal pinjam.
  final DateTime date;

  /// Tanggal harus lunas (opsional).
  final DateTime? dueDate;
  final String note;

  /// Dompet tempat uang pinjaman masuk/keluar (opsional).
  final String? walletId;

  /// Perpindahan uang awal di dompet, bila dicatat ke dompet.
  final String? transferId;

  /// Pembayaran, terbaru lebih dulu.
  final List<DebtPayment> payments;

  bool get iOwe => direction == DebtDirection.iOwe;
  double get paid => payments.fold(0, (s, p) => s + p.amount);
  double get remaining => (amount - paid).clamp(0, double.infinity);
  double get progress => (paid / amount).clamp(0, 1);
  bool get isSettled => remaining < 0.5;

  /// Lewat jatuh tempo dan belum lunas.
  bool isOverdue(DateTime now) =>
      !isSettled &&
      dueDate != null &&
      dueDate!.isBefore(DateUtils.dateOnly(now));

  Debt copyWith({
    String? person,
    String? note,
    DateTime? Function()? dueDate,
    List<DebtPayment>? payments,
  }) => Debt(
    id: id,
    person: person ?? this.person,
    direction: direction,
    amount: amount,
    date: date,
    dueDate: dueDate == null ? this.dueDate : dueDate(),
    note: note ?? this.note,
    walletId: walletId,
    transferId: transferId,
    payments: payments ?? this.payments,
  );

  @override
  bool operator ==(Object other) =>
      other is Debt &&
      other.id == id &&
      other.person == person &&
      other.direction == direction &&
      other.amount == amount &&
      other.date == date &&
      other.dueDate == dueDate &&
      other.note == note &&
      other.walletId == walletId &&
      other.transferId == transferId &&
      _listEquals(other.payments, payments);

  static bool _listEquals(List<DebtPayment> a, List<DebtPayment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    person,
    direction,
    amount,
    date,
    dueDate,
    note,
    walletId,
    transferId,
    Object.hashAll(payments),
  );
}

/// Kontrak penyimpanan utang-piutang.
abstract interface class DebtRepository {
  List<Debt> getAll();

  Future<void> replaceAll(List<Debt> debts);
}
