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
    final category = TransactionCategory.byId(reader.readString(), type);
    final date = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    // v2: ID transaksi rutin (opsional).
    String? optional() => reader.availableBytes > 0 && reader.readBool()
        ? reader.readString()
        : null;
    final recurringId = optional();
    // v3: ID dompet (opsional).
    final walletId = optional();
    // v4: catatan & foto struk (opsional).
    final note = optional() ?? '';
    final photoPath = optional();
    return Transaction(
      id: id,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
      recurringId: recurringId,
      walletId: walletId,
      note: note,
      photoPath: photoPath,
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
      ..writeInt(obj.date.millisecondsSinceEpoch);
    // Kolom opsional: penanda bool lalu nilainya.
    void optional(String? v) {
      writer.writeBool(v != null);
      if (v != null) writer.writeString(v);
    }

    optional(obj.recurringId);
    optional(obj.walletId);
    optional(obj.note.isEmpty ? null : obj.note);
    optional(obj.photoPath);
  }
}
