import 'package:flutter/foundation.dart';

import '../../../core/utils/month.dart';

/// Satu setoran (positif) atau penarikan (negatif) ke target tabungan.
@immutable
class GoalDeposit {
  const GoalDeposit({
    required this.id,
    required this.amount,
    required this.date,
    this.transactionId,
  });

  final String id;

  /// Positif = setor, negatif = tarik.
  final double amount;
  final DateTime date;

  /// Transaksi yang ikut dicatat (kategori Tabungan / Ambil Tabungan), bila
  /// pengguna memilih mencatatnya.
  final String? transactionId;

  bool get isWithdrawal => amount < 0;

  @override
  bool operator ==(Object other) =>
      other is GoalDeposit &&
      other.id == id &&
      other.amount == amount &&
      other.date == date &&
      other.transactionId == transactionId;

  @override
  int get hashCode => Object.hash(id, amount, date, transactionId);
}

/// Target tabungan, mis. "Dana darurat Rp 10 juta".
@immutable
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.iconKey,
    required this.colorValue,
    this.deadline,
    this.deposits = const [],
  });

  final String id;
  final String name;
  final double target;

  /// Kunci ikon di `CategoryStyle.icons`.
  final String iconKey;
  final int colorValue;

  /// Target tanggal tercapai (opsional).
  final DateTime? deadline;

  /// Riwayat setoran/penarikan, terbaru lebih dulu.
  final List<GoalDeposit> deposits;

  double get saved => deposits.fold(0, (sum, d) => sum + d.amount);
  double get remaining => (target - saved).clamp(0, double.infinity);
  double get progress => target <= 0 ? 0 : (saved / target).clamp(0, 1);
  bool get isReached => saved >= target;

  /// Setoran yang dibutuhkan per bulan agar tercapai tepat waktu, dihitung
  /// dari bulan [now] sampai bulan [deadline] (inklusif). `null` bila tanpa
  /// tenggat atau sudah tercapai.
  double? monthlyNeeded(DateTime now) {
    final d = deadline;
    if (d == null || isReached) return null;
    final months = (d.year - now.year) * 12 + d.month - now.month + 1;
    return remaining / (months < 1 ? 1 : months);
  }

  /// Total setoran bersih di bulan [month].
  double savedIn(DateTime month) => deposits
      .where((d) => d.date.isSameMonthAs(month))
      .fold(0, (sum, d) => sum + d.amount);

  SavingsGoal copyWith({
    String? name,
    double? target,
    String? iconKey,
    int? colorValue,
    DateTime? Function()? deadline,
    List<GoalDeposit>? deposits,
  }) => SavingsGoal(
    id: id,
    name: name ?? this.name,
    target: target ?? this.target,
    iconKey: iconKey ?? this.iconKey,
    colorValue: colorValue ?? this.colorValue,
    deadline: deadline == null ? this.deadline : deadline(),
    deposits: deposits ?? this.deposits,
  );

  @override
  bool operator ==(Object other) =>
      other is SavingsGoal &&
      other.id == id &&
      other.name == name &&
      other.target == target &&
      other.iconKey == iconKey &&
      other.colorValue == colorValue &&
      other.deadline == deadline &&
      listEquals(other.deposits, deposits);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    target,
    iconKey,
    colorValue,
    deadline,
    Object.hashAll(deposits),
  );
}
