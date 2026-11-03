import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/home_tab.dart';
import '../features/budgets/presentation/pages/budgets_tab.dart';
import '../features/goals/presentation/pages/goal_pages.dart';
import '../features/goals/presentation/pages/goals_tab.dart';
import '../features/reminders/presentation/pages/notifications_page.dart';
import '../features/reminders/presentation/providers/reminder_providers.dart';
import '../features/settings/presentation/pages/more_tab.dart';
import '../features/transactions/presentation/pages/history_tab.dart';
import '../features/transactions/presentation/pages/summary_tab.dart';
import '../features/transactions/presentation/pages/transaction_search_page.dart';
import '../features/transactions/presentation/providers/transaction_providers.dart';
import '../features/transactions/presentation/widgets/transaction_actions.dart';

/// Kerangka utama dengan navigasi bawah: Ringkasan, Riwayat, Anggaran,
/// Tabungan, Lainnya. App bar & tombol tambah menyesuaikan tab aktif.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

typedef _Tab = ({
  String title,
  String label,
  IconData icon,
  IconData selectedIcon,
  Widget body,
});

class _HomeShellState extends ConsumerState<HomeShell> {
  int get _index => ref.watch(homeTabProvider).index;

  static const List<_Tab> _tabs = [
    (
      title: 'Ringkasan',
      label: 'Ringkasan',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      body: SummaryTab(),
    ),
    (
      title: 'Riwayat',
      label: 'Riwayat',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      body: HistoryTab(),
    ),
    (
      title: 'Anggaran',
      label: 'Anggaran',
      icon: Icons.pie_chart_outline,
      selectedIcon: Icons.pie_chart,
      body: BudgetsTab(),
    ),
    (
      title: 'Target Tabungan',
      label: 'Tabungan',
      icon: Icons.savings_outlined,
      selectedIcon: Icons.savings,
      body: GoalsTab(),
    ),
    (
      title: 'Lainnya',
      label: 'Lainnya',
      icon: Icons.menu,
      selectedIcon: Icons.menu_open,
      body: MoreTab(),
    ),
  ];

  /// Tombol tambah sesuai tab; `null` = tanpa tombol.
  Widget? _fab() => switch (_index) {
    0 || 1 => FloatingActionButton.extended(
      onPressed: () =>
          openTransactionForm(context, month: ref.read(selectedMonthProvider)),
      icon: const Icon(Icons.add),
      label: const Text('Transaksi'),
    ),
    2 => FloatingActionButton.extended(
      onPressed: () => pickCategoryForBudget(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Anggaran'),
    ),
    3 => FloatingActionButton.extended(
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const GoalFormPage())),
      icon: const Icon(Icons.add),
      label: const Text('Target'),
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationsProvider);
    final tab = _tabs[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(tab.title),
        actions: [
          IconButton(
            tooltip: 'Cari transaksi',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TransactionSearchPage(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notifikasi',
            icon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsPage(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _fab(),
      // IndexedStack menjaga posisi scroll tiap tab saat berpindah.
      body: IndexedStack(
        index: _index,
        children: [for (final t in _tabs) t.body],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) =>
            ref.read(homeTabProvider.notifier).select(HomeTab.values[i]),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
