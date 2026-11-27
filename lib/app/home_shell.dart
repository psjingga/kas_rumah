import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';

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
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      body: SummaryTab(),
    ),
    (
      title: 'Riwayat',
      label: 'Riwayat',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      body: HistoryTab(),
    ),
    (
      title: 'Anggaran',
      label: 'Anggaran',
      icon: Icons.pie_chart_outline_rounded,
      selectedIcon: Icons.pie_chart_rounded,
      body: BudgetsTab(),
    ),
    (
      title: 'Target Tabungan',
      label: 'Tabungan',
      icon: Icons.savings_outlined,
      selectedIcon: Icons.savings_rounded,
      body: GoalsTab(),
    ),
    (
      title: 'Lainnya',
      label: 'Lainnya',
      icon: Icons.more_horiz_rounded,
      selectedIcon: Icons.more_horiz_rounded,
      body: MoreTab(),
    ),
  ];

  /// Tombol tambah sesuai tab; `null` = tanpa tombol.
  Widget? _fab() => switch (_index) {
    0 || 1 => FloatingActionButton.extended(
      onPressed: () =>
          openTransactionForm(context, month: ref.read(selectedMonthProvider)),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Transaksi'),
    ),
    2 => FloatingActionButton.extended(
      onPressed: () => pickCategoryForBudget(context, ref),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Anggaran'),
    ),
    3 => FloatingActionButton.extended(
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const GoalFormPage())),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Target'),
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationsProvider);
    final tab = _tabs[_index];

    // Tab Ringkasan: app bar menyatu dengan hero saldo berwarna madu.
    final hero = _index == 0;
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Text(tab.title),
        backgroundColor: hero ? palette.heroStart : null,
        foregroundColor: hero ? Colors.white : null,
        titleTextStyle: hero
            ? Theme.of(
                context,
              ).appBarTheme.titleTextStyle?.copyWith(color: Colors.white)
            : null,
        systemOverlayStyle: hero ? SystemUiOverlayStyle.light : null,
        actions: [
          IconButton(
            tooltip: 'Cari transaksi',
            icon: const Icon(Icons.search_rounded),
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
              child: const Icon(Icons.notifications_none_rounded),
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
