import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab di navigasi bawah halaman utama.
enum HomeTab { summary, history, budgets, goals, more }

/// Tab yang sedang aktif. Disimpan di provider agar halaman lain (mis.
/// kartu Anggaran di Ringkasan) bisa memindahkan tab.
final homeTabProvider = NotifierProvider<HomeTabNotifier, HomeTab>(
  HomeTabNotifier.new,
);

class HomeTabNotifier extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.summary;

  void select(HomeTab tab) => state = tab;
}
