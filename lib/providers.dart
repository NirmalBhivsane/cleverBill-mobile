import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/i18n/i18n.dart' show I18n;
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/session_store.dart';
import 'core/utils/json.dart';
import 'core/utils/sound.dart';
import 'data/api.dart';
import 'data/models.dart';

final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('override in main'),
);
final storeProvider = Provider((ref) => SessionStore(ref.watch(prefsProvider)));
final apiClientProvider = Provider(
  (ref) => ApiClient(
    ref.watch(storeProvider),
    onSessionExpired: () => Future.microtask(
      () => ref.read(authProvider.notifier).signOut(callApi: false),
    ),
  ),
);
final apiProvider = Provider((ref) => Api(ref.watch(apiClientProvider)));

// ───────────────────────── Auth ─────────────────────────
enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.session,
    this.needsSetup = false,
    this.billingMode = 'SIMPLE',
  });
  final AuthStatus status;
  final Session? session;
  final bool needsSetup;
  final String billingMode;
  bool get isGst => billingMode == 'GST';
  AuthState copy({
    AuthStatus? status,
    Session? session,
    bool? needsSetup,
    String? billingMode,
  }) => AuthState(
    status: status ?? this.status,
    session: session ?? this.session,
    needsSetup: needsSetup ?? this.needsSetup,
    billingMode: billingMode ?? this.billingMode,
  );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this.ref) : super(const AuthState()) {
    _init();
  }
  final Ref ref;
  SessionStore get _store => ref.read(storeProvider);
  Api get _api => ref.read(apiProvider);

  Future<void> _init() async {
    final s = await _store.load();
    if (s == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    state = AuthState(
      status: AuthStatus.authenticated,
      session: s,
      billingMode: _store.billingMode,
      needsSetup:
          s.isOwner && !_store.isSetupDone(s.userId) && _looksUnconfigured(s),
    );
  }

  bool _looksUnconfigured(Session s) =>
      (s.businessName ?? '').isEmpty ||
      (s.businessName ?? '').endsWith("'s Business");

  Session _toSession(Map<String, dynamic> d, {String? tokenOverride}) =>
      Session(
        token: tokenOverride ?? js(d['token'] ?? d['idToken']),
        refreshToken: d['refreshToken']?.toString(),
        userId: js(d['userId'] ?? d['id']),
        name: js(d['name']),
        email: js(d['email']),
        role: js(d['role'], 'BUSINESS_OWNER'),
        phone: js(d['phone']),
        businessId: d['businessId']?.toString(),
        businessName: d['businessName']?.toString(),
        branchId: d['branchId']?.toString(),
        branchName: d['branchName']?.toString(),
        profilePhoto: d['profilePhoto']?.toString(),
        isCaptain: jb(d['isBranchCaptain']),
      );

  Future<void> _complete(Session s, {bool fresh = false}) async {
    await _store.save(s);
    if (!s.isOwner && s.branchId != null)
      await _store.setSelectedBranchId(s.branchId);
    state = AuthState(
      status: AuthStatus.authenticated,
      session: s,
      billingMode: _store.billingMode,
      needsSetup:
          s.isOwner && !_store.isSetupDone(s.userId) && _looksUnconfigured(s),
    );
  }

  Future<void> loginEmail(String email, String password) async {
    final d = await _api.loginEmail(email.trim(), password);
    await _complete(_toSession(d));
  }

  /// [idToken] is the Firebase ID token obtained after OTP verification.
  Future<void> loginPhone(String idToken) async {
    final d = await _api.phoneLogin(idToken);
    await _complete(_toSession(d, tokenOverride: idToken));
  }

  Future<void> loginGoogle() async {
    final g = await GoogleSignIn().signIn();
    if (g == null) throw ApiException('Google sign-in cancelled');
    final a = await g.authentication;
    final cred = GoogleAuthProvider.credential(
      idToken: a.idToken,
      accessToken: a.accessToken,
    );
    final uc = await FirebaseAuth.instance.signInWithCredential(cred);
    final t = await uc.user!.getIdToken();
    final d = await _api.googleLogin(t!);
    await _complete(_toSession(d, tokenOverride: t));
  }

  Future<void> finishSetup({required String billingMode}) async {
    final s = state.session;
    if (s == null) return;
    await _store.setBillingMode(billingMode);
    await _store.setSetupDone(s.userId);
    state = state.copy(needsSetup: false, billingMode: billingMode);
  }

  Future<void> setBillingMode(String m) async {
    await _store.setBillingMode(m);
    state = state.copy(billingMode: m);
  }

  void updateBusinessName(String name) {
    final s = state.session;
    if (s == null) return;
    final n = s.copyWith(businessName: name);
    _store.save(n);
    state = state.copy(session: n);
  }

  bool _signingOut = false;

  Future<void> signOut({bool callApi = true}) async {
    if (_signingOut) return;
    _signingOut = true;
    // Set unauthenticated FIRST so the router redirect fires immediately
    // before any async cleanup — prevents blank screen on web.
    state = const AuthState(status: AuthStatus.unauthenticated);
    try {
      if (callApi) {
        try {
          // never let a slow/failed network call block the sign-out
          await _api.logout().timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      try {
        await _store.clear();
      } catch (_) {}
    } finally {
      _signingOut = false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

// ───────────────────────── Branches ─────────────────────────
final branchesProvider = FutureProvider.autoDispose<List<Branch>>(
  (ref) => ref.watch(apiProvider).branches(),
);

class BranchSelection extends StateNotifier<String?> {
  BranchSelection(this.ref) : super(ref.read(storeProvider).selectedBranchId);
  final Ref ref;
  Future<void> select(String? id) async {
    await ref.read(storeProvider).setSelectedBranchId(id);
    state = id;
    // refresh everything that depends on the active branch
    ref.invalidate(homeProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(invoicesProvider);
    ref.invalidate(customersProvider);
  }
}

final selectedBranchProvider = StateNotifierProvider<BranchSelection, String?>(
  (ref) => BranchSelection(ref),
);

// ───────────────────────── Shared data providers ─────────────────────────
final homeProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  ref.watch(selectedBranchProvider);
  final api = ref.watch(apiProvider);
  final results = await Future.wait([
    api.dateDashboard(DateTime.now()).catchError((_) => <String, dynamic>{}),
    api.mobileHome().catchError((_) => <String, dynamic>{}),
  ]);
  return {'dash': results[0], 'home': results[1]};
});

final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  ref.watch(selectedBranchProvider);
  return (await ref.watch(apiProvider).products()).items;
});

final categoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(apiProvider).categories(),
);

final invoicesProvider = FutureProvider.autoDispose
    .family<List<Invoice>, DateTime>((ref, month) async {
      ref.watch(selectedBranchProvider);
      final from = DateTime(month.year, month.month, 1);
      final to = DateTime(month.year, month.month + 1, 0);
      return (await ref.watch(apiProvider).invoicesRange(from, to)).items;
    });

final customersProvider = FutureProvider.autoDispose<List<Customer>>((
  ref,
) async {
  ref.watch(selectedBranchProvider);
  return (await ref.watch(apiProvider).customers()).items;
});

final notificationsProvider = FutureProvider.autoDispose<List<Notif>>(
  (ref) async => (await ref.watch(apiProvider).notifications()).items,
);
final unreadCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(apiProvider).unreadCount().catchError((_) => 0),
);

