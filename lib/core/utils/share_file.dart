import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Tulis [bytes] ke file sementara bernama [name] lalu buka lembar
/// "Bagikan" (WhatsApp, Drive, email, …).
Future<void> shareFile(String name, List<int> bytes, {String? text}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: text),
  );
}
