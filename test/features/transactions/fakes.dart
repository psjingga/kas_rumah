import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:keuangan_rumah_tangga/features/budgets/domain/budget_repository.dart';
import 'package:keuangan_rumah_tangga/features/budgets/presentation/providers/budget_providers.dart';
import 'package:keuangan_rumah_tangga/features/goals/domain/goal_repository.dart';
import 'package:keuangan_rumah_tangga/features/goals/domain/savings_goal.dart';
import 'package:keuangan_rumah_tangga/features/goals/presentation/providers/goal_providers.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/entities/notification_entry.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/entities/planned_reminder.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/entities/reminder_settings.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/repositories/notification_log_repository.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/repositories/reminder_settings_repository.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/services/notification_service.dart';
import 'package:keuangan_rumah_tangga/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:keuangan_rumah_tangga/features/settings/domain/preferences_repository.dart';
import 'package:keuangan_rumah_tangga/features/settings/domain/security.dart';
import 'package:keuangan_rumah_tangga/features/settings/presentation/providers/settings_providers.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/recurring_transaction.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/repositories/category_repository.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/repositories/recurring_repository.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:keuangan_rumah_tangga/features/transactions/presentation/providers/category_providers.dart';
import 'package:keuangan_rumah_tangga/features/transactions/presentation/providers/recurring_providers.dart';
import 'package:keuangan_rumah_tangga/features/transactions/presentation/providers/transaction_providers.dart';

/// "Hari ini" di semua tes: 3 November 2026.
final today = DateTime(2026, 11, 3, 9);

/// Repository transaksi di memori untuk tes, pengganti Hive.
class InMemoryTransactionRepository implements TransactionRepository {
  InMemoryTransactionRepository([Iterable<Transaction> initial = const []])
    : _items = {for (final t in initial) t.id: t};

  final Map<String, Transaction> _items;

  @override
  List<Transaction> getAll() =>
      _items.values.toList()..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<void> save(Transaction transaction) async =>
      _items[transaction.id] = transaction;

  @override
  Future<void> delete(String id) async => _items.remove(id);

  @override
  Future<void> replaceAll(List<Transaction> transactions) async => _items
    ..clear()
    ..addAll({for (final t in transactions) t.id: t});
}

/// Repository transaksi rutin di memori.
class InMemoryRecurringRepository implements RecurringRepository {
  InMemoryRecurringRepository([
    Iterable<RecurringTransaction> initial = const [],
  ]) : _items = {for (final r in initial) r.id: r};

  final Map<String, RecurringTransaction> _items;

  @override
  List<RecurringTransaction> getAll() =>
      _items.values.toList()
        ..sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));

  @override
  Future<void> save(RecurringTransaction recurring) async =>
      _items[recurring.id] = recurring;

  @override
  Future<void> delete(String id) async => _items.remove(id);

  @override
  Future<void> replaceAll(List<RecurringTransaction> recurring) async => _items
    ..clear()
    ..addAll({for (final r in recurring) r.id: r});
}

/// Pengaturan pengingat di memori.
class InMemoryReminderSettingsRepository implements ReminderSettingsRepository {
  ReminderSettings settings = const ReminderSettings();

  @override
  ReminderSettings load() => settings;

  @override
  Future<void> save(ReminderSettings s) async => settings = s;
}

/// Riwayat & jadwal notifikasi di memori.
class InMemoryNotificationLogRepository implements NotificationLogRepository {
  InMemoryNotificationLogRepository([this.inbox = const []]);

  List<NotificationEntry> inbox;
  List<PlannedReminder> scheduled = const [];

  @override
  List<NotificationEntry> loadInbox() => inbox;

  @override
  Future<void> saveInbox(List<NotificationEntry> entries) async =>
      inbox = entries;

  @override
  List<PlannedReminder> loadScheduled() => scheduled;

  @override
  Future<void> saveScheduled(List<PlannedReminder> reminders) async =>
      scheduled = reminders;
}

/// Layanan notifikasi palsu: mencatat panggilan tanpa plugin.
class FakeNotificationService implements NotificationService {
  var permissionRequests = 0;
  final shown = <String>[];
  List<PlannedReminder> scheduled = const [];

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  /// Hasil [isPermissionGranted]; ubah untuk mensimulasikan izin mati.
  var granted = true;

  @override
  Future<bool> isPermissionGranted() async => granted;

  @override
  Future<void> openSettings() async {}

  @override
  void Function(String? payload)? onTap;

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<void> replaceSchedule(List<PlannedReminder> reminders) async =>
      scheduled = reminders;

  @override
  Future<void> showNow({
    required String title,
    required String body,
    int id = 0,
  }) async => shown.add(title);
}

class InMemoryCategoryRepository implements CategoryRepository {
  List<TransactionCategory> items = [];

