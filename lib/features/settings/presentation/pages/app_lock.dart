import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_providers.dart';
import '../widgets/pin_pad.dart';

/// Membungkus seluruh aplikasi: menampilkan layar kunci di atas isi
/// aplikasi saat terkunci, dan mengunci lagi setelah aplikasi lama di latar
/// belakang (lihat [AppLockNotifier.lockAfter]).
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockedProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        lock.onBackground();
      case AppLifecycleState.resumed:
        lock.onForeground();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockedProvider);
    return Stack(
      children: [
        // Isi aplikasi tetap hidup (state tidak hilang) tapi tidak bisa
        // disentuh dan disembunyikan dari pembaca layar saat terkunci.
        ExcludeSemantics(
          excluding: locked,
          child: AbsorbPointer(absorbing: locked, child: widget.child),
        ),
        if (locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}

/// Layar kunci: PIN atau sidik jari.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String? _error;
  var _attempts = 0;

  @override
  void initState() {
    super.initState();
    // Langsung tawarkan sidik jari bila diaktifkan.
    if (ref.read(securityProvider).biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  Future<void> _biometric() =>
      ref.read(appLockedProvider.notifier).unlockWithBiometric();

  void _submit(String pin) {
    if (ref.read(appLockedProvider.notifier).unlockWithPin(pin)) return;
    setState(() {
      _attempts++;
      _error = 'PIN salah ($_attempts×)';
    });
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: scheme.primary),
                const SizedBox(height: 12),
                Text(
                  'Kas Rumah',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text('Masukkan PIN untuk membuka'),
                const SizedBox(height: 24),
                PinPad(
                  length: security.pinLength,
                  error: _error,
                  onCompleted: _submit,
                  onBiometric: security.biometric ? _biometric : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
