import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recurring_transaction.dart';
import '../../domain/entities/transaction.dart';
import '../pages/transaction_form_page.dart';
import '../providers/transaction_providers.dart';

/// Aksi transaksi yang dipakai di beberapa halaman (dashboard, pencarian).

/// Snackbar yang selalu hilang sendiri setelah beberapa detik.
///
/// Sejak Flutter 3.3x, snackbar yang punya [action] (mis. "Urungkan")
/// secara bawaan *menetap* sampai ditutup; `persist: false` mengembalikan
/// perilaku hilang otomatis.
void showAppSnack(BuildContext context, String text, [SnackBarAction? action]) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        action: action,
        persist: false,
        duration: Duration(seconds: action == null ? 3 : 5),
      ),
    );
}

/// Buka form transaksi: tambah (default), ubah ([initial]), atau catat
/// transaksi rutin ([recurring]) untuk [month].
Future<void> openTransactionForm(
  BuildContext context, {
  required DateTime month,
  Transaction? initial,
  RecurringTransaction? recurring,
  DateTime? occurrenceDate,
}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => TransactionFormPage(
        month: month,
        initial: initial,
        recurring: recurring,
        occurrenceDate: occurrenceDate,
      ),
    ),
  );
  if (saved == true && context.mounted) {
    showAppSnack(context, 'Transaksi tersimpan.');
  }
}

/// Hapus [transaction] lalu tampilkan snackbar "Urungkan".
Future<void> deleteTransactionWithUndo(
  BuildContext context,
  WidgetRef ref,
  Transaction transaction,
) async {
  final notifier = ref.read(transactionsProvider.notifier);
  final removed = await notifier.remove(transaction.id);
  if (removed == null || !context.mounted) return;
  unawaited(HapticFeedback.mediumImpact());

  showAppSnack(
    context,
    '"${removed.title}" dihapus.',
    SnackBarAction(
      label: 'Urungkan',
      onPressed: () => notifier.restore(removed),
    ),
  );
}
