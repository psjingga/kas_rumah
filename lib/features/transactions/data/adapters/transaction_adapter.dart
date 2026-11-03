import 'package:hive_ce/hive_ce.dart';

import '../../domain/entities/transaction.dart';

/// Adapter Hive untuk [Transaction], ditulis manual (tanpa build_runner).
///
/// Enum disimpan sebagai **nama** (bukan index) supaya urutan enum boleh
/// diubah tanpa merusak data lama. Tanggal disimpan sebagai epoch milidetik.
///
/// Kolom baru selalu ditambahkan di **akhir** dan dibaca hanya bila byte-nya
/// ada, sehingga record versi lama (tanpa `recurringId`) tetap terbaca.
class TransactionAdapter extends TypeAdapter<Transaction> {
  /// ID tipe harus unik di seluruh aplikasi dan tidak boleh diubah
  /// setelah rilis.
  static const id = 0;

  @override
  final int typeId = id;

  @override
  Transaction read(BinaryReader reader) {
    final id = reader.readString();
    final title = reader.readString();
    final amount = reader.readDouble();
    // Jenis dibaca dulu: dibutuhkan untuk penanda kategori.
    final type = TransactionType.values.byName(reader.readString());
    return Transaction(
      id: id,
      title: title,
      amount: amount,
      type: type,
      category: TransactionCategory.byId(reader.readString(), type),
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      // v2: ID transaksi rutin (opsional).
      recurringId: reader.availableBytes > 0 && reader.readBool()
          ? reader.readString()
          : null,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    // Urutan tulis harus sama persis dengan urutan baca di [read].
    writer
      ..writeString(obj.id)
      ..writeString(obj.title)
      ..writeDouble(obj.amount)
      ..writeString(obj.type.name)
      ..writeString(obj.category.id)
      ..writeInt(obj.date.millisecondsSinceEpoch)
      ..writeBool(obj.recurringId != null);
    if (obj.recurringId case final id?) writer.writeString(id);
  }
}
