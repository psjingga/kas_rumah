import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../wallets/presentation/providers/wallet_providers.dart';
import '../../domain/debt.dart';

final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => throw UnimplementedError(
    'debtRepositoryProvider harus di-override di ProviderScope',
  ),
);

/// Semua utang-piutang (terbaru dulu).
final debtsProvider = NotifierProvider<DebtsNotifier, List<Debt>>(
  DebtsNotifier.new,
);

/// Sisa utang saya & sisa piutang (yang belum lunas).
final debtTotalsProvider = Provider<({double iOwe, double theyOwe})>((ref) {
  var iOwe = 0.0;
  var theyOwe = 0.0;
  for (final d in ref.watch(debtsProvider)) {
    if (d.iOwe) {
      iOwe += d.remaining;
    } else {
      theyOwe += d.remaining;
    }
  }
  return (iOwe: iOwe, theyOwe: theyOwe);
});

class DebtsNotifier extends Notifier<List<Debt>> {
  static const _uuid = Uuid();

  DebtRepository get _repository => ref.read(debtRepositoryProvider);
  TransfersNotifier get _transfers => ref.read(transfersProvider.notifier);

  @override
  List<Debt> build() =>
      ref.watch(debtRepositoryProvider).getAll()
        ..sort((a, b) => b.date.compareTo(a.date));

  Future<void> _save(List<Debt> debts) async {
    debts.sort((a, b) => b.date.compareTo(a.date));
    await _repository.replaceAll(debts);
    state = debts;
  }

  Debt _byId(String id) => state.firstWhere((d) => d.id == id);

  /// Catat utang/piutang baru. Bila [walletId] diisi, saldo dompet ikut
  /// berubah (pinjam → uang masuk; meminjamkan → uang keluar), tanpa
  /// dihitung sebagai pemasukan/pengeluaran.
  Future<Debt> add({
    required String person,
    required DebtDirection direction,
    required double amount,
    required DateTime date,
    DateTime? dueDate,
    String note = '',
    String? walletId,
  }) async {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    final id = _uuid.v4();
    final name = person.trim();
    final transfer = walletId == null
        ? null
        : await _transfers.recordDebtMovement(
            walletId: walletId,
            amount: amount,
            incoming: direction == DebtDirection.iOwe,
            date: date,
            note: direction == DebtDirection.iOwe
                ? 'Pinjam dari $name'
                : 'Pinjamkan ke $name',
            debtId: id,
          );
    final debt = Debt(
      id: id,
      person: name,
      direction: direction,
      amount: amount,
      date: date,
      dueDate: dueDate,
      note: note.trim(),
      walletId: walletId,
      transferId: transfer?.id,
    );
    await _save([debt, ...state]);
    return debt;
  }

  /// Ubah nama, catatan, atau jatuh tempo.
  Future<void> edit(Debt debt) =>
      _save([for (final d in state) d.id == debt.id ? debt : d]);

  /// Catat pembayaran. Bila [walletId] diisi, saldo dompet ikut berubah
  /// (bayar utang → uang keluar; terima pelunasan → uang masuk).
  Future<void> pay(
    String debtId, {
    required double amount,
    required DateTime date,
    String? walletId,
  }) async {
    final debt = _byId(debtId);
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    if (amount > debt.remaining + 0.5) {
      throw ArgumentError('Melebihi sisa ${debt.remaining}');
    }
    final transfer = walletId == null
        ? null
        : await _transfers.recordDebtMovement(
            walletId: walletId,
            amount: amount,
            incoming: !debt.iOwe,
            date: date,
            note: debt.iOwe
                ? 'Bayar utang ke ${debt.person}'
                : 'Terima pelunasan dari ${debt.person}',
            debtId: debt.id,
          );
    final payment = DebtPayment(
      id: _uuid.v4(),
      amount: amount,
      date: date,
      transferId: transfer?.id,
    );
    await edit(
      debt.copyWith(
        payments: [payment, ...debt.payments]
          ..sort((a, b) => b.date.compareTo(a.date)),
      ),
    );
  }

  /// Batalkan satu pembayaran (perpindahan uang di dompet ikut dihapus).
  Future<void> removePayment(String debtId, String paymentId) async {
    final debt = _byId(debtId);
    final payment = debt.payments.firstWhere((p) => p.id == paymentId);
    if (payment.transferId case final t?) await _transfers.remove(t);
    await edit(
      debt.copyWith(
        payments: [
          for (final p in debt.payments)
            if (p.id != paymentId) p,
        ],
      ),
    );
  }

  /// Hapus utang/piutang beserta semua perpindahan uang terkait.
  Future<void> remove(String debtId) async {
    final debt = _byId(debtId);
    for (final id in [
      ?debt.transferId,
      for (final p in debt.payments) ?p.transferId,
    ]) {
      await _transfers.remove(id);
    }
    await _save([
      for (final d in state)
        if (d.id != debtId) d,
    ]);
  }
}
