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
    return RecurringTransaction(
      id: id,
      title: title,
      amount: amount,
      type: type,
      category: TransactionCategory.byId(reader.readString(), type),
      dayOfMonth: reader.readByte(),
      startMonth: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      active: reader.readBool(),
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
      ..writeBool(obj.active);
  }
}
