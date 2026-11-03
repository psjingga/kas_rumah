import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/month.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/reports.dart';

/// Tahun yang ditampilkan di laporan tahunan.
final reportYearProvider = NotifierProvider<ReportYearNotifier, int>(
  ReportYearNotifier.new,
);

final yearReportProvider = Provider<YearReport>(
  (ref) => YearReport.from(
    ref.watch(transactionsProvider),
    ref.watch(reportYearProvider),
  ),
);

/// Dua bulan yang dibandingkan; awalnya bulan lalu vs bulan ini.
final comparedMonthsProvider =
    NotifierProvider<ComparedMonthsNotifier, (DateTime, DateTime)>(
      ComparedMonthsNotifier.new,
    );

final monthComparisonProvider = Provider<MonthComparison>((ref) {
  final (a, b) = ref.watch(comparedMonthsProvider);
  return MonthComparison.from(ref.watch(transactionsProvider), a, b);
});

class ReportYearNotifier extends Notifier<int> {
  @override
  int build() => ref.read(clockProvider)().year;

  void previous() => state--;
  void next() => state++;
}

class ComparedMonthsNotifier extends Notifier<(DateTime, DateTime)> {
  @override
  (DateTime, DateTime) build() {
    final now = ref.read(clockProvider)().firstOfMonth;
    return (now.addMonths(-1), now);
  }

  void setFirst(DateTime month) => state = (month.firstOfMonth, state.$2);
  void setSecond(DateTime month) => state = (state.$1, month.firstOfMonth);
}