// ───────────────────────── Cart ─────────────────────────
class CartLine {
  CartLine(this.product, this.qty);
  final Product product;
  int qty;
  double get total => product.price * qty;
  double get tax => (total * product.taxPercent / 100);
}

class CartState {
  const CartState({
    this.lines = const [],
    this.customer,
    this.discountValue = 0,
    this.percent = false,
    this.notes = '',
    this.signature,
  });
  final List<CartLine> lines;
  final Customer? customer;
  final double discountValue;
  final bool percent;
  final String notes;
  final String? signature; // base64 PNG
  int get count => lines.fold(0, (a, l) => a + l.qty);
  double get subtotal => lines.fold(0.0, (a, l) => a + l.total);
  double get discount {
    final d = percent
        ? subtotal * discountValue.clamp(0, 100) / 100
        : discountValue;
    return d.clamp(0, subtotal).toDouble();
  }

  double get tax {
    if (subtotal <= 0) return 0.0;
    final discountRatio = (subtotal - discount) / subtotal;
    return lines.fold(0.0, (a, l) => a + (l.tax * discountRatio));
  }

  String get discountType => percent ? 'PERCENTAGE' : 'AMOUNT';
  double get total =>
      (subtotal - discount + tax).clamp(0, double.infinity).toDouble();
  int qtyOf(String productId) => lines
      .where((l) => l.product.id == productId)
      .fold(0, (a, l) => a + l.qty);
}

class CartController extends StateNotifier<CartState> {
  CartController() : super(const CartState());

