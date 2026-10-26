import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../providers.dart';

class LockState {
  const LockState({
    this.enabled = false,
    this.locked = false,
    this.biometric = false,
  });
  final bool enabled, locked, biometric;
  LockState copy({bool? enabled, bool? locked, bool? biometric}) => LockState(
    enabled: enabled ?? this.enabled,
    locked: locked ?? this.locked,
    biometric: biometric ?? this.biometric,
  );
}

class AppLockController extends StateNotifier<LockState> {
  AppLockController(this.prefs)
    : super(
        LockState(
          enabled: prefs.getBool('lock_enabled') ?? false,
          locked: prefs.getBool('lock_enabled') ?? false,
          biometric: prefs.getBool('lock_bio') ?? false,
        ),
      );
  final SharedPreferences prefs;
  static const _secure = FlutterSecureStorage();
  static String _hash(String pin) =>
      sha256.convert(utf8.encode('cb-lock:$pin')).toString();

  Future<void> enable(String pin, {required bool biometric}) async {
    await _secure.write(key: 'lock_pin', value: _hash(pin));
    await prefs.setBool('lock_enabled', true);
    await prefs.setBool('lock_bio', biometric);
    state = LockState(enabled: true, locked: false, biometric: biometric);
  }

  Future<void> disable() async {
    await _secure.delete(key: 'lock_pin');
    await prefs.setBool('lock_enabled', false);
    await prefs.setBool('lock_bio', false);
    state = const LockState();
  }

  Future<bool> verify(String pin) async =>
      (await _secure.read(key: 'lock_pin')) == _hash(pin);

  void lock() {
    if (state.enabled) state = state.copy(locked: true);
  }

  void unlock() => state = state.copy(locked: false);

  Future<bool> biometricAvailable() async {
    try {
      final a = LocalAuthentication();
      return await a.isDeviceSupported() && await a.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> tryBiometric() async {
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: 'Unlock Clever Bill',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false; // plugin not available (e.g. web) – PIN still works
    }
  }
}

final appLockProvider = StateNotifierProvider<AppLockController, LockState>(
  (ref) => AppLockController(ref.watch(prefsProvider)),
);

/// Wraps the app: locks again when it returns from background (after 20 s) and shows the PIN screen.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AppLockGate> createState() => _GateState();
}

class _GateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;

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
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (s == AppLifecycleState.resumed && _pausedAt != null) {
      if (DateTime.now().difference(_pausedAt!).inSeconds >= 20)
        ref.read(appLockProvider.notifier).lock();
      _pausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    final authed = ref.watch(
      authProvider.select((a) => a.status == AuthStatus.authenticated),
    );
    return Stack(
      children: [
        widget.child,
        if (lock.enabled && lock.locked && authed)
          const Positioned.fill(child: PinLockScreen()),
      ],
    );
  }
}

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});
  @override
  ConsumerState<PinLockScreen> createState() => _PinLockState();
}

class _PinLockState extends ConsumerState<PinLockScreen> {
  String _pin = '';
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(appLockProvider).biometric)
      WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  Future<void> _bio() async {
    if (await ref.read(appLockProvider.notifier).tryBiometric())
      ref.read(appLockProvider.notifier).unlock();
  }

  Future<void> _tap(String d) async {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _wrong = false;
    });
    if (_pin.length == 4) {
      if (await ref.read(appLockProvider.notifier).verify(_pin)) {
        ref.read(appLockProvider.notifier).unlock();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _pin = '';
          _wrong = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: C.bg,
    child: SafeArea(
      child: Column(
        children: [
          const Spacer(),
          Icon(Icons.lock_outline_rounded, size: 44, color: C.primary),
          const SizedBox(height: 12),
          const Text(
            'Enter PIN',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? C.primary : Colors.transparent,
                    border: Border.all(
                      color: _wrong ? C.danger : C.primary,
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 26,
            child: _wrong
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Incorrect PIN',
                      style: TextStyle(
                        color: C.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
          ),
          const Spacer(),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final d in row) _Key(label: d, onTap: () => _tap(d)),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Key(
                icon: ref.watch(appLockProvider).biometric
                    ? Icons.fingerprint
                    : null,
                onTap: ref.read(appLockProvider).biometric ? _bio : null,
              ),
              _Key(label: '0', onTap: () => _tap('0')),
              _Key(
                icon: Icons.backspace_outlined,
                onTap: () => setState(
                  () => _pin = _pin.isEmpty
                      ? ''
                      : _pin.substring(0, _pin.length - 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, this.onTap});
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: SizedBox(
      width: 72,
      height: 72,
      child: onTap == null && label == null
          ? null
          : InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: label != null
                    ? Text(
                        label!,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Icon(icon, size: 28, color: C.primary),
              ),
            ),
    ),
  );
}

/// Enable / disable flows used by Settings → Security & privacy.
Future<void> toggleAppLock(BuildContext context, WidgetRef ref) async {
  final ctl = ref.read(appLockProvider.notifier);
  if (ref.read(appLockProvider).enabled) {
    final pin = await _askPin(context, 'Enter PIN');
    if (pin == null) return;
    if (await ctl.verify(pin)) {
      await ctl.disable();
      if (context.mounted) toast(context, 'App lock disabled');
    } else if (context.mounted) {
      toast(context, 'Incorrect PIN', error: true);
    }
    return;
  }
  final a = await _askPin(context, 'Set a 4-digit PIN');
  if (a == null) return;
  if (!context.mounted) return;
  final b = await _askPin(context, 'Confirm PIN');
  if (b == null) return;
  if (a != b) {
    if (context.mounted) toast(context, 'PINs do not match', error: true);
    return;
  }
  final bio = await ctl.biometricAvailable();
  await ctl.enable(a, biometric: bio);
  if (context.mounted) toast(context, 'App lock enabled');
}

Future<String?> _askPin(BuildContext context, String title) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        obscureText: true,
        maxLength: 4,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 26, letterSpacing: 12),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(ctx, c.text.length == 4 ? c.text : null),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
