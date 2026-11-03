import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../budgets/presentation/providers/budget_providers.dart';
import '../../../goals/presentation/providers/goal_providers.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';
import '../../../transactions/presentation/providers/category_providers.dart';
import '../../../transactions/presentation/providers/recurring_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../data/backup_service.dart';

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    transactions: ref.watch(transactionRepositoryProvider),
    recurring: ref.watch(recurringRepositoryProvider),
    categories: ref.watch(categoryRepositoryProvider),
    budgets: ref.watch(budgetRepositoryProvider),
    goals: ref.watch(goalRepositoryProvider),
    reminderSettings: ref.watch(reminderSettingsRepositoryProvider),
  ),
);

/// Muat ulang semua data dari penyimpanan setelah backup dipulihkan.
void reloadAllData(WidgetRef ref) {
  ref
    ..invalidate(customCategoriesProvider)
    ..invalidate(transactionsProvider)
    ..invalidate(recurringProvider)
    ..invalidate(budgetLimitsProvider)
    ..invalidate(goalsProvider)
    ..invalidate(reminderSettingsProvider);
}
