import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../more/language_sheet.dart';
import '../../core/i18n/i18n.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:async';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../providers.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40, this.showTagline = true});
  final double size;
  final bool showTagline;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(size * .18),
            decoration: BoxDecoration(
              color: C.primary,
              borderRadius: BorderRadius.circular(size * .28),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: size * .8,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Clever Bill',
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              color: C.primaryDark,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
      if (showTagline)
        Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Billing  •  Inventory  •  Growth',
            style: TextStyle(color: C.muted, fontSize: 12.5),
          ),
        ),
    ],
  );
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.card,
    body: Center(child: BrandLogo(size: 44)),
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget feature(IconData i, Color c, String t, String s) => Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: c.withOpacity(.14),
            child: Icon(i, color: c),
          ),
          const SizedBox(height: 8),
          Text(
            t,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          Text(
            s,
            textAlign: TextAlign.center,
            style: TextStyle(color: C.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: C.card,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 40),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const BrandLogo(),
                    const Spacer(),
                    Container(
                      width: 250,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: C.card,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: C.primary.withOpacity(.18),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                        border: Border.all(color: C.border),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Clever Bill',
                            style: TextStyle(
                              color: C.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Divider(height: 22),
                          _Row('Rice (5 kg)', '₹350'),
                          _Row('Milk (2 pcs)', '₹120'),
                          _Row('Discount', '- ₹20', green: true),
                          Divider(height: 22),
                          _Row('Total', '₹450', bold: true),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Your shop. Simply managed.',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fast billing, better control, happier customers.',
                      style: TextStyle(color: C.muted),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        feature(
                          Icons.bolt_rounded,
                          C.primary,
                          'Fast billing',
                          'Create bills in seconds',
                        ),
                        feature(
                          Icons.inventory_2_rounded,
                          C.success,
                          'Stock tracking',
                          "Know what's in stock",
                        ),
                        feature(
                          Icons.notifications_active_rounded,
                          C.warning,
                          'Payment reminders',
                          'Get paid on time',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      'Get started',
                      icon: Icons.chevron_right_rounded,
                      onPressed: () => context.push('/auth/phone'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => context.push('/auth/phone'),
                      child: const Text('Sign up'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/auth/phone'),
                      child: const Text(
                        'Already have an account? Sign in',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Consumer(
                      builder: (c, ref, _) => TextButton.icon(
                        onPressed: () => showLanguageSheet(c, ref),
                        icon: Icon(Icons.language, size: 18, color: C.muted),
                        label: Text(
                          I18n.names[ref.watch(languageProvider)] ?? 'English',
                          style: TextStyle(color: C.muted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.a, this.b, {this.bold = false, this.green = false});
  final String a, b;
  final bool bold, green;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          a,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: green ? C.success : C.text,
          ),
        ),
        Text(
          b,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: green ? C.success : C.text,
          ),
        ),
      ],
    ),
  );
}

// ───────────────────────── Phone login ─────────────────────────
class OtpArgs {
  OtpArgs(this.phone, this.verificationId, this.resendToken);
  final String phone;
  final String verificationId;
  final int? resendToken;
}

Future<void> _finishPhoneSignIn(WidgetRef ref, UserCredential uc) async {
  final t = await uc.user!.getIdToken();
  await ref.read(authProvider.notifier).loginPhone(t!);
}

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});
  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginState();
}

class _PhoneLoginState extends ConsumerState<PhoneLoginScreen> {
  final _phone = TextEditingController();
  bool _busy = false;

  Future<void> _send() async {
    final n = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (n.length != 10)
      return toast(
        context,
        'Enter a valid 10-digit mobile number',
        error: true,
      );
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$n',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          try {
            final uc = await FirebaseAuth.instance.signInWithCredential(cred);
            await _finishPhoneSignIn(ref, uc);
          } catch (e) {
            if (mounted) toast(context, '$e', error: true);
          }
        },
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() => _busy = false);
          toast(context, e.message ?? 'Could not send code', error: true);
        },
        codeSent: (id, token) {
          if (!mounted) return;
          setState(() => _busy = false);
          context.push('/auth/otp', extra: OtpArgs('+91 $n', id, token));
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(
          context,
          'Could not send code. Check internet and try again.',
          error: true,
        );
      }
    }
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).loginGoogle();
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.card,
    appBar: AppBar(
      backgroundColor: C.card,
      leading: BackButton(onPressed: () => context.pop()),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Center(child: BrandLogo(size: 34)),
          const SizedBox(height: 40),
          const Text(
            'Sign in to Clever Bill',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your mobile number to continue.',
            style: TextStyle(color: C.muted, fontSize: 16),
          ),
          const SizedBox(height: 26),
          const Text(
            'Mobile number',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: C.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Text(
                      '+91',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 17),
                  decoration: InputDecoration(
                    hintText: tr('98765 43210'),
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            'Continue',
            icon: Icons.chevron_right_rounded,
            loading: _busy,
            onPressed: _send,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: TextStyle(color: C.muted)),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _google,
            style: OutlinedButton.styleFrom(
              foregroundColor: C.text,
              side: BorderSide(color: C.border),
              minimumSize: const Size.fromHeight(54),
            ),
            icon: const Text(
              'G',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFFEA4335),
              ),
            ),
            label: const Text('Continue with Google'),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.push('/auth/email'),
              child: const Text('Use email & password instead'),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => context.push('/auth/register'),
              child: const Text('New here? Create account with email'),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined, color: C.primary, size: 22),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy.',
                  style: TextStyle(color: C.muted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.args});
  final OtpArgs args;
  @override
  ConsumerState<OtpScreen> createState() => _OtpState();
}

