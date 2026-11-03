import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/money_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/wallet.dart';
import '../providers/wallet_providers.dart';

/// Ikon dompet berwarna dalam lingkaran.
class WalletAvatar extends StatelessWidget {
  const WalletAvatar({super.key, required this.wallet, this.radius = 20});

  final Wallet wallet;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: wallet.color.withValues(alpha: .15),
      child: Icon(wallet.type.icon, color: wallet.color, size: radius),
    );
  }
}

/// Dropdown pilih dompet (dompet aktif + saldonya).
class WalletField extends ConsumerWidget {
  const WalletField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Dompet',
    this.exclude,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  /// ID dompet yang tidak boleh dipilih (mis. dompet asal transfer).
  final String? exclude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookup = ref.watch(walletLookupProvider);
    final balances = ref.watch(walletBalancesProvider);
    final options = [
      // Dompet yang diarsipkan tetap ditampilkan untuk data lama.
      if (lookup[value] case final w? when w.archived) w,
      for (final w in ref.watch(activeWalletsProvider))
        if (w.id != exclude) w,
    ];
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$exclude'),
      initialValue: options.any((w) => w.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      validator: (v) => v == null ? 'Pilih dompet' : null,
      items: [
        for (final w in options)
          DropdownMenuItem(
            value: w.id,
            child: Row(
              children: [
                Icon(w.type.icon, color: w.color, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(w.name, overflow: TextOverflow.ellipsis)),
                Text(
                  Fmt.rupiah(balances[w.id] ?? 0),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }
}

/// Baris transfer / penyesuaian saldo di riwayat.
class TransferTile extends ConsumerWidget {
  const TransferTile({
    super.key,
    required this.transfer,
    this.onDelete,
    this.perspectiveWalletId,
  });

  final Transfer transfer;
  final VoidCallback? onDelete;

  /// Bila diisi (halaman detail dompet), nominal diberi tanda +/− sesuai
  /// efeknya ke dompet tersebut.
  final String? perspectiveWalletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = transfer;
    final lookup = ref.watch(walletLookupProvider);
    final scheme = Theme.of(context).colorScheme;
    String name(String? id) => lookup[id]?.name ?? 'Dompet dihapus';

    final title = t.isAdjustment
        ? 'Penyesuaian ${name(t.fromWalletId ?? t.toWalletId)}'
        : '${name(t.fromWalletId)} → ${name(t.toWalletId)}';
    final effect = perspectiveWalletId == null
        ? null
        : t.effectOn(perspectiveWalletId!);
    final amountText = switch (effect) {
      null when t.isAdjustment =>
        t.toWalletId != null ? Fmt.signed(t.amount) : Fmt.signed(-t.amount),
      null => Fmt.rupiah(t.amount),
      final e => Fmt.signed(e),
    };

    final tile = ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(
          t.isAdjustment ? Icons.tune : Icons.swap_horiz,
          color: scheme.onSecondaryContainer,
          size: 20,
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        t.note.isEmpty || t.note == 'Penyesuaian saldo'
            ? (t.isAdjustment ? 'Penyesuaian saldo' : 'Transfer')
            : t.note,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        amountText,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: switch (effect) {
            null => scheme.onSurfaceVariant,
            >= 0 => context.incomeColor,
            _ => context.expenseColor,
          },
        ),
      ),
    );
    if (onDelete == null) return tile;
    return Dismissible(
      key: ValueKey('tr-${t.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete!(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: scheme.errorContainer,
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      child: tile,
    );
  }
}
