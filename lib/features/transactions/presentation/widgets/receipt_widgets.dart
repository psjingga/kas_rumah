import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/receipt_store.dart';

/// Penyimpanan foto struk; di-override di `main()` / tes.
final receiptStoreProvider = Provider<ReceiptStore>(
  (ref) => throw UnimplementedError(
    'receiptStoreProvider harus di-override di ProviderScope',
  ),
);

/// Bagian "Foto struk" di form: tombol Kamera/Galeri, atau pratinjau foto
/// dengan tombol hapus. [onChanged] menerima path foto tersimpan / `null`.
class ReceiptPhotoField extends ConsumerStatefulWidget {
  const ReceiptPhotoField({
    super.key,
    required this.path,
    required this.onChanged,
  });

  final String? path;
  final ValueChanged<String?> onChanged;

  @override
  ConsumerState<ReceiptPhotoField> createState() => _ReceiptPhotoFieldState();
}

class _ReceiptPhotoFieldState extends ConsumerState<ReceiptPhotoField> {
  var _busy = false;

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // Cukup tajam untuk dibaca, tapi hemat penyimpanan.
        maxWidth: 1600,
        imageQuality: 75,
      );
      if (picked == null) return;
      final saved = await ref.read(receiptStoreProvider).save(picked.path);
      widget.onChanged(saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    if (path == null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Foto struk'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Dari galeri'),
            ),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReceiptThumbnail(path: path, size: 96),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Foto struk terlampir'),
              TextButton.icon(
                onPressed: () => widget.onChanged(null),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus foto'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Gambar kecil foto struk; ketuk untuk melihat layar penuh.
class ReceiptThumbnail extends StatelessWidget {
  const ReceiptThumbnail({super.key, required this.path, this.size = 64});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Foto struk, ketuk untuk memperbesar',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ReceiptViewer(path: path)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(path),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: size,
              height: size,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }
}

/// Foto struk layar penuh, bisa di-zoom.
class ReceiptViewer extends StatelessWidget {
  const ReceiptViewer({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Foto struk'),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(child: Image.file(File(path))),
      ),
    );
  }
}
