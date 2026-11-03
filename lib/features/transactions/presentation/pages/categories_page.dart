import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/transaction_category.dart';
import '../providers/category_providers.dart';
import '../providers/recurring_providers.dart';
import '../providers/transaction_providers.dart';
import '../widgets/form_fields.dart';
import '../widgets/style_picker.dart';
import '../widgets/transaction_actions.dart';

/// Daftar kategori bawaan & buatan sendiri, per jenis.
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  void _open(BuildContext context, [TransactionCategory? initial]) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CategoryFormPage(initial: initial),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kategori'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pengeluaran'),
              Tab(text: 'Pemasukan'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _open(context),
          icon: const Icon(Icons.add),
          label: const Text('Kategori'),
        ),
        body: TabBarView(
          children: [
            for (final type in [
              TransactionType.expense,
              TransactionType.income,
            ])
              ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final c in ref.watch(categoriesOfTypeProvider(type)))
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: c.color.withValues(alpha: .15),
                        child: Icon(c.icon, color: c.color, size: 20),
                      ),
                      title: Text(c.label),
                      subtitle: c.builtIn ? const Text('Bawaan') : null,
                      trailing: c.builtIn
                          ? const Icon(Icons.lock_outline, size: 18)
                          : const Icon(Icons.chevron_right),
                      onTap: c.builtIn ? null : () => _open(context, c),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Tambah / ubah kategori buatan sendiri.
class CategoryFormPage extends ConsumerStatefulWidget {
  const CategoryFormPage({super.key, this.initial});

  final TransactionCategory? initial;

  @override
  ConsumerState<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends ConsumerState<CategoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.label);
  late var _type = widget.initial?.type ?? TransactionType.expense;
  late var _iconKey = widget.initial?.iconKey ?? 'label';
  late var _color = widget.initial?.color ?? CategoryStyle.colors[3];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Nama wajib diisi';
    if (name.length > 30) return 'Maksimal 30 karakter';
    final duplicate = ref
        .read(categoriesOfTypeProvider(_type))
        .any(
          (c) =>
              c.id != widget.initial?.id &&
              c.label.toLowerCase() == name.toLowerCase(),
        );
    return duplicate ? 'Nama kategori sudah ada' : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(customCategoriesProvider.notifier);
    if (widget.initial case final c?) {
      await notifier.edit(
        c.copyWith(label: _name.text.trim(), iconKey: _iconKey, color: _color),
      );
    } else {
      await notifier.add(
        label: _name.text,
        type: _type,
        iconKey: _iconKey,
        color: _color,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(TransactionCategory c) async {
    final used =
        ref.read(transactionsProvider).where((t) => t.category == c).length +
        ref.read(recurringProvider).where((r) => r.category == c).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus "${c.label}"?'),
        content: Text(
          used == 0
              ? 'Kategori ini belum dipakai.'
              : 'Dipakai $used transaksi. Transaksinya tetap tersimpan, '
                    'tetapi kategorinya tampil sebagai "Kategori dihapus".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(customCategoriesProvider.notifier).remove(c.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppSnack(context, 'Kategori "${c.label}" dihapus.');
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(initial == null ? 'Kategori Baru' : 'Ubah Kategori'),
        actions: [
          if (initial != null)
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(initial),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Jenis tidak bisa diubah setelah dibuat (transaksi lama
            // sudah tercatat sebagai jenis tersebut).
            if (initial == null) ...[
              TypeSelector(
                value: _type,
                onChanged: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: 20),
            ],
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nama kategori',
                hintText: 'Mis. Arisan',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: _color,
                    child: Icon(
                      CategoryStyle.icons[_iconKey],
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              validator: _validateName,
            ),
            const SizedBox(height: 20),
            Text('Warna', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            ColorPicker(
              selected: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 20),
            Text('Ikon', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            IconPicker(
              selected: _iconKey,
              color: _color,
              onChanged: (k) => setState(() => _iconKey = k),
            ),
            const SizedBox(height: 24),
            SaveButton(saving: false, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
