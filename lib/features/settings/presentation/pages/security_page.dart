import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transactions/presentation/widgets/transaction_actions.dart';
import '../../domain/security.dart';
import '../providers/settings_providers.dart';
import '../widgets/pin_pad.dart';

/// Pengaturan kunci aplikasi: PIN dan sidik jari.
class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});

  /// Minta PIN lama; `true` bila benar.
  static Future<bool> _verify(BuildContext context) async =>
      await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => const PinVerifyPage())) ==
      true;

  Future<void> _togglePin(BuildContext context, WidgetRef ref, bool on) async {
    final notifier = ref.read(securityProvider.notifier);
    if (on) {
      final pin = await Navigator.of(
        context,
      ).push<String>(MaterialPageRoute(builder: (_) => const PinSetupPage()));
      if (pin == null) return;
      await notifier.setPin(pin);
      if (context.mounted) showAppSnack(context, 'Kunci aplikasi aktif.');
    } else if (await _verify(context)) {
      await notifier.removePin();
      if (context.mounted) showAppSnack(context, 'Kunci aplikasi dimatikan.');
    }
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    if (!await _verify(context) || !context.mounted) return;
    final pin = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const PinSetupPage()));
    if (pin == null) return;
    await ref.read(securityProvider.notifier).setPin(pin);
    if (context.mounted) showAppSnack(context, 'PIN diganti.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(securityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kunci Aplikasi')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Kunci dengan PIN'),
            subtitle: const Text(
              'Diminta saat aplikasi dibuka atau setelah 30 detik di latar '
              'belakang',
            ),
            value: s.hasPin,
            onChanged: (on) => _togglePin(context, ref, on),
          ),
          ListTile(
            enabled: s.hasPin,
            leading: const Icon(Icons.password),
            title: const Text('Ubah PIN'),
            onTap: () => _changePin(context, ref),
          ),
          FutureBuilder(
            future: ref.read(biometricAuthProvider).isAvailable(),
            builder: (context, snap) => SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Buka dengan sidik jari / wajah'),
              subtitle: Text(
                snap.data == false
                    ? 'Tidak tersedia di HP ini'
                    : 'PIN tetap bisa dipakai',
              ),
              value: s.hasPin && s.biometric,
              onChanged: s.hasPin && snap.data == true
                  ? (on) => ref.read(securityProvider.notifier).setBiometric(on)
                  : null,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Lupa PIN? Hapus data aplikasi lewat Pengaturan HP lalu pulihkan '
              'dari file backup. Karena itu, buat backup secara berkala.',
            ),
          ),
        ],
      ),
    );
  }
}

/// Buat PIN baru: ketik lalu ulangi. Mengembalikan PIN lewat `pop`.
class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  String? _first;
  String? _error;
  final _pad = GlobalKey<PinPadState>();

  void _onPin(String pin) {
    final first = _first;
    if (first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
    } else if (pin == first) {
      Navigator.of(context).pop(pin);
    } else {
      setState(() {
        _first = null;
        _error = 'PIN tidak sama, ulangi dari awal';
      });
      _pad.currentState?.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirming = _first != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Buat PIN')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                confirming
                    ? 'Ulangi PIN'
                    : 'Buat PIN ${SecuritySettings.minPinLength}–'
                          '${SecuritySettings.maxPinLength} angka',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              PinPad(
                // Mengulang: panjang harus sama dengan PIN pertama.
                key: ValueKey(confirming),
                length: _first?.length,
                minLength: SecuritySettings.minPinLength,
                maxLength: SecuritySettings.maxPinLength,
                error: _error,
                onCompleted: _onPin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minta PIN saat ini; `pop(true)` bila benar.
class PinVerifyPage extends ConsumerStatefulWidget {
  const PinVerifyPage({super.key});

  @override
  ConsumerState<PinVerifyPage> createState() => _PinVerifyPageState();
}

class _PinVerifyPageState extends ConsumerState<PinVerifyPage> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(securityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('PIN saat ini')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: PinPad(
            length: s.pinLength,
            error: _error,
            onCompleted: (pin) => s.verify(pin)
                ? Navigator.of(context).pop(true)
                : setState(() => _error = 'PIN salah'),
          ),
        ),
      ),
    );
  }
}
