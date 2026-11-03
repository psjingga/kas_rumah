import 'package:hive_ce/hive_ce.dart';

import '../../domain/entities/recurring_transaction.dart';
import '../../domain/entities/transaction.dart';

/// Adapter Hive untuk [RecurringTransaction]. Aturannya sama dengan
/// `TransactionAdapter`: enum disimpan sebagai nama, kolom baru di akhir.
class RecurringAdapter extends TypeAdapter<RecurringTransaction> {
  static const id = 1;

  @override
  final int typeId = id;

  @override
  RecurringTransaction read(BinaryReader reader) {
    final id = reader.readString();
    final title = reader.readString();
    final amount = reader.readDouble();
    // Jenis dibaca dulu: dibutuhkan untuk penanda kategori.
    final type = TransactionType.values.byName(reader.readString());
    final category = TransactionCategory.byId(reader.readString(), type);
    final dayOfMonth = reader.readByte();
    final startMonth = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final active = reader.readBool();
    bool more() => reader.availableBytes > 0;
    // v2: ID dompet (opsional; data lama tidak punya).
    final walletId = more() && reader.readBool() ? reader.readString() : null;
    // v3: frekuensi, hari, bulan, jumlah cicilan.
    final frequency = more()
        ? RecurrenceFrequency.values.byName(reader.readString())
        : RecurrenceFrequency.monthly;
    final weekday = more() ? reader.readByte() : DateTime.monday;
    final monthOfYear = more() ? reader.readByte() : 1;
    final total = more() && reader.readBool() ? reader.readInt() : null;
    return RecurringTransaction(
      id: id,
      title: title,
      amount: amount,
      type: type,
      category: category,
      dayOfMonth: dayOfMonth,
      startMonth: startMonth,
      active: active,
      walletId: walletId,
      frequency: frequency,
      weekday: weekday,
      monthOfYear: monthOfYear,
      totalOccurrences: total,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringTransaction obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.title)
      ..writeDouble(obj.amount)
      ..writeString(obj.type.name)
      ..writeString(obj.category.id)
      ..writeByte(obj.dayOfMonth)
      ..writeInt(obj.startMonth.millisecondsSinceEpoch)
      ..writeBool(obj.active)
      ..writeBool(obj.walletId != null);
    if (obj.walletId case final id?) writer.writeString(id);
    writer
      ..writeString(obj.frequency.name)
      ..writeByte(obj.weekday)
      ..writeByte(obj.monthOfYear)
      ..writeBool(obj.totalOccurrences != null);
    if (obj.totalOccurrences case final n?) writer.writeInt(n);
  }
}
