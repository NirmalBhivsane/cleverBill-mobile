import 'package:flutter_test/flutter_test.dart';
import 'package:clever_bill_mobile/core/utils/json.dart';
import 'package:clever_bill_mobile/data/models.dart';

void main() {
  group('json helpers are tolerant', () {
    test('numbers from strings / null', () {
      expect(jd('12.5'), 12.5);
      expect(jd(null), 0);
      expect(ji('7'), 7);
      expect(ji('abc'), 0);
    });
    test('bool / map / list', () {
      expect(jb('true'), isTrue);
      expect(jb(null, true), isTrue);
      expect(jm(null), isEmpty);
      expect(
        jlist<String>([
          {'a': '1'},
          5,
        ], (m) => m['a'] as String),
        ['1'],
      );
    });
  });

  group('Product', () {
    test('stock flags', () {
      expect(Product({'stock': 0}).isOut, isTrue);
      expect(Product({'stock': 3, 'lowStockThreshold': 5}).isLow, isTrue);
      expect(Product({'stock': 30, 'lowStockThreshold': 5}).isLow, isFalse);
      expect(Product({'stock': 0, 'isService': true}).isOut, isFalse);
    });
    test('GST slab wins over taxPercent', () {
      expect(Product({'gstSlab': 'EIGHTEEN'}).taxPercent, 18);
      expect(Product({'taxPercent': 5}).taxPercent, 5);
    });
    test('category and unit defaults', () {
      final p = Product({'categoryId': 3, 'categoryName': 'Dairy'});
      expect(p.categoryId, '3');
      expect(p.category, 'Dairy');
      expect(p.unit, 'PCS');
    });
  });

  group('Invoice', () {
    test('due never negative, walk-in fallback', () {
      final i = Invoice({'grandTotal': 100, 'paidAmount': 150});
      expect(i.due, 0);
      expect(i.customerName, 'Walk-in Customer');
    });
    test('ui status', () {
      expect(Invoice({'status': 'CANCELLED'}).uiStatus, 'Cancelled');
      expect(Invoice({'paymentStatus': 'PARTIAL'}).uiStatus, 'Partial');
      expect(Invoice({'paymentStatus': 'PAID'}).uiStatus, 'Paid');
      expect(Invoice({}).uiStatus, 'Unpaid');
    });
  });

  test('Category model', () {
    final c = Category({'id': 1, 'name': 'Snacks', 'defaultGstPercent': 12});
    expect(c.id, '1');
    expect(c.gst, 12);
  });
}
