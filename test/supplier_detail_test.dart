import 'package:flutter/material.dart' hide Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clever_bill_mobile/data/models.dart';
import 'package:clever_bill_mobile/features/suppliers/supplier_screens.dart';
import 'package:clever_bill_mobile/features/suppliers/supplier_main_screens.dart';
import 'package:clever_bill_mobile/core/i18n/i18n.dart';
import 'package:clever_bill_mobile/providers.dart';

void main() {
  testWidgets('Supplier Products tab renders properly with catalog, purchases and mappings', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    final testSupplier = Supplier({
      'id': 'supp-1',
      'name': 'Kantilal Kamble',
      'phone': '9359986921',
      'gstin': '26ABCDE1234F1Z5',
      'state': '27',
      'active': true,
      'status': 'ACTIVE',
      'totalPurchases': 30000.0,
      'outstanding': 0.0,
      'ordersCount': 1,
      'pendingDeliveries': 0,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supplierProductsProvider('supp-1').overrideWith((ref) async => [
            SupplierProductMapping({
              'id': 'map-1',
              'productId': 'prod-1',
              'productName': 'Basmati Rice',
              'purchasePrice': 1200.0,
              'stock': 15,
              'hsnCode': '1006',
              'sku': 'RICE-01',
              'isPreferred': true,
            }),
          ]),
          supplierPurchasesProvider('supp-1').overrideWith((ref) async => [
            Purchase({
              'id': 'pur-1',
              'purchaseNumber': 'PUR-2026-01003',
              'supplierId': 'supp-1',
              'supplierName': 'Kantilal Kamble',
              'totalAmount': 30000.0,
              'paymentMode': 'CASH',
              'purchaseDate': '2026-10-29T10:00:00Z',
              'cancelled': false,
              'items': [
                {
                  'id': 'item-1',
                  'productId': 'prod-1',
                  'productName': 'Basmati Rice',
                  'quantity': 25,
                  'purchasePrice': 1200.0,
                  'totalAmount': 30000.0,
                },
              ],
            }),
          ]),
          supplierBillsProvider('supp-1').overrideWith((ref) async => []),
          supplierReturnsProvider('supp-1').overrideWith((ref) async => []),
          productsProvider.overrideWith((ref) async => [
            Product({
              'id': 'prod-1',
              'name': 'Basmati Rice',
              'sku': 'RICE-01',
              'price': 1400.0,
              'purchasePrice': 1200.0,
              'stock': 15,
              'unit': 'KG',
              'categoryName': 'Grains',
            }),
          ]),
        ],
        child: MaterialApp(
          home: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SupplierDetailScreen(supplier: testSupplier),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('Kantilal Kamble'), findsAtLeastNWidgets(1));
    expect(find.text('₹30,000'), findsAtLeastNWidgets(1));

    // Tap on Products tab
    final productsTabFinder = find.widgetWithText(Tab, 'Products');
    expect(productsTabFinder, findsOneWidget);
    await tester.tap(productsTabFinder);
    await tester.pumpAndSettle();

    // Verify Products tab content
    expect(find.text('Products Supplied'), findsOneWidget);
    expect(find.text('1 product(s) linked to this supplier'), findsOneWidget);
    expect(find.text('Basmati Rice'), findsOneWidget);
    expect(find.text('Preferred'), findsOneWidget);
    expect(find.text('Mapped'), findsOneWidget);
    expect(find.text('Bought: 25'), findsOneWidget);
    expect(find.text('Stock: 15'), findsOneWidget);
    expect(find.text('₹1,200'), findsOneWidget);
    expect(find.text('Reorder'), findsOneWidget);
    expect(find.text('Add Mapping'), findsOneWidget);

    // Verify that the title does NOT collapse to single letter lines
    final titleFinder = find.text('Products Supplied');
    final renderBox = tester.renderObject<RenderBox>(titleFinder);
    expect(renderBox.size.width, greaterThan(100.0));
    print('SUCCESS: Products Supplied text width = ${renderBox.size.width}');
  });
}
