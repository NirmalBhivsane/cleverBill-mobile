import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  final String token;
  final String? refreshToken;
  final String userId, name, email, role, phone;
  final String? businessId, businessName, branchId, branchName, profilePhoto;
  final bool isCaptain;
  const Session({
    required this.token,
    this.refreshToken,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.phone,
    this.businessId,
    this.businessName,
    this.branchId,
    this.branchName,
    this.profilePhoto,
    this.isCaptain = false,
  });
  bool get isOwner => role == 'BUSINESS_OWNER';

  Map<String, String> toMap() => {
    'token': token,
    'refreshToken': refreshToken ?? '',
    'userId': userId,
    'name': name,
    'email': email,
    'role': role,
    'phone': phone,
    'businessId': businessId ?? '',
    'businessName': businessName ?? '',
    'branchId': branchId ?? '',
    'branchName': branchName ?? '',
    'profilePhoto': profilePhoto ?? '',
    'isCaptain': '$isCaptain',
  };

  factory Session.fromMap(Map<String, String> m) {
    String? n(String k) => (m[k] == null || m[k]!.isEmpty) ? null : m[k];
    return Session(
      token: m['token'] ?? '',
      refreshToken: n('refreshToken'),
      userId: m['userId'] ?? '',
      name: m['name'] ?? '',
      email: m['email'] ?? '',
      role: m['role'] ?? 'BUSINESS_OWNER',
      phone: m['phone'] ?? '',
      businessId: n('businessId'),
      businessName: n('businessName'),
      branchId: n('branchId'),
      branchName: n('branchName'),
      profilePhoto: n('profilePhoto'),
      isCaptain: m['isCaptain'] == 'true',
    );
  }

  Session copyWith({
    String? token,
    String? refreshToken,
    String? businessName,
  }) => Session(
    token: token ?? this.token,
    refreshToken: refreshToken ?? this.refreshToken,
    userId: userId,
    name: name,
    email: email,
    role: role,
    phone: phone,
    businessId: businessId,
    businessName: businessName ?? this.businessName,
    branchId: branchId,
    branchName: branchName,
    profilePhoto: profilePhoto,
    isCaptain: isCaptain,
  );
}

class SessionStore {
  SessionStore(this._prefs);
  final SharedPreferences _prefs;
  static const _secure = FlutterSecureStorage();
  Session? _cache;

  Session? get session => _cache;

  Future<Session?> load() async {
    final raw = await _secure.readAll();
    if (raw['token'] == null || raw['token']!.isEmpty) return null;
    return _cache = Session.fromMap(raw);
  }

  Future<void> save(Session s) async {
    _cache = s;
    for (final e in s.toMap().entries) {
      await _secure.write(key: e.key, value: e.value);
    }
  }

  Future<void> clear() async {
    _cache = null;
    await _secure.deleteAll();
    await _prefs.remove('selectedBranchId');
  }

  String? get selectedBranchId => _prefs.getString('selectedBranchId');
  Future<void> setSelectedBranchId(String? id) => id == null
      ? _prefs.remove('selectedBranchId')
      : _prefs.setString('selectedBranchId', id);

  /// 'SIMPLE' or 'GST'
  String get billingMode => _prefs.getString('billingMode') ?? 'SIMPLE';
  Future<void> setBillingMode(String m) => _prefs.setString('billingMode', m);

  bool isSetupDone(String userId) => _prefs.getBool('setup_$userId') ?? false;
  Future<void> setSetupDone(String userId) =>
      _prefs.setBool('setup_$userId', true);

  String get language => _prefs.getString('lang') ?? 'English';
  Future<void> setLanguage(String l) => _prefs.setString('lang', l);
}
