import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/money_colors.dart';
import '../../../../core/widgets/warm_widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/wallet.dart';
import '../providers/wallet_providers.dart';

/// Ikon dompet berwarna dalam kotak pastel.
class WalletAvatar extends StatelessWidget {
  const WalletAvatar({super.key, required this.wallet, this.radius = 20});

  final Wallet wallet;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return IconTile(
      icon: wallet.type.icon,
      color: wallet.color,
      size: radius * 2,
    );
  }
}

/// Pilih dompet berupa chip (dompet aktif + saldonya).
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
    final p = context.palette;
    final selected = options.any((w) => w.id == value) ? value : null;
    return FormField<String>(
      key: ValueKey('$label-$exclude-$selected'),
      initialValue: selected,
      validator: (_) => selected == null ? 'Pilih dompet' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in options)
                Semantics(
                  button: true,
                  selected: w.id == selected,
                  child: InkWell(
                    onTap: () => onChanged(w.id),
                    borderRadius: BorderRadius.circular(AppRadius.box),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                      decoration: BoxDecoration(
                        color: w.id == selected ? p.primarySoft : p.surface,
                        borderRadius: BorderRadius.circular(AppRadius.box),
                        border: Border.all(
                          color: w.id == selected ? p.primary : p.border,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconTile(icon: w.type.icon, color: w.color, size: 32),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                w.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                Fmt.rupiah(balances[w.id] ?? 0),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: p.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (field.errorText case final e?)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(e, style: TextStyle(color: p.expense, fontSize: 12)),
            ),
        ],
      ),
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

    final title = switch (t) {
      Transfer(isDebt: true) => t.note,
      Transfer(isAdjustment: true) =>
        'Penyesuaian ${name(t.fromWalletId ?? t.toWalletId)}',
      _ => '${name(t.fromWalletId)} → ${name(t.toWalletId)}',
    };
    final effect = perspectiveWalletId == null
        ? null
        : t.effectOn(perspectiveWalletId!);
    final amountText = switch (effect) {
      null when t.isAdjustment || t.isDebt =>
        t.toWalletId != null ? Fmt.signed(t.amount) : Fmt.signed(-t.amount),
      null => Fmt.rupiah(t.amount),
      final e => Fmt.signed(e),
    };

    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: IconTile(
        icon: t.isDebt
            ? Icons.handshake_rounded
            : t.isAdjustment
            ? Icons.tune_rounded
            : Icons.swap_horiz_rounded,
        color: context.palette.info,
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        switch (t) {
          Transfer(isDebt: true) =>
            'Utang/piutang · ${name(t.fromWalletId ?? t.toWalletId)}',
          _ when t.note.isEmpty || t.note == 'Penyesuaian saldo' =>
            t.isAdjustment ? 'Penyesuaian saldo' : 'Transfer',
          _ => t.note,
        },
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        amountText,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
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
        child: Icon(
          Icons.delete_outline_rounded,
          color: scheme.onErrorContainer,
        ),
      ),
      child: tile,
    );
  }
}