class _OtpState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late String _vid = widget.args.verificationId;
  late int? _rtoken = widget.args.resendToken;
  int _secs = 30;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _code.addListener(() => setState(() {}));
  }

  void _startTimer() {
    _secs = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secs <= 0) return t.cancel();
      setState(() => _secs--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (_code.text.length != 6)
      return toast(context, 'Enter the 6-digit code', error: true);
    setState(() => _busy = true);
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _vid,
        smsCode: _code.text,
      );
      final uc = await FirebaseAuth.instance.signInWithCredential(cred);
      await _finishPhoneSignIn(ref, uc);
    } on FirebaseAuthException catch (e) {
      if (mounted)
        toast(
          context,
          e.code == 'invalid-verification-code'
              ? 'Incorrect code'
              : (e.message ?? 'Verification failed'),
          error: true,
        );
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.args.phone.replaceAll(' ', ''),
        forceResendingToken: _rtoken,
        verificationCompleted: (_) {},
        verificationFailed: (e) =>
            toast(context, e.message ?? 'Could not resend', error: true),
        codeSent: (id, t) {
          _vid = id;
          _rtoken = t;
          _startTimer();
          toast(context, 'Code sent again');
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      if (mounted) toast(context, 'Could not resend code', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mm = '00:${_secs.toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: C.card,
      appBar: AppBar(backgroundColor: C.card),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Verify your mobile number',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'We have sent a 6-digit code to',
                style: TextStyle(color: C.muted, fontSize: 15),
              ),
            ),
            Center(
              child: Text(
                widget.args.phone,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              height: 62,
              child: Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 6; i++)
                        Container(
                          width: 48,
                          height: 60,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: C.card,
                            border: Border.all(
                              color: i == _code.text.length
                                  ? C.primary
                                  : C.border,
                              width: i == _code.text.length ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            i < _code.text.length ? _code.text[i] : '',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _code,
                        focusNode: _focus,
                        autofocus: true,
                        maxLength: 6,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (v) {
                          if (v.length == 6) _verify();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: _secs > 0
                  ? Text('Resend code in $mm', style: TextStyle(color: C.muted))
                  : TextButton(
                      onPressed: _resend,
                      child: const Text('Resend code'),
                    ),
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              'Verify & continue',
              icon: Icons.chevron_right_rounded,
              loading: _busy,
              onPressed: _verify,
            ),
            Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: const Text(
                  'Change number',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});
  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailState();
}

class _EmailState extends ConsumerState<EmailLoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false, _hide = true;

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _pw.text.isEmpty)
      return toast(context, 'Enter email and password', error: true);
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).loginEmail(_email.text, _pw.text);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.card,
    appBar: AppBar(backgroundColor: C.card),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'Sign in with email',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 22),
        LabeledField(
          label: 'Email',
          controller: _email,
          keyboard: TextInputType.emailAddress,
        ),
        LabeledField(
          label: 'Password',
          controller: _pw,
          obscure: _hide,
          suffix: IconButton(
            icon: Icon(
              _hide ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            ),
            onPressed: () => setState(() => _hide = !_hide),
          ),
          maxLines: 1,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              if (_email.text.trim().isEmpty)
                return toast(context, 'Enter your email first', error: true);
              try {
                await ref.read(apiProvider).forgotPassword(_email.text.trim());
                if (mounted)
                  toast(context, 'Reset instructions sent to your email');
              } catch (e) {
                if (mounted) toast(context, '$e', error: true);
              }
            },
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 10),
        PrimaryButton('Sign in', loading: _busy, onPressed: _login),
        Center(
          child: TextButton(
            onPressed: () => context.push('/auth/register'),
            child: const Text('New here? Create an account'),
          ),
        ),
      ],
    ),
  );
}