  void _lines(List<CartLine> l) => state = CartState(
    lines: List.of(l),
    customer: state.customer,
    discountValue: state.discountValue,
    percent: state.percent,
    notes: state.notes,
    signature: state.signature,
  );

  void add(Product p) {
    PosSound.playBeep();
    final l = List.of(state.lines);
    final i = l.indexWhere((e) => e.product.id == p.id);
    if (i >= 0) {
      l[i].qty++;
    } else {
      l.add(CartLine(p, 1));
    }
    _lines(l);
  }

  void setQty(String id, int q) {
    final l = List.of(state.lines);
    final i = l.indexWhere((e) => e.product.id == id);
    if (i < 0) return;
    if (q <= 0) {
      l.removeAt(i);
    } else {
      l[i].qty = q;
    }
    _lines(l);
  }

  void inc(String id) {
    PosSound.playBeep();
    setQty(id, state.qtyOf(id) + 1);
  }
  void dec(String id) => setQty(id, state.qtyOf(id) - 1);

  void setDiscount(double v, {bool percent = false}) => state = CartState(
    lines: state.lines,
    customer: state.customer,
    discountValue: v < 0 ? 0 : v,
    percent: percent,
    notes: state.notes,
    signature: state.signature,
  );

  void setCustomer(Customer? c) => state = CartState(
    lines: state.lines,
    customer: c,
    discountValue: state.discountValue,
    percent: state.percent,
    notes: state.notes,
    signature: state.signature,
  );

  void setNotes(String n) => state = CartState(
    lines: state.lines,
    customer: state.customer,
    discountValue: state.discountValue,
    percent: state.percent,
    notes: n,
    signature: state.signature,
  );

  void setSignature(String? sig) => state = CartState(
    lines: state.lines,
    customer: state.customer,
    discountValue: state.discountValue,
    percent: state.percent,
    notes: state.notes,
    signature: sig,
  );

  void clear() => state = const CartState();
}

final cartProvider = StateNotifierProvider<CartController, CartState>(
  (ref) => CartController(),
);

// ───────────────────────── Appearance (dark mode, brand colour, font size) ─────────────────────────
class AppearanceState {
  const AppearanceState({
    this.dark = false,
    this.colorKey = 'sleek-blue',
    this.fontKey = 'MEDIUM',
  });
  final bool dark;
  final String colorKey, fontKey;
  double get fontScale => switch (fontKey) {
    'SMALL' => 0.875,
    'LARGE' => 1.125,
    _ => 1.0,
  };
}

class AppearanceController extends StateNotifier<AppearanceState> {
  AppearanceController(this.prefs)
    : super(
        AppearanceState(
          dark: prefs.getBool('ap_dark') ?? false,
          colorKey: prefs.getString('ap_color') ?? 'sleek-blue',
          fontKey: prefs.getString('ap_font') ?? 'MEDIUM',
        ),
      ) {
    C.apply(isDark: state.dark, colorKey: state.colorKey);
  }
  final SharedPreferences prefs;

  void update({bool? dark, String? colorKey, String? fontKey}) {
    final n = AppearanceState(
      dark: dark ?? state.dark,
      colorKey: colorKey ?? state.colorKey,
      fontKey: fontKey ?? state.fontKey,
    );
    C.apply(isDark: n.dark, colorKey: n.colorKey);
    prefs.setBool('ap_dark', n.dark);
    prefs.setString('ap_color', n.colorKey);
    prefs.setString('ap_font', n.fontKey);
    state = n;
  }

  void reset() =>
      update(dark: false, colorKey: 'sleek-blue', fontKey: 'MEDIUM');
}

final appearanceProvider =
    StateNotifierProvider<AppearanceController, AppearanceState>(
      (ref) => AppearanceController(ref.watch(prefsProvider)),
    );

// ───────────────────────── Profile / search / analytics ─────────────────────────
final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async =>
      jm(await ref.watch(apiClientProvider).get('/api/auth/profile')),
);

// ───────────────────────── Language (English / हिन्दी / मराठी) ─────────────────────────
class LanguageController extends StateNotifier<String> {
  LanguageController(this.prefs) : super(prefs.getString('lang_code') ?? 'en') {
    I18n.lang = state;
  }
  final SharedPreferences prefs;
  void set(String code) {
    I18n.lang = code;
    prefs.setString('lang_code', code);
    state = code;
  }
}

final languageProvider = StateNotifierProvider<LanguageController, String>(
  (ref) => LanguageController(ref.watch(prefsProvider)),
);
