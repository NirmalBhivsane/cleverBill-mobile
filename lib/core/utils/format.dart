import 'package:intl/intl.dart';

final _money0 = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);
final _money2 = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

/// Whole rupees when value is integral, else 2 decimals.
String money(num v) =>
    v == v.roundToDouble() ? _money0.format(v) : _money2.format(v);
String num0(num v) => NumberFormat.decimalPattern('en_IN').format(v);
String dateShort(DateTime? d) =>
    d == null ? '-' : DateFormat('dd MMM yyyy').format(d);
String dateTime12(DateTime? d) =>
    d == null ? '-' : DateFormat('dd MMM yyyy, hh:mm a').format(d);
String timeOnly(DateTime? d) =>
    d == null ? '' : DateFormat('hh:mm a').format(d);
String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String initials(String name) {
  final p = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}
