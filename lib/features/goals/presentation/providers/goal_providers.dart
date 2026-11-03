import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/goal_repository.dart';
import '../../domain/savings_goal.dart';

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => throw UnimplementedError(
    'goalRepositoryProvider harus di-override di ProviderScope',
  ),
);

/// Semua target tabungan.
final goalsProvider = NotifierProvider<GoalsNotifier, List<SavingsGoal>>(
  GoalsNotifier.new,
);

class GoalsNotifier extends Notifier<List<SavingsGoal>> {
  static const _uuid = Uuid();

  GoalRepository get _repository => ref.read(goalRepositoryProvider);

  @override
  List<SavingsGoal> build() => ref.watch(goalRepositoryProvider).getAll();

  Future<void> _save(List<SavingsGoal> goals) async {
    await _repository.replaceAll(goals);
    state = goals;
  }

  Future<SavingsGoal> add({
    required String name,
    required double target,
    required String iconKey,
    required int colorValue,
    DateTime? deadline,
  }) async {
    if (target <= 0) throw ArgumentError.value(target, 'target');
    final goal = SavingsGoal(
      id: _uuid.v4(),
      name: name.trim(),
      target: target,
      iconKey: iconKey,
      colorValue: colorValue,
      deadline: deadline,
    );
    await _save([...state, goal]);
    return goal;
  }

  Future<void> edit(SavingsGoal goal) =>
      _save([for (final g in state) g.id == goal.id ? goal : g]);

  /// Hapus target. Transaksi yang pernah ikut dicatat tetap disimpan.
  Future<void> remove(String id) => _save([
    for (final g in state)
      if (g.id != id) g,
  ]);

  /// Setor ([amount] > 0) atau tarik ([amount] < 0) tabungan.
  ///
  /// Bila [recordTransaction], dibuat juga transaksi kategori "Tabungan"
  /// (pengeluaran) atau "Ambil Tabungan" (pemasukan), sehingga sisa saldo
  /// bulanan ikut mencerminkan uang yang dipindahkan.
  Future<void> deposit(
    String goalId, {
    required double amount,
    required DateTime date,
    bool recordTransaction = true,
    String? walletId,
  }) async {
    if (amount == 0) throw ArgumentError.value(amount, 'amount');
    final goal = state.firstWhere((g) => g.id == goalId);

    String? transactionId;
    if (recordTransaction) {
      final withdraw = amount < 0;
      final t = await ref
          .read(transactionsProvider.notifier)
          .add(
            title: '${withdraw ? 'Ambil' : 'Setor'} tabungan: ${goal.name}',
            amount: amount.abs(),
            type: withdraw ? TransactionType.income : TransactionType.expense,
            category: withdraw
                ? TransactionCategory.savingsWithdrawal
                : TransactionCategory.savings,
            date: date,
            walletId: walletId,
          );
      transactionId = t.id;
    }

    final entry = GoalDeposit(
      id: _uuid.v4(),
      amount: amount,
      date: date,
      transactionId: transactionId,
    );
    await edit(
      goal.copyWith(
        deposits: [entry, ...goal.deposits]
          ..sort((a, b) => b.date.compareTo(a.date)),
      ),
    );
  }

  /// Batalkan satu setoran; transaksi terkaitnya ikut dihapus.
  Future<void> removeDeposit(String goalId, String depositId) async {
    final goal = state.firstWhere((g) => g.id == goalId);
    final target = goal.deposits.firstWhere((d) => d.id == depositId);
    if (target.transactionId case final tid?) {
      await ref.read(transactionsProvider.notifier).remove(tid);
    }
    await edit(
      goal.copyWith(
        deposits: [
          for (final d in goal.deposits)
            if (d.id != depositId) d,
        ],
      ),
    );
  }
}
