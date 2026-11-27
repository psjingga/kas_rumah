import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/money_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/warm_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transactions/presentation/widgets/form_fields.dart';
import '../../../transactions/presentation/widgets/style_picker.dart';
import '../../../transactions/presentation/widgets/transaction_actions.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
import '../../domain/wallet.dart';
import '../providers/wallet_providers.dart';
import '../widgets/wallet_widgets.dart';

/// Buka form transfer antar-dompet; [from] = dompet asal awal.
Future<void> openTransferForm(BuildContext context, {String? from}) async {
  final saved = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => TransferFormPage(from: from)));
  if (saved == true && context.mounted) {
    showAppSnack(context, 'Transfer tersimpan.');
  }
}

/// Hapus transfer lalu tawarkan "Urungkan".
Future<void> deleteTransferWithUndo(
  BuildContext context,
  WidgetRef ref,
  Transfer transfer,
) async {
  final notifier = ref.read(transfersProvider.notifier);
  final removed = await notifier.remove(transfer.id);
  if (removed == null || !context.mounted) return;
  unawaited(HapticFeedback.mediumImpact());
  showAppSnack(
    context,
    removed.isAdjustment ? 'Penyesuaian dihapus.' : 'Transfer dihapus.',
    SnackBarAction(
      label: 'Urungkan',
      onPressed: () => notifier.restore(removed),
    ),
  );
}

