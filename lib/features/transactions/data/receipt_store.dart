import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Menyimpan foto struk/nota di folder aplikasi (`<documents>/receipts`),
/// terpisah dari galeri HP, sehingga tetap ada walau foto aslinya dihapus.
class ReceiptStore {
  const ReceiptStore(this.directory);

  /// Folder penyimpanan foto struk.
  final Directory directory;

  static const _uuid = Uuid();

  /// Salin foto dari [sourcePath] (hasil kamera/galeri); kembalikan path
  /// salinannya.
  Future<String> save(String sourcePath) async {
    await directory.create(recursive: true);
    final ext = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.'))
        : '.jpg';
    final target = File('${directory.path}/${_uuid.v4()}$ext');
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  /// Hapus foto yang tidak lagi dipakai transaksi mana pun (mis. form
  /// dibatalkan setelah memotret, atau transaksinya dihapus).
  Future<int> cleanupOrphans(Set<String> used) async {
    if (!await directory.exists()) return 0;
    var removed = 0;
    await for (final f in directory.list()) {
      if (f is File && !used.contains(f.path)) {
        try {
          await f.delete();
          removed++;
        } catch (e) {
          debugPrint('Gagal menghapus foto lama: $e');
        }
      }
    }
    return removed;
  }
}
