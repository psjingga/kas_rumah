import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/month.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/recurring_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../providers/settings_providers.dart';
import 'security_page.dart';

/// Satu transaksi rutin yang disiapkan di halaman pembuka.
typedef _Draft = ({
  String title,
  TransactionCategory category,
  double amount,
  int day,
});

/// Tagihan umum rumah tangga untuk dipilih cepat.
const _presets = <(String, TransactionCategory)>[
  ('Listrik', TransactionCategory.bills),
  ('Air PDAM', TransactionCategory.bills),
  ('Internet', TransactionCategory.bills),
  ('Pulsa / Data', TransactionCategory.bills),
  ('Cicilan', TransactionCategory.bills),
  ('SPP Sekolah', TransactionCategory.education),
  ('Arisan', TransactionCategory.otherExpense),
];

/// Halaman pembuka (sekali saja): kenalan dengan aplikasi, isi pemasukan
/// & tagihan rutin, lalu opsi memasang PIN. Semua langkah boleh dilewati.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pages = PageController();
  var _step = 0;
  var _saving = false;

  // Langkah 2: pemasukan rutin.
  final _incomeTitle = TextEditingController(text: 'Gaji');
  final _incomeAmount = TextEditingController();
  var _incomeDay = 25;

  // Langkah 3: tagihan rutin.
  final _bills = <_Draft>[];

  static const _stepCount = 4;

  @override
  void dispose() {
    _pages.dispose();
    _incomeTitle.dispose();
    _incomeAmount.dispose();
    super.dispose();
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _addBill(String title, TransactionCategory category) async {
    final draft = await showModalBottomSheet<_Draft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BillSheet(title: title, category: category),
    );
    if (draft != null) setState(() => _bills.add(draft));
  }

  Future<void> _setPin() async {
    final pin = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const PinSetupPage()));
    if (pin == null) return;
    await ref.read(securityProvider.notifier).setPin(pin);
    if (mounted) await _finish();
  }

  /// Simpan transaksi rutin yang diisi, lalu masuk ke aplikasi.
  Future<void> _finish() async {
    setState(() => _saving = true);
    final recurring = ref.read(recurringProvider.notifier);
    final month = ref.read(clockProvider)().firstOfMonth;
    final income = Fmt.parseAmount(_incomeAmount.text);
    if (income != null && income > 0) {
      await recurring.add(
        title: _incomeTitle.text.trim().isEmpty ? 'Gaji' : _incomeTitle.text,
        amount: income,
        type: TransactionType.income,
        category: TransactionCategory.salary,
        dayOfMonth: _incomeDay,
        startMonth: month,
      );
    }
    for (final b in _bills) {
      await recurring.add(
        title: b.title,
        amount: b.amount,
        type: TransactionType.expense,
        category: b.category,
        dayOfMonth: b.day,
        startMonth: month,
      );
    }
    await ref.read(onboardingDoneProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Indikator langkah + tombol lewati.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _stepCount; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _step ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? scheme.primary
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : _finish,
                    child: const Text('Lewati'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _welcome(context),
                  _incomeStep(context),
                  _billsStep(context),
                  _securityStep(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepLayout(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
    required Widget action,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, size: 32, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(width: double.infinity, child: action),
        ),
      ],
    );
  }

  Widget _welcome(BuildContext context) => _stepLayout(
    context,
    icon: Icons.home_outlined,
    title: 'Selamat datang di Kas Rumah',
    subtitle:
        'Catatan keuangan keluarga yang sederhana. Semua data '
        'tersimpan di HP ini, tanpa akun.',
    children: const [
      _Benefit(
        icon: Icons.receipt_long_outlined,
        text: 'Catat pemasukan & pengeluaran, lihat sisa saldo tiap bulan',
      ),
      _Benefit(
        icon: Icons.event_repeat,
        text: 'Tagihan rutin diingatkan sebelum jatuh tempo',
      ),
      _Benefit(
        icon: Icons.pie_chart_outline,
        text: 'Anggaran per kategori & target tabungan',
      ),
    ],
    action: FilledButton(onPressed: () => _go(1), child: const Text('Mulai')),
  );

  Widget _incomeStep(BuildContext context) => _stepLayout(
    context,
    icon: Icons.work_outline,
    title: 'Pemasukan rutin',
    subtitle:
        'Berapa gaji atau pemasukan tetap setiap bulan? Boleh '
        'dikosongkan.',
    children: [
      TextField(
        controller: _incomeTitle,
        decoration: const InputDecoration(labelText: 'Nama'),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _incomeAmount,
        keyboardType: TextInputType.number,
        inputFormatters: const [ThousandsInputFormatter()],
        decoration: const InputDecoration(
          labelText: 'Nominal per bulan',
          prefixText: 'Rp ',
        ),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<int>(
        initialValue: _incomeDay,
        decoration: const InputDecoration(labelText: 'Diterima tiap tanggal'),
        items: [
          for (var d = 1; d <= 31; d++)
            DropdownMenuItem(value: d, child: Text('Tanggal $d')),
        ],
        onChanged: (d) => setState(() => _incomeDay = d ?? _incomeDay),
      ),
    ],
    action: FilledButton(onPressed: () => _go(2), child: const Text('Lanjut')),
  );

  Widget _billsStep(BuildContext context) => _stepLayout(
    context,
    icon: Icons.receipt_outlined,
    title: 'Tagihan bulanan',
    subtitle:
        'Pilih tagihan yang dibayar tiap bulan. Kamu akan diingatkan '
        'sebelum jatuh tempo.',
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (title, category) in _presets)
            ActionChip(
              avatar: Icon(category.icon, size: 18, color: category.color),
              label: Text(title),
              onPressed: () => _addBill(title, category),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Lainnya'),
            onPressed: () => _addBill('', TransactionCategory.otherExpense),
          ),
        ],
      ),
      const SizedBox(height: 16),
      for (final (i, b) in _bills.indexed)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(b.category.icon, color: b.category.color),
            title: Text(b.title),
            subtitle: Text('${Fmt.rupiah(b.amount)} · tiap tgl ${b.day}'),
            trailing: IconButton(
              tooltip: 'Hapus ${b.title}',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _bills.removeAt(i)),
            ),
          ),
        ),
    ],
    action: FilledButton(onPressed: () => _go(3), child: const Text('Lanjut')),
  );

  Widget _securityStep(BuildContext context) => _stepLayout(
    context,
    icon: Icons.lock_outline,
    title: 'Kunci dengan PIN?',
    subtitle:
        'Data keuangan bersifat pribadi. Pasang PIN agar hanya kamu '
        'yang bisa membuka aplikasi. Bisa diatur nanti di menu Lainnya.',
    children: const [],
    action: Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _setPin,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Pasang PIN'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _saving ? null : _finish,
            child: const Text('Nanti saja, mulai pakai'),
          ),
        ),
      ],
    ),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

/// Isi nominal & tanggal satu tagihan.
class _BillSheet extends StatefulWidget {
  const _BillSheet({required this.title, required this.category});

  final String title;
  final TransactionCategory category;

  @override
  State<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends State<_BillSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.title);
  final _amount = TextEditingController();
  var _day = 5;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Nama tagihan'),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Nominal per bulan',
                prefixText: 'Rp ',
              ),
              validator: (v) => (Fmt.parseAmount(v ?? '') ?? 0) > 0
                  ? null
                  : 'Isi nominal lebih dari 0',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(labelText: 'Jatuh tempo tiap'),
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(value: d, child: Text('Tanggal $d')),
              ],
              onChanged: (d) => setState(() => _day = d ?? _day),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop<_Draft>(context, (
                  title: _title.text.trim(),
                  category: widget.category,
                  amount: Fmt.parseAmount(_amount.text)!,
                  day: _day,
                ));
              },
              child: const Text('Tambahkan'),
            ),
          ],
        ),
      ),
    );
  }
}