/// Daftar dompet beserta saldonya dan total uang.
class WalletsPage extends ConsumerWidget {
  const WalletsPage({super.key});

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);
    final active = [
      for (final w in wallets)
        if (!w.archived) w,
    ];
    final archived = [
      for (final w in wallets)
        if (w.archived) w,
    ];
    final balances = ref.watch(walletBalancesProvider);
    final total = ref.watch(totalMoneyProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dompet'),
        actions: [
          IconButton(
            tooltip: 'Transfer antar-dompet',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: active.length < 2
                ? null
                : () => openTransferForm(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _push(context, const WalletFormPage()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Dompet'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: context.palette.heroGradient,
              borderRadius: BorderRadius.circular(AppRadius.hero),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total uang saat ini',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Fmt.rupiah(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Jumlah saldo ${active.length} dompet aktif sampai hari ini. '
                  'Transfer antar-dompet tidak dihitung sebagai '
                  'pemasukan/pengeluaran.'
                  '${switch (ref.watch(upcomingTransactionCountProvider)) {
                    0 => '',
                    final n => ' $n transaksi bertanggal mendatang belum dihitung.',
                  }}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: context.palette.inkMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Saldo berbeda dengan uang sebenarnya? Buka dompetnya lalu '
                    'ketuk "Sesuaikan".',
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          for (final type in WalletType.values)
            if (active.where((w) => w.type == type).toList() case final group
                when group.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionLabel(type.label),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (i, w) in group.indexed) ...[
                      if (i > 0) const Divider(indent: 72, endIndent: 16),
                      _WalletRow(
                        wallet: w,
                        balance: balances[w.id] ?? 0,
                        isDefault: w.id == active.first.id,
                        onTap: () =>
                            _push(context, WalletDetailPage(walletId: w.id)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          if (archived.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionLabel('Diarsipkan'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final w in archived)
                    Opacity(
                      opacity: .6,
                      child: _WalletRow(
                        wallet: w,
                        balance: balances[w.id] ?? 0,
                        isDefault: false,
                        onTap: () =>
                            _push(context, WalletDetailPage(walletId: w.id)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({
    required this.wallet,
    required this.balance,
    required this.isDefault,
    required this.onTap,
  });

  final Wallet wallet;
  final double balance;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: WalletAvatar(wallet: wallet),
      title: Text(wallet.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        isDefault ? '${wallet.type.label} · Bawaan' : wallet.type.label,
      ),
      trailing: Text(
        Fmt.rupiah(balance),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: balance < 0 ? context.expenseColor : context.palette.ink,
        ),
      ),
    );
  }
}

/// Detail satu dompet: saldo, aksi, dan riwayat transaksi + transfer.
class WalletDetailPage extends ConsumerWidget {
  const WalletDetailPage({super.key, required this.walletId});

  final String walletId;

  Future<void> _adjust(BuildContext context, WidgetRef ref, Wallet w) async {
    final current = ref.read(walletBalancesProvider)[w.id] ?? 0;
    final controller = TextEditingController(
      text: current >= 0 ? Fmt.thousands(current) : null,
    );
    final formKey = GlobalKey<FormState>();
    final actual = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sesuaikan saldo'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Isi saldo sebenarnya (mis. dari m-banking). Selisihnya '
                'dicatat sebagai penyesuaian, bukan pemasukan/pengeluaran.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Saldo sebenarnya',
                  prefixText: 'Rp ',
                ),
                validator: (v) => Fmt.parseAmount(v ?? '') == null
                    ? 'Isi saldo (boleh 0)'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, Fmt.parseAmount(controller.text));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (actual == null) return;
    final t = await ref
        .read(transfersProvider.notifier)
        .adjust(w.id, actualBalance: actual, date: ref.read(clockProvider)());
    if (context.mounted) {
      showAppSnack(
        context,
        t == null ? 'Saldo sudah sesuai.' : 'Saldo disesuaikan.',
      );
    }
  }

  Future<void> _archiveOrDelete(
    BuildContext context,
    WidgetRef ref,
    Wallet w,
  ) async {
    final notifier = ref.read(walletsProvider.notifier);
    final used = notifier.isUsed(w.id);
    final balance = ref.read(walletBalancesProvider)[w.id] ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(used ? 'Arsipkan "${w.name}"?' : 'Hapus "${w.name}"?'),
        content: Text(
          used
              ? 'Dompet ini sudah punya riwayat, jadi diarsipkan (disembunyikan) '
                    'agar riwayatnya tetap utuh.'
                    '${balance.abs() >= 1 ? '\n\nSisa saldo ${Fmt.rupiah(balance)} tidak lagi dihitung di total uang. Pindahkan dulu bila perlu.' : ''}'
              : 'Dompet ini belum pernah dipakai.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(used ? 'Arsipkan' : 'Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (used) {
      await notifier.edit(w.copyWith(archived: true));
    } else {
      await notifier.remove(w.id);
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletLookupProvider)[walletId];
    if (wallet == null) return const Scaffold();
    final wallets = ref.watch(walletsProvider);
    final isDefault = ref.watch(defaultWalletProvider).id == walletId;
    final balance = ref.watch(walletBalancesProvider)[walletId] ?? 0;
    final canDelete = wallets.length > 1;

    bool own(String? id) => (id ?? Wallet.mainId) == walletId;
    final items = <(DateTime, Object)>[
      for (final t in ref.watch(transactionsProvider))
        if (own(t.walletId)) (t.date, t),
      for (final t in ref.watch(transfersProvider))
        if (t.fromWalletId == walletId || t.toWalletId == walletId) (t.date, t),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    return Scaffold(
      appBar: AppBar(
        title: Text(wallet.name),
        actions: [
          IconButton(
            tooltip: 'Ubah dompet',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WalletFormPage(initial: wallet),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'default' =>
                ref.read(walletsProvider.notifier).makeDefault(walletId),
              'unarchive' =>
                ref
                    .read(walletsProvider.notifier)
                    .edit(wallet.copyWith(archived: false)),
              _ => _archiveOrDelete(context, ref, wallet),
            },
            itemBuilder: (_) => [
              if (!isDefault && !wallet.archived)
                const PopupMenuItem(
                  value: 'default',
                  child: Text('Jadikan dompet bawaan'),
                ),
              if (wallet.archived)
                const PopupMenuItem(
                  value: 'unarchive',
                  child: Text('Aktifkan lagi'),
                )
              else if (canDelete)
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Arsipkan / hapus'),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            color: Color.alphaBlend(
              wallet.color.withValues(alpha: .10),
              context.palette.surface,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  WalletAvatar(wallet: wallet, radius: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${wallet.type.label}'
                          '${isDefault ? ' · Bawaan' : ''}'
                          '${wallet.archived ? ' · Diarsipkan' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Saldo saat ini',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Fmt.rupiah(balance),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.5,
                              color: balance < 0 ? context.expenseColor : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: wallets.where((w) => !w.archived).length < 2
                      ? null
                      : () => openTransferForm(context, from: walletId),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Transfer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _adjust(context, ref, wallet),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Sesuaikan'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionLabel('Riwayat'),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Belum ada transaksi di dompet ini',
              compact: true,
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, (_, item)) in items.indexed) ...[
                    if (i > 0) const Divider(indent: 72, endIndent: 16),
                    switch (item) {
                      final Transaction t => TransactionTile(
                        key: ValueKey(t.id),
                        transaction: t,
                        onTap: () => openTransactionForm(
                          context,
                          month: t.date,
                          initial: t,
                        ),
                        onDelete: () =>
                            deleteTransactionWithUndo(context, ref, t),
                      ),
                      final Transfer t => TransferTile(
                        key: ValueKey('tr-${t.id}'),
                        transfer: t,
                        perspectiveWalletId: walletId,
                        onDelete: () => deleteTransferWithUndo(context, ref, t),
                      ),
                      _ => const SizedBox.shrink(),
                    },
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tambah / ubah dompet.
class WalletFormPage extends ConsumerStatefulWidget {
  const WalletFormPage({super.key, this.initial});

  final Wallet? initial;

  @override
  ConsumerState<WalletFormPage> createState() => _WalletFormPageState();
}

class _WalletFormPageState extends ConsumerState<WalletFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _initial = TextEditingController(
    text: switch (widget.initial?.initialBalance) {
      final b? when b > 0 => Fmt.thousands(b),
      _ => null,
    },
  );
  late var _type = widget.initial?.type ?? WalletType.bank;
  late var _color = widget.initial?.color ?? CategoryStyle.colors[3];
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final notifier = ref.read(walletsProvider.notifier);
    final initialBalance = Fmt.parseAmount(_initial.text) ?? 0;
    if (widget.initial case final w?) {
      await notifier.edit(
        w.copyWith(
          name: _name.text.trim(),
          type: _type,
          colorValue: _color.toARGB32(),
          initialBalance: initialBalance,
        ),
      );
    } else {
      await notifier.add(
        name: _name.text,
        type: _type,
        colorValue: _color.toARGB32(),
        initialBalance: initialBalance,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Dompet Baru' : 'Ubah Dompet'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<WalletType>(
              showSelectedIcon: false,
              segments: [
                for (final t in WalletType.values)
                  ButtonSegment(
                    value: t,
                    icon: Icon(t.icon),
                    label: Text(t.label),
                  ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nama dompet',
                hintText: switch (_type) {
                  WalletType.cash => 'Mis. Dompet Ibu',
                  WalletType.bank => 'Mis. BCA',
                  WalletType.ewallet => 'Mis. GoPay',
                  WalletType.other => 'Mis. Celengan',
                },
              ),
              validator: (v) {
                final name = v?.trim() ?? '';
                if (name.isEmpty) return 'Nama wajib diisi';
                if (name.length > 30) return 'Maksimal 30 karakter';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _initial,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Saldo awal',
                helperText: 'Saldo saat mulai dicatat (boleh kosong)',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 20),
            Text('Warna', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ColorPicker(
              selected: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 24),
            SaveButton(saving: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// Transfer antar-dompet, mis. tarik tunai BCA → Tunai, top up GoPay.
class TransferFormPage extends ConsumerStatefulWidget {
  const TransferFormPage({super.key, this.from});

  final String? from;

  @override
  ConsumerState<TransferFormPage> createState() => _TransferFormPageState();
}

class _TransferFormPageState extends ConsumerState<TransferFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _from;
  String? _to;
  late DateTime _date;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final active = ref.read(activeWalletsProvider);
    _from = widget.from ?? active.first.id;
    _to = active.where((w) => w.id != _from).firstOrNull?.id;
    _date = DateUtils.dateOnly(ref.read(clockProvider)());
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref
        .read(transfersProvider.notifier)
        .transfer(
          fromWalletId: _from,
          toWalletId: _to!,
          amount: Fmt.parseAmount(_amount.text)!,
          date: _date,
          note: _note.text,
        );
    unawaited(HapticFeedback.lightImpact());
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            WalletField(
              label: 'Dari',
              value: _from,
              // Asal = tujuan → tukar posisi keduanya.
              onChanged: (v) => setState(() {
                if (_to == v) _to = _from;
                _from = v;
              }),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Icon(Icons.arrow_downward),
            ),
            WalletField(
              label: 'Ke',
              value: _to ?? '',
              exclude: _from,
              onChanged: (v) => setState(() => _to = v),
            ),
            const SizedBox(height: 16),
            AmountField(controller: _amount),
            const SizedBox(height: 8),
            QuickAmountChips(controller: _amount),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Mis. Tarik tunai, top up',
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(_date.year + 5),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(Fmt.date(_date)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Transfer tidak dihitung sebagai pemasukan atau pengeluaran.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            SaveButton(saving: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// Kartu "Uang saat ini" di Ringkasan: uang yang benar-benar ada hari ini,
/// saldo tiap dompet, lalu rincian transaksi terjadwal sampai akhir bulan
/// dan perkiraan uang di akhir bulan.
class WalletsSummaryCard extends ConsumerWidget {
  const WalletsSummaryCard({super.key});

  /// Paling banyak sekian transaksi terjadwal yang dirinci.
  static const _maxListed = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(activeWalletsProvider);
    final balances = ref.watch(walletBalancesProvider);
    final upcoming = ref.watch(upcomingThisMonthProvider);
    final f = ref.watch(monthEndForecastProvider);
    final today = ref.read(clockProvider)();
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall;

    Widget row(String label, String value, {Color? color, bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(label, style: textTheme.bodyMedium)),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const WalletsPage())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(
                    icon: Icons.account_balance_wallet_rounded,
                    color: context.palette.info,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Uang saat ini', style: textTheme.titleSmall),
                  ),
                  Text(
                    Fmt.rupiah(f.now),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              Text(
                'Uang yang benar-benar ada per ${Fmt.date(today)}: hanya '
                'transaksi sampai hari ini.',
                style: muted,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final w in wallets)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                        decoration: BoxDecoration(
                          color: context.palette.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.box),
                        ),
                        child: Row(
                          children: [
                            IconTile(
                              icon: w.type.icon,
                              color: w.color,
                              size: 30,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.name, style: textTheme.labelSmall),
                                Text(
                                  Fmt.rupiah(balances[w.id] ?? 0),
                                  style: textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 20),
              Text(
                'Sampai akhir ${Fmt.monthName(today)}',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              if (upcoming.isEmpty)
                Text(
                  'Tidak ada transaksi terjadwal setelah hari ini.',
                  style: muted,
                )
              else ...[
                if (f.incoming > 0)
                  row(
                    'Akan masuk (${upcoming.where((t) => t.isIncome).length})',
                    Fmt.signed(f.incoming),
                    color: context.incomeColor,
                  ),
                if (f.outgoing > 0)
                  row(
                    'Akan keluar (${upcoming.where((t) => !t.isIncome).length})',
                    Fmt.signed(-f.outgoing),
                    color: context.expenseColor,
                  ),
                // Rincian transaksi terjadwal.
                for (final t in upcoming.take(_maxListed))
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: Row(
                      children: [
                        Icon(
                          t.category.icon,
                          size: 14,
                          color: t.category.color,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${t.title} · ${Fmt.date(t.date)}',
                            style: muted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(Fmt.signed(t.signedAmount), style: muted),
                      ],
                    ),
                  ),
                if (upcoming.length > _maxListed)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: Text(
                      'dan ${upcoming.length - _maxListed} transaksi lainnya',
                      style: muted,
                    ),
                  ),
                const SizedBox(height: 6),
                row(
                  'Perkiraan uang akhir bulan',
                  Fmt.rupiah(f.forecast),
                  bold: true,
                  color: f.forecast < 0 ? context.expenseColor : null,
                ),
              ],
              if (f.unrecordedCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: context.warningColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${f.unrecordedCount} transaksi rutin bulan ini belum '
                        'dicatat (${Fmt.signed(f.unrecordedNet)}), belum '
                        'termasuk perkiraan di atas.',
                        style: muted?.copyWith(color: context.warningColor),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
