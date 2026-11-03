import 'package:hive_ce/hive_ce.dart';

import '../domain/wallet.dart';

/// Dompet disimpan sebagai list map di box `settings` (jumlahnya sedikit);
/// transfer di box `transfers` (key = ID) karena bisa bertambah banyak.
class HiveWalletRepository implements WalletRepository {
  const HiveWalletRepository(this._settings, this._transfers);

  final Box<dynamic> _settings;
  final Box<dynamic> _transfers;

  static const _walletsKey = 'wallets';

  static Map<String, Object?> walletToMap(Wallet w) => {
    'id': w.id,
    'name': w.name,
    'type': w.type.name,
    'color': w.colorValue,
    'initialBalance': w.initialBalance,
    'archived': w.archived,
  };

  static Wallet walletFromMap(Map<dynamic, dynamic> m) => Wallet(
    id: m['id'] as String,
    name: m['name'] as String,
    type: WalletType.values.byName(m['type'] as String),
    colorValue: m['color'] as int,
    initialBalance: (m['initialBalance'] as num? ?? 0).toDouble(),
    archived: m['archived'] as bool? ?? false,
  );

  static Map<String, Object?> transferToMap(Transfer t) => {
    'id': t.id,
    'from': t.fromWalletId,
    'to': t.toWalletId,
    'amount': t.amount,
    'date': t.date.millisecondsSinceEpoch,
    'note': t.note,
    'debtId': t.debtId,
  };

  static Transfer transferFromMap(Map<dynamic, dynamic> m) => Transfer(
    id: m['id'] as String,
    fromWalletId: m['from'] as String?,
    toWalletId: m['to'] as String?,
    amount: (m['amount'] as num).toDouble(),
    date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
    note: m['note'] as String? ?? '',
    debtId: m['debtId'] as String?,
  );

  @override
  List<Wallet> getWallets() => [
    for (final m
        in (_settings.get(_walletsKey) as List? ?? const [])
            .whereType<Map<dynamic, dynamic>>())
      walletFromMap(m),
  ];

  @override
  Future<void> replaceWallets(List<Wallet> wallets) =>
      _settings.put(_walletsKey, [for (final w in wallets) walletToMap(w)]);

  @override
  List<Transfer> getTransfers() => [
    for (final m in _transfers.values.whereType<Map<dynamic, dynamic>>())
      transferFromMap(m),
  ]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<void> saveTransfer(Transfer transfer) =>
      _transfers.put(transfer.id, transferToMap(transfer));

  @override
  Future<void> deleteTransfer(String id) => _transfers.delete(id);

  @override
  Future<void> replaceTransfers(List<Transfer> transfers) async {
    await _transfers.clear();
    await _transfers.putAll({
      for (final t in transfers) t.id: transferToMap(t),
    });
  }
}
