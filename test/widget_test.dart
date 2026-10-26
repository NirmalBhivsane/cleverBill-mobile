import 'package:flutter_test/flutter_test.dart';
import 'package:clever_bill_mobile/core/utils/format.dart';

void main() {
  test('money formats Indian rupees', () {
    expect(money(450), '₹450');
    expect(money(1234567), '₹12,34,567');
    expect(money(99.5), '₹99.50');
  });
  test('initials', () {
    expect(initials('Rohan Patil'), 'RP');
    expect(initials('  '), '?');
  });
}
