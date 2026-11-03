import 'package:hive_ce/hive_ce.dart';

import '../domain/debt.dart';

/// Menyimpan utang-piutang sebagai list map di box `settings`.
class HiveDebtRepository implements DebtRepository {
  const HiveDebtRepository(this._box);

  final Box<dynamic> _box;

  static const _key = 'debts';

  static DateTime? _date(Object? ms) =>
      ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;

  static Map<String, Object?> toMap(Debt d) => {
    'id': d.id,
    'person': d.person,
    'direction': d.direction.name,
    'amount': d.amount,
    'date': d.date.millisecondsSinceEpoch,
    'dueDate': d.dueDate?.millisecondsSinceEpoch,
    'note': d.note,
    'walletId': d.walletId,
    'transferId': d.transferId,
    'payments': [
      for (final p in d.payments)
        {
          'id': p.id,
          'amount': p.amount,
          'date': p.date.millisecondsSinceEpoch,
          'transferId': p.transferId,
        },
    ],
  };

  static Debt fromMap(Map<dynamic, dynamic> m) => Debt(
    id: m['id'] as String,
    person: m['person'] as String,
    direction: DebtDirection.values.byName(m['direction'] as String),
    amount: (m['amount'] as num).toDouble(),
    date: _date(m['date'])!,
    dueDate: _date(m['dueDate']),
    note: m['note'] as String? ?? '',
    walletId: m['walletId'] as String?,
    transferId: m['transferId'] as String?,
    payments: [
      for (final p
          in (m['payments'] as List? ?? const [])
              .whereType<Map<dynamic, dynamic>>())
        DebtPayment(
          id: p['id'] as String,
          amount: (p['amount'] as num).toDouble(),
          date: _date(p['date'])!,
          transferId: p['transferId'] as String?,
        ),
    ],
  );

  @override
  List<Debt> getAll() => [
    for (final m
        in (_box.get(_key) as List? ?? const [])
            .whereType<Map<dynamic, dynamic>>())
      fromMap(m),
  ];

  @override
  Future<void> replaceAll(List<Debt> debts) =>
      _box.put(_key, [for (final d in debts) toMap(d)]);
}
