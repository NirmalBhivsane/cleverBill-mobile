import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../providers.dart';
import 'auth_screens.dart' show BrandLogo;

/// Email sign-up (2 steps) – mirrors the web Register page.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends ConsumerState<RegisterScreen> {
  int _step = 0;
  bool _busy = false, _hide = true;
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _pw = TextEditingController(),
      _pw2 = TextEditingController();
  final _biz = TextEditingController(),
      _phone = TextEditingController(),
      _gst = TextEditingController(),
      _addr = TextEditingController();
  String _type = 'Grocery';
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

  String? _validateStep1() {
    if (_name.text.trim().length < 2) return 'Enter your full name';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim()))
      return 'Enter a valid email address';
    final p = _pw.text;
    if (p.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(p) ||
        !RegExp(r'\d').hasMatch(p))
      return 'Password needs 8+ characters with letters and numbers';
    if (p != _pw2.text) return 'Passwords do not match';
    return null;
  }

  String? _validateStep2() {
    if (_biz.text.trim().isEmpty) return 'Enter your business name';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text.trim()))
      return 'Enter a valid 10-digit business phone';
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final err = _validateStep2();
    if (err != null) return toast(context, err, error: true);
    setState(() => _busy = true);
    final api = ref.read(apiProvider);
    try {
      String? idToken;
      try {
        final uc = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _pw.text,
        );
        idToken = await uc.user!.getIdToken();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // A previous sign-up may have stopped half-way (Firebase user created,
          // backend not). Try to continue with the same credentials; if the
          // password differs or the account is complete, ask the user to sign in.
          try {
            final uc = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: _email.text.trim(),
              password: _pw.text,
            );
            idToken = await uc.user!.getIdToken();
          } catch (_) {
            throw ApiException(
              'This email is already registered. Please sign in.',
            );
          }
        } else if (e.code == 'weak-password') {
          throw ApiException('Password is too weak.');
        } else if (e.code == 'network-request-failed') {
          throw ApiException('No internet connection. Please try again.');
        }
        // other Firebase errors: continue, backend may create the user itself
      } catch (_) {
        /* Firebase not configured on this platform */
      }
      await api.register({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _pw.text,
        'confirmPassword': _pw2.text,
        'businessName': _biz.text.trim(),
        'businessType': _type,
        'gstNumber': _gst.text.trim().toUpperCase(),
        'businessAddress': _addr.text.trim().isEmpty
            ? _biz.text.trim()
            : _addr.text.trim(),
        'businessPhone': _phone.text.trim(),
        'role': 'BUSINESS_OWNER',
      }, idToken: idToken);
      await ref.read(authProvider.notifier).loginEmail(_email.text, _pw.text);
      if (mounted)
        toast(context, 'Registration successful. Welcome to Clever Bill!');
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
      leading: BackButton(
        onPressed: () => _step == 1 ? setState(() => _step = 0) : context.pop(),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Center(child: BrandLogo(size: 30, showTagline: false)),
        const SizedBox(height: 22),
        Text(
          _step == 0 ? 'Create your account' : 'About your business',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        Text('Step ${_step + 1} of 2', style: TextStyle(color: C.muted)),
        const SizedBox(height: 18),
        if (_step == 0) ...[
          LabeledField(label: 'Full name', controller: _name, required: true),
          LabeledField(
            label: 'Email',
            controller: _email,
            keyboard: TextInputType.emailAddress,
            required: true,
          ),
          LabeledField(
            label: 'Password',
            controller: _pw,
            required: true,
            obscure: _hide,
            suffix: IconButton(
              icon: Icon(
                _hide
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
          LabeledField(
            label: 'Confirm password',
            controller: _pw2,
            required: true,
            obscure: _hide,
          ),
          PrimaryButton(
            'Next',
            icon: Icons.chevron_right_rounded,
            onPressed: () {
              final e = _validateStep1();
              if (e != null) return toast(context, e, error: true);
              setState(() => _step = 1);
            },
          ),
        ] else ...[
          LabeledField(
            label: 'Business name',
            controller: _biz,
            required: true,
          ),
          Text(
            'Business type',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _type,
            items: [
              for (final t in types) DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Business phone',
            controller: _phone,
            keyboard: TextInputType.phone,
            required: true,
            maxLength: 10,
          ),
          LabeledField(label: 'GSTIN (optional)', controller: _gst),
          LabeledField(
            label: 'Business address (optional)',
            controller: _addr,
            maxLines: 2,
          ),
          PrimaryButton('Create account', loading: _busy, onPressed: _submit),
        ],
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => context.go('/auth/email'),
            child: const Text('Already have an account? Sign in'),
          ),
        ),
      ],
    ),
  );
}
