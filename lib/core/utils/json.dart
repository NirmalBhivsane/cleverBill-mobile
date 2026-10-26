double jd(dynamic v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
int ji(dynamic v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String js(dynamic v, [String d = '']) => v == null ? d : v.toString();
bool jb(dynamic v, [bool d = false]) =>
    v is bool ? v : (v == null ? d : '$v' == 'true');
DateTime? jdt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
Map<String, dynamic> jm(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<T> jlist<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    (v is List ? v : const [])
        .whereType<Map>()
        .map((e) => f(Map<String, dynamic>.from(e)))
        .toList();
