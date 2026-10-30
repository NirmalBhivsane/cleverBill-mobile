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

  group('Supplier Module', () {
    test('Supplier model parsing and financial calculations', () {
      final s = Supplier({
        'id': 'sup-1',
        'name': 'Kantilal Kamble',
        'contactPerson': 'Kantilal Kamble',
        'phone': '9358800921',
        'gstin': '26ABCDE1234F125',
        'state': 'Maharashtra',
        'active': true,
        'totalPurchases': 250000,
        'totalPaid': 165000,
        'outstanding': 85000,
        'ordersCount': 12,
        'pendingDeliveries': 2,
      });

      expect(s.id, 'sup-1');
      expect(s.name, 'Kantilal Kamble');
      expect(s.phone, '9358800921');
      expect(s.gstin, '26ABCDE1234F125');
      expect(s.state, 'Maharashtra');
      expect(s.active, isTrue);
      expect(s.status, 'Active');
      expect(s.totalPurchases, 250000.0);
      expect(s.totalPaid, 165000.0);
      expect(s.outstanding, 85000.0);
      expect(s.ordersCount, 12);
      expect(s.pendingDeliveries, 2);
    });

    test('Supplier default outstanding calculation when not given', () {
      final s = Supplier({
        'id': 'sup-2',
        'name': 'Ramesh Traders',
        'totalPurchases': 50000,
        'totalPaid': 30000,
      });
      expect(s.outstanding, 20000.0);
    });

    test('SupplierProductMapping model', () {
      final m = SupplierProductMapping({
        'id': 'map-1',
        'supplierId': 'sup-1',
        'supplierName': 'Kantilal Kamble',
        'productId': 'prod-101',
        'productName': 'Laptop',
        'hsnCode': '847130',
        'purchasePrice': 45000,
        'stock': 8,
        'preferredFlag': true,
      });

      expect(m.id, 'map-1');
      expect(m.productName, 'Laptop');
      expect(m.hsnCode, '847130');
      expect(m.purchasePrice, 45000.0);
      expect(m.stock, 8);
      expect(m.isPreferred, isTrue);
    });

    test('SupplierBill model', () {
      final b = SupplierBill({
        'id': 'bill-1',
        'invoiceNumber': 'SI-001',
        'amount': 45000,
        'status': 'Paid',
      });

      expect(b.id, 'bill-1');
      expect(b.invoiceNumber, 'SI-001');
      expect(b.amount, 45000.0);
      expect(b.status, 'Paid');
    });

    test('PurchaseReturn model', () {
      final r = PurchaseReturn({
        'id': 'ret-1',
        'returnNumber': 'PR-001',
        'productName': 'Laptop',
        'quantity': 2,
        'reason': 'Damaged',
        'status': 'Completed',
        'settlementType': 'Supplier Credit',
      });

      expect(r.id, 'ret-1');
      expect(r.returnNumber, 'PR-001');
      expect(r.quantity, 2);
      expect(r.reason, 'Damaged');
      expect(r.status, 'Completed');
      expect(r.settlementType, 'Supplier Credit');
    });

    test('SupplierLedgerEntry model', () {
      final l = SupplierLedgerEntry({
        'id': 'led-1',
        'particulars': 'Purchase Invoice #PI-001',
        'debit': 45000,
        'credit': 0,
        'balance': 50000,
        'type': 'PURCHASE',
      });

      expect(l.particulars, 'Purchase Invoice #PI-001');
      expect(l.debit, 45000.0);
      expect(l.credit, 0.0);
      expect(l.balance, 50000.0);
    });
  });
}
