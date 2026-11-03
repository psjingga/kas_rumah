import 'savings_goal.dart';

/// Kontrak penyimpanan target tabungan.
abstract interface class GoalRepository {
  List<SavingsGoal> getAll();

  Future<void> replaceAll(List<SavingsGoal> goals);
}