// ───────────────────────── Shop setup (2 steps) ─────────────────────────
final _setupDraft = StateProvider<Map<String, dynamic>>((_) => {});

class ShopSetupScreen extends ConsumerStatefulWidget {
  const ShopSetupScreen({super.key});
  @override
  ConsumerState<ShopSetupScreen> createState() => _ShopSetupState();
}

class _ShopSetupState extends ConsumerState<ShopSetupScreen> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  String _type = 'Grocery';
  Uint8List? _logoBytes;
  String? _logoName;
  static const types = [
    'Grocery',
    'Medical',
    'Clothing',
    'Electronics',
    'Restaurant',
    'Hardware',
    'Stationery',
    'Other',
  ];

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (bytes.isEmpty) return;
    setState(() {
      _logoBytes = bytes;
      _logoName = x.name;
    });
  }

  void _next() {
    if (_name.text.trim().isEmpty)
      return toast(context, 'Enter your shop name', error: true);
    ref.read(_setupDraft.notifier).state = {
      'name': _name.text.trim(),
      'type': _type,
      'city': _city.text.trim(),
      'logoBytes': _logoBytes,
      'logoName': _logoName,
    };
    context.push('/setup/billing');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.card,
    appBar: AppBar(
      backgroundColor: C.card,
      automaticallyImplyLeading: false,
      actions: [
        Text('Step 1 of 2', style: TextStyle(color: C.muted)),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(value: .5, minHeight: 5),
          ),
        ),
        const SizedBox(width: 16),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'Set up your shop',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        Text(
          'Tell us about your shop to get started.',
          style: TextStyle(color: C.muted, fontSize: 16),
        ),
        const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Shop logo (optional)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: C.primarySoft,
                    backgroundImage: _logoBytes == null
                        ? null
                        : MemoryImage(_logoBytes!),
                    child: _logoBytes == null
                        ? Icon(
                            Icons.storefront_rounded,
                            size: 36,
                            color: C.primary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Add logo'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(120, 44),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'JPG or PNG, up to 2 MB',
                          style: TextStyle(color: C.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LabeledField(
                label: 'Shop name',
                controller: _name,
                hint: 'Sunrise Stores',
              ),
              const Text(
                'Shop type',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _type,
                items: [
                  for (final t in types)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: 'City',
                controller: _city,
                hint: 'Pune',
                prefix: const Icon(Icons.location_on_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          'Continue',
          icon: Icons.chevron_right_rounded,
          onPressed: _next,
        ),
      ],
    ),
  );
}

class BillingSetupScreen extends ConsumerStatefulWidget {
  const BillingSetupScreen({super.key});
  @override
  ConsumerState<BillingSetupScreen> createState() => _BillingSetupState();
}

class _BillingSetupState extends ConsumerState<BillingSetupScreen> {
  String _mode = 'SIMPLE';
  String _currency = 'INR';
  bool _track = true, _busy = false;

  Future<void> _finish() async {
    setState(() => _busy = true);
    final d = ref.read(_setupDraft);
    final api = ref.read(apiProvider);
    try {
      String? logoUrl;
      final logoBytes = d['logoBytes'];
      if (logoBytes is List<int> && logoBytes.isNotEmpty) {
        try {
          logoUrl = await api.uploadProductImage(
            null,
            bytes: logoBytes,
            filename: d['logoName'] as String?,
          );
        } catch (_) {}
      }
      await api.updateBusinessProfile({
        'businessName': d['name'],
        'businessType': d['type'],
        'address': d['city'],
        'currency': _currency,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (_mode == 'SIMPLE') 'defaultTaxRate': 0,
      });
      ref.read(authProvider.notifier).updateBusinessName(d['name'] as String);
      await ref.read(authProvider.notifier).finishSetup(billingMode: _mode);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _option(
    String value,
    String title,
    String sub,
    List<String> pts,
    IconData icon,
  ) {
    final sel = _mode == value;
    return GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: sel ? C.primarySoft.withOpacity(.5) : C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sel ? C.primary : C.border,
            width: sel ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: C.primarySoft,
              child: Icon(icon, color: C.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(sub, style: TextStyle(color: C.muted)),
                  const SizedBox(height: 8),
                  for (final p in pts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.check_rounded, size: 18, color: C.success),
                          const SizedBox(width: 8),
                          Flexible(child: Text(p)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              sel ? Icons.radio_button_checked : Icons.radio_button_off,
              color: sel ? C.primary : C.muted,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.card,
    appBar: AppBar(
      backgroundColor: C.card,
      title: const BrandLogo(size: 22, showTagline: false),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Text('Step 2 of 2', style: TextStyle(color: C.muted)),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(value: 1, minHeight: 5),
              ),
            ),
            const SizedBox(width: 10),
            Text('Almost done!', style: TextStyle(color: C.muted)),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Choose how you want to bill',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        Text(
          'You can change this later from Settings.',
          style: TextStyle(color: C.muted),
        ),
        const SizedBox(height: 18),
        _option(
          'SIMPLE',
          'Simple billing',
          'For shops not registered for GST',
          const [
            'Quick and easy billing',
            'No GST calculation',
            'Suitable for most small retail shops',
          ],
          Icons.description_outlined,
        ),
        _option('GST', 'GST billing', 'For GST-registered shops', const [
          'Automatic GST calculation (CGST, SGST/IGST)',
          'GST compliant invoices',
          'Suitable for registered businesses',
        ], Icons.request_quote_outlined),
        const Divider(height: 30),
        const Text(
          'Business currency',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _currency,
          items: const [
            DropdownMenuItem(value: 'INR', child: Text('Indian Rupee (₹)')),
          ],
          onChanged: (v) => setState(() => _currency = v ?? 'INR'),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _track,
          onChanged: (v) => setState(() => _track = v),
          title: const Text(
            'Track stock for products',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Keep track of product quantities and get low stock alerts.',
          ),
        ),
        const SizedBox(height: 10),
        PrimaryButton('Finish setup', loading: _busy, onPressed: _finish),
      ],
    ),
  );
}