  @override
  List<TransactionCategory> getAll() => items;

  @override
  Future<void> save(TransactionCategory c) async =>
      items = [...items.where((x) => x.id != c.id), c];

  @override
  Future<void> delete(String id) async =>
      items = [...items.where((x) => x.id != id)];

  @override
  Future<void> replaceAll(List<TransactionCategory> categories) async =>
      items = categories;
}

class InMemoryBudgetRepository implements BudgetRepository {
  Map<String, double> limits = {};
  Set<String> sent = {};

  @override
  Map<String, double> getLimits() => limits;

  @override
  Future<void> replaceLimits(Map<String, double> l) async => limits = l;

  @override
  Set<String> getSentAlerts() => sent;

  @override
  Future<void> saveSentAlerts(Set<String> keys) async => sent = keys;
}

class InMemoryGoalRepository implements GoalRepository {
  List<SavingsGoal> goals = [];

  @override
  List<SavingsGoal> getAll() => goals;

  @override
  Future<void> replaceAll(List<SavingsGoal> g) async => goals = g;
}

class InMemoryPreferencesRepository implements PreferencesRepository {
  @override
  ThemeMode themeMode = ThemeMode.system;

  @override
  DateTime? lastBackupAt;

  @override
  Future<void> setThemeMode(ThemeMode mode) async => themeMode = mode;

  @override
  Future<void> setLastBackupAt(DateTime time) async => lastBackupAt = time;

  /// Default `true` agar tes langsung masuk ke halaman utama.
  @override
  bool onboardingDone = true;

  @override
  Future<void> setOnboardingDone() async => onboardingDone = true;
}

class InMemorySecurityRepository implements SecurityRepository {
  SecuritySettings settings = const SecuritySettings();

  @override
  SecuritySettings load() => settings;

  @override
  Future<void> save(SecuritySettings s) async => settings = s;
}

class FakeBiometricAuth implements BiometricAuth {
  var available = false;
  var succeed = false;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async => succeed;
}

/// Penyimpanan di memori lainnya; buat sendiri bila tes perlu memeriksa
/// atau mengisi isinya.
class TestStores {
  final categories = InMemoryCategoryRepository();
  final budgets = InMemoryBudgetRepository();
  final goals = InMemoryGoalRepository();
  final reminderSettings = InMemoryReminderSettingsRepository();
  final preferences = InMemoryPreferencesRepository();
  final security = InMemorySecurityRepository();
  final biometric = FakeBiometricAuth();
}

/// Override provider untuk tes: repository di memori, notifikasi palsu,
/// dan jam tetap [today].
List<Override> testOverrides(
  TransactionRepository transactions, [
  RecurringRepository? recurring,
  FakeNotificationService? notifications,
  InMemoryNotificationLogRepository? notificationLog,
  DateTime Function()? clock,
  TestStores? stores,
]) => [
  ..._storeOverrides(stores ?? TestStores()),
  transactionRepositoryProvider.overrideWithValue(transactions),
  recurringRepositoryProvider.overrideWithValue(
    recurring ?? InMemoryRecurringRepository(),
  ),
  notificationLogRepositoryProvider.overrideWithValue(
    notificationLog ?? InMemoryNotificationLogRepository(),
  ),
  notificationServiceProvider.overrideWithValue(
    notifications ?? FakeNotificationService(),
  ),
  clockProvider.overrideWithValue(clock ?? () => today),
];

List<Override> _storeOverrides(TestStores s) => [
  categoryRepositoryProvider.overrideWithValue(s.categories),
  budgetRepositoryProvider.overrideWithValue(s.budgets),
  goalRepositoryProvider.overrideWithValue(s.goals),
  reminderSettingsRepositoryProvider.overrideWithValue(s.reminderSettings),
  preferencesRepositoryProvider.overrideWithValue(s.preferences),
  securityRepositoryProvider.overrideWithValue(s.security),
  biometricAuthProvider.overrideWithValue(s.biometric),
];

Transaction tx(
  String id,
  double amount,
  TransactionCategory category, {
  DateTime? date,
  String? recurringId,
}) => Transaction(
  id: id,
  title: 'Transaksi $id',
  amount: amount,
  type: category.type,
  category: category,
  date: date ?? DateTime(2026, 11, 1),
  recurringId: recurringId,
);

/// Template "Listrik" Rp 450.000 tiap tanggal [day], mulai November 2026.
RecurringTransaction listrik({double amount = 450000, int day = 5}) =>
    RecurringTransaction(
      id: 'listrik',
      title: 'Listrik',
      amount: amount,
      type: TransactionType.expense,
      category: TransactionCategory.bills,
      dayOfMonth: day,
      startMonth: DateTime(2026, 11),
    );
