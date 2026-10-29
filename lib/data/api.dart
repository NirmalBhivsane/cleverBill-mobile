import 'package:dio/dio.dart' show Options;
import 'package:image_picker/image_picker.dart' show XFile;

import '../core/network/api_client.dart';
import '../core/utils/format.dart';
import '../core/utils/json.dart';
import 'models.dart';

/// All backend calls used by the app, grouped by module.
class Api {
  Api(this.c);
  final ApiClient c;

  // ───────── Auth ─────────
  Future<Map<String, dynamic>> loginEmail(
    String email,
    String password,
  ) async => jm(
    await c.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
    ),
  );
  Future<Map<String, dynamic>> phoneLogin(String firebaseIdToken) async =>
      jm(await c.post('/api/auth/phone', options: _bearer(firebaseIdToken)));
  Future<Map<String, dynamic>> googleLogin(String firebaseIdToken) async => jm(
    await c.post(
      '/api/auth/google',
      q: {'register': 'true'},
      options: _bearer(firebaseIdToken),
    ),
  );
  Future<void> logout() async => c.post('/api/auth/logout');
  Future<void> register(Map<String, dynamic> body, {String? idToken}) async {
    try {
      await c.post(
        '/api/auth/register',
        body: body,
        options: idToken == null ? null : _bearer(idToken),
      );
    } on ApiException catch (e) {
      if (e.status == 401 && idToken != null) {
        await c.post('/api/auth/register', body: body);
      } else {
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> profile() async =>
      jm(await c.get('/api/auth/profile'));
  Future<void> updateProfile(Map<String, dynamic> body) async =>
      c.put('/api/auth/profile', body: body);
  Future<Map<String, dynamic>> globalSearch(String q) async =>
      jm(await c.get('/api/search', q: {'query': q}));
  Future<Map<String, dynamic>> analytics(String kind, String period) async =>
      jm(await c.get('/api/analytics/$kind', q: {'period': period}));
  Future<Map<String, dynamic>> branchActivity(String id) async =>
      jm(await c.get('/api/branches/$id/activity'));
  Future<Map<String, dynamic>> razorpayCreateOrder(
    Map<String, dynamic> body,
  ) async =>
      jm(await c.post('/api/payments/razorpay/create-order', body: body));
  Future<Map<String, dynamic>> razorpayVerify(
    Map<String, dynamic> body,
  ) async => jm(await c.post('/api/payments/razorpay/verify', body: body));
  Future<bool> validateScanSession(String id) async =>
      jb(jm(await c.get('/api/scan-session/validate/$id'))['valid']);
  Future<void> approveExpense(String id) async =>
      c.put('/api/expenses/$id/approve');
  Future<void> rejectExpense(String id) async =>
      c.put('/api/expenses/$id/reject');
  Future<List<Product>> expiryList(String kind) async {
    final d = await c.get('/api/expiry/$kind');
    final l = d is Map
        ? (d['products'] ?? d['content'] ?? d['items'] ?? d['data'])
        : d;
    return jlist(l, Product.new);
  }

  Future<Map<String, dynamic>> rfqDetail(String id) async =>
      jm(await c.get('/api/rfqs/$id'));
  Future<List<int>> rfqPdf(String id) => c.bytes('/api/rfqs/$id/pdf');
  Future<Map<String, dynamic>> invoicePdfSettings() async =>
      jm(await c.get('/api/settings/invoice-pdf'));
  Future<void> updateInvoicePdfSettings(Map<String, dynamic> body) async =>
      c.put('/api/settings/invoice-pdf', body: body);
  Future<List<int>> quotationPdf(String id) =>
      c.bytes('/api/quotations/$id/pdf');
  Future<void> changePassword(String oldPw, String newPw) async => c.post(
    '/api/auth/change-password',
    body: {
      'currentPassword': oldPw,
      'oldPassword': oldPw,
      'newPassword': newPw,
    },
  );
  Future<void> deleteAccount(String? password) async =>
      c.delete('/api/auth/delete-account', body: {'password': password ?? ''});
  Future<void> forgotPassword(String email) async =>
      c.post('/api/auth/forgot-password', body: {'email': email});
  Future<void> registerDeviceToken(String token) async => c.post(
    '/api/v1/device-tokens',
    body: {'token': token, 'platform': 'ANDROID'},
  );
  Future<void> removeDeviceToken(String token) async =>
      c.delete('/api/v1/device-tokens', body: {'token': token});

  Options _bearer(String t) => Options(headers: {'Authorization': 'Bearer $t'});

  // ───────── Home / reports ─────────
  Future<Map<String, dynamic>> dashboard() async =>
      jm(await c.get('/api/reports/dashboard'));
  Future<Map<String, dynamic>> dateDashboard(DateTime d) async =>
      jm(await c.get('/api/reports/date-aware-dashboard', q: {'date': iso(d)}));
  Future<Map<String, dynamic>> mobileHome() async =>
      jm(await c.get('/api/mobile/home'));
  Future<Map<String, dynamic>> mobileReports() async =>
      jm(await c.get('/api/mobile/reports'));
  Future<List<Map<String, dynamic>>> salesReport(
    DateTime from,
    DateTime to,
  ) async => jlist(
    await c.get('/api/reports/sales', q: {'from': iso(from), 'to': iso(to)}),
    (m) => m,
  );
  Future<List<Map<String, dynamic>>> topProducts(
    DateTime from,
    DateTime to,
  ) async => jlist(
    await c.get('/api/reports/top-products', q: {'limit': 10}),
    (m) => m,
  );
  Future<List<int>> exportSales(
    DateTime from,
    DateTime to, {
    bool excel = true,
  }) => c.bytes(
    '/api/reports/export/${excel ? 'excel' : 'csv'}',
    q: {'from': iso(from), 'to': iso(to)},
  );
  Future<Map<String, dynamic>> expenseBreakdown(
    DateTime from,
    DateTime to,
  ) async => jm(
    await c.get(
      '/api/expenses/analytics/category-breakdown',
      q: {'from': iso(from), 'to': iso(to)},
    ),
  );

  // ───────── Products / categories / stock ─────────
  Future<PageData<Product>> products({
    int page = 0,
    int size = 200,
    bool lowStock = false,
  }) async => PageData.parse(
    await c.get(
      '/api/products',
      q: {'page': page, 'size': size, 'lowStock': lowStock},
    ),
    Product.new,
  );
  Future<PageData<Product>> searchProducts(String k) async => PageData.parse(
    await c.get('/api/products/search', q: {'keyword': k, 'size': 50}),
    Product.new,
  );
  Future<Product?> productByBarcode(String code) async {
    try {
      return Product(jm(await c.get('/api/products/barcode/$code')));
    } on ApiException {
      return null;
    }
  }

  Future<Product> product(String id) async =>
      Product(jm(await c.get('/api/products/$id')));
  Future<void> saveProduct(Map<String, dynamic> body, {String? id}) async =>
      id == null
      ? c.post('/api/products', body: body)
      : c.put('/api/products/$id', body: body);
  Future<void> deleteProduct(String id) async => c.delete('/api/products/$id');
  Future<String> generateBarcode() async =>
      js(jm(await c.get('/api/products/generate-barcode')).values.first);
  Future<String?> uploadProductImage(
    String? path, {
    List<int>? bytes,
    String? filename,
  }) async {
    List<int>? fileBytes = bytes;
    if (fileBytes == null && path != null && path.isNotEmpty) {
      try {
        fileBytes = await XFile(path).readAsBytes();
      } catch (_) {}
    }
    final d = await c.upload(
      '/api/products/upload-image',
      'image',
      filePath: path,
      bytes: fileBytes,
      filename: filename ??
          (path != null && path.isNotEmpty
              ? path.split('/').last.split('\\').last
              : 'image.jpg'),
    );
    return _imageUrlFrom(d);
  }

  String? _imageUrlFrom(dynamic d) {
    bool ok(String v) =>
        v.isNotEmpty &&
        v != 'null' &&
        (v.startsWith('http://') ||
            v.startsWith('https://') ||
            v.startsWith('/') ||
            v.contains('cloudinary'));
    if (d is String && ok(d)) return d;
    if (d is Map) {
      final m = Map<String, dynamic>.from(d);
      for (final key in [
        'url',
        'imageUrl',
        'fileUrl',
        'secure_url',
        'secureUrl',
      ]) {
        final v = m[key];
        if (v is String && ok(v)) return v;
      }
      if (m['data'] is String && ok(m['data'] as String)) {
        return m['data'] as String;
      }
      if (m['data'] is Map) return _imageUrlFrom(m['data']);
      for (final v in m.values) {
        if (v is String && ok(v)) return v;
      }
    }
    return null;
  }

  Future<List<Category>> categories() async =>
      jlist(await c.get('/api/categories/active'), Category.new);
  Future<void> saveCategory(Map<String, dynamic> body, {String? id}) async =>
      id == null
      ? c.post('/api/categories', body: body)
      : c.put('/api/categories/$id', body: body);
  Future<void> deleteCategory(String id) async =>
      c.delete('/api/categories/$id');
  Future<void> adjustStock(
    String productId,
    int qty,
    String type,
    String note,
  ) async => c.post(
    '/api/stock/adjust',
    body: {
      'productId': productId,
      'quantity': qty,
      'movementType': type,
      'note': note,
    },
  );
  Future<PageData<StockMovement>> movements(
    String productId, {
    int page = 0,
  }) async => PageData.parse(
    await c.get(
      '/api/stock/movements',
      q: {'productId': productId, 'page': page, 'size': 30},
    ),
    StockMovement.new,
  );
  Future<Map<String, dynamic>> expiryAlerts() async =>
      jm(await c.get('/api/expiry/alerts'));

  // ───────── POS / invoices ─────────
  Future<Invoice> checkout(Map<String, dynamic> body) async =>
      Invoice(jm(await c.post('/api/pos/checkout', body: body)));
  Future<Invoice> createInvoice(Map<String, dynamic> body) async =>
      Invoice(jm(await c.post('/api/invoices', body: body)));
  Future<PageData<Invoice>> invoices({int page = 0, int size = 20}) async =>
      PageData.parse(
        await c.get('/api/invoices', q: {'page': page, 'size': size}),
        Invoice.new,
      );
  Future<PageData<Invoice>> invoicesRange(
    DateTime from,
    DateTime to, {
    int page = 0,
    int size = 300,
  }) async => PageData.parse(
    await c.get(
      '/api/invoices/filter',
      q: {'from': iso(from), 'to': iso(to), 'page': page, 'size': size},
    ),
    Invoice.new,
  );
  Future<List<Invoice>> searchInvoices(String q) async =>
      jlist(await c.get('/api/invoices/search', q: {'q': q}), Invoice.new);
  Future<Invoice> invoice(String id) async =>
      Invoice(jm(await c.get('/api/invoices/$id')));
  Future<void> cancelInvoice(String id) async =>
      c.patch('/api/invoices/$id/cancel');
  Future<void> markPaid(String id) async =>
      c.patch('/api/invoices/$id/mark-paid');
  Future<List<int>> invoicePdf(String id) => c.bytes('/api/invoices/$id/pdf');
  Future<PageData<Invoice>> invoicesByCustomer(String cid) async =>
      PageData.parse(
        await c.get('/api/invoices/customer/$cid', q: {'size': 100}),
        Invoice.new,
      );

  // ───────── Customers / payments ─────────
  Future<PageData<Customer>> customers({int page = 0, int size = 100}) async =>
      PageData.parse(
        await c.get('/api/customers', q: {'page': page, 'size': size}),
        Customer.new,
      );
  Future<PageData<Customer>> searchCustomers(String k) async => PageData.parse(
    await c.get('/api/customers/search', q: {'keyword': k, 'size': 30}),
    Customer.new,
  );
  Future<Customer> saveCustomer(
    Map<String, dynamic> body, {
    String? id,
  }) async => Customer(
    jm(
      id == null
          ? await c.post('/api/customers', body: body)
          : await c.put('/api/customers/$id', body: body),
    ),
  );
  Future<Map<String, dynamic>> customerLedger(String id) async =>
      jm(await c.get('/api/customers/$id/ledger'));
  Future<Map<String, dynamic>> customerBalance(String id) async =>
      jm(await c.get('/api/customers/$id/balance'));
  Future<void> recordPayment(
    String invoiceId,
    double amount,
    String mode,
    String note,
  ) async => c.post(
    '/api/payments',
    body: {
      'invoiceId': invoiceId,
      'amount': amount,
      'paymentMode': mode,
      'note': note,
    },
  );
  Future<String> paymentReminder(String invoiceId) async =>
      js(await c.get('/api/payments/reminder/$invoiceId'));
  Future<Map<String, dynamic>> paymentDetails() async =>
      jm(await c.get('/api/settings/payment-details'));

  // ───────── Suppliers / purchases / RFQ ─────────
  Future<PageData<Supplier>> suppliers({
    String? search,
    String? status,
    String? state,
    String? branchId,
  }) async => PageData.parse(
    await c.get(
      '/api/suppliers',
      q: {
        'size': 100,
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
        if (state != null && state.isNotEmpty) 'state': state,
        if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      },
    ),
    Supplier.new,
  );

  Future<Supplier> supplier(String id) async =>
      Supplier(jm(await c.get('/api/suppliers/$id')));

  Future<void> saveSupplier(Map<String, dynamic> body, {String? id}) async =>
      id == null
      ? c.post('/api/suppliers', body: body)
      : c.put('/api/suppliers/$id', body: body);

  Future<void> deleteSupplier(String id) async => c.delete('/api/suppliers/$id');

  Future<void> deactivateSupplier(String id, bool active) async => c.patch(
    '/api/suppliers/$id/status',
    body: {'active': active, 'status': active ? 'ACTIVE' : 'INACTIVE'},
  );

  Future<List<SupplierProductMapping>> supplierProducts(
    String supplierId,
  ) async {
    try {
      final res = await c.get('/api/suppliers/$supplierId/products');
      final list = res is Map
          ? (res['items'] ?? res['content'] ?? res['data'])
          : res;
      return jlist(list, SupplierProductMapping.new);
    } catch (_) {
      return [];
    }
  }

  Future<void> mapSupplierProduct(
    String supplierId,
    Map<String, dynamic> body,
  ) async => c.post('/api/suppliers/$supplierId/products', body: body);

  Future<void> deleteSupplierProductMapping(
    String supplierId,
    String mappingId,
  ) async => c.delete('/api/suppliers/$supplierId/products/$mappingId');

  Future<List<SupplierBill>> supplierBills(String supplierId) async {
    try {
      final res = await c.get('/api/suppliers/$supplierId/bills');
      final list = res is Map
          ? (res['items'] ?? res['content'] ?? res['data'])
          : res;
      return jlist(list, SupplierBill.new);
    } catch (_) {
      return [];
    }
  }

  Future<void> uploadSupplierBill(
    String supplierId,
    Map<String, dynamic> body,
  ) async => c.post('/api/suppliers/$supplierId/bills', body: body);

  Future<List<PurchaseReturn>> purchaseReturns({
    String? supplierId,
    String? status,
  }) async {
    try {
      final res = await c.get(
        '/api/purchase-returns',
        q: {
          if (supplierId != null && supplierId.isNotEmpty)
            'supplierId': supplierId,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );
      final list = res is Map
          ? (res['items'] ?? res['content'] ?? res['data'])
          : res;
      return jlist(list, PurchaseReturn.new);
    } catch (_) {
      return [];
    }
  }

  Future<void> createPurchaseReturn(Map<String, dynamic> body) async =>
      c.post('/api/purchase-returns', body: body);

  Future<void> approvePurchaseReturn(String id) async =>
      c.patch('/api/purchase-returns/$id/status', body: {'status': 'Approved'});

  Future<Map<String, dynamic>> supplierLedger(
    String supplierId, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      return jm(
        await c.get(
          '/api/suppliers/$supplierId/ledger',
          q: {
            if (from != null) 'from': iso(from),
            if (to != null) 'to': iso(to),
          },
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> recordSupplierPayment(Map<String, dynamic> body) async =>
      c.post('/api/supplier-payments', body: body);

  Future<PageData<Purchase>> purchases({
    String? supplierId,
    DateTime? from,
    DateTime? to,
  }) async => PageData.parse(
    await c.get(
      '/api/purchases',
      q: {
        'supplierId': supplierId,
        'from': from == null ? null : iso(from),
        'to': to == null ? null : iso(to),
        'size': 100,
      },
    ),
    Purchase.new,
  );
  Future<Purchase> purchase(String id) async =>
      Purchase(jm(await c.get('/api/purchases/$id')));
  Future<void> createPurchase(Map<String, dynamic> body) async =>
      c.post('/api/purchases', body: body);
  Future<void> cancelPurchase(String id) async =>
      c.patch('/api/purchases/$id/cancel');
  Future<List<Rfq>> rfqs() async => jlist(await c.get('/api/rfqs'), Rfq.new);
  Future<void> createRfq(Map<String, dynamic> body) async =>
      c.post('/api/rfqs', body: body);
  Future<void> cancelRfq(String id) async => c.patch('/api/rfqs/$id/cancel');
  Future<List<Quotation>> quotationsForRfq(String rfqId) async =>
      jlist(await c.get('/api/quotations/rfq/$rfqId'), Quotation.new);
  Future<void> quotationAction(
    String id,
    String action,
    String remarks,
  ) async => c.patch(
    '/api/quotations/$id/action',
    body: {'action': action, 'remarks': remarks},
  );

  // ───────── Returns / expenses ─────────
  Future<PageData<ReturnRec>> returns({String? status}) async => PageData.parse(
    await c.get('/api/returns', q: {'status': status, 'size': 100}),
    ReturnRec.new,
  );
  Future<void> createReturn(Map<String, dynamic> body) async =>
      c.post('/api/returns', body: body);
  Future<void> approveReturn(String id) async =>
      c.put('/api/returns/$id/approve');
  Future<void> rejectReturn(String id) async =>
      c.put('/api/returns/$id/reject');
  Future<PageData<Expense>> expenses({
    String? category,
    DateTime? from,
    DateTime? to,
  }) async => PageData.parse(
    await c.get(
      '/api/expenses',
      q: {
        'category': category,
        'from': from == null ? null : iso(from),
        'to': to == null ? null : iso(to),
        'size': 100,
      },
    ),
    Expense.new,
  );
  Future<void> saveExpense(Map<String, dynamic> body, {String? id}) async =>
      id == null
      ? c.post('/api/expenses', body: body)
      : c.put('/api/expenses/$id', body: body);
  Future<void> deleteExpense(String id) async => c.delete('/api/expenses/$id');

  // ───────── Notifications ─────────
  Future<PageData<Notif>> notifications() async => PageData.parse(
    await c.get('/api/notifications', q: {'size': 50}),
    Notif.new,
  );
  Future<int> unreadCount() async =>
      ji(jm(await c.get('/api/notifications/unread-count')).values.firstOrNull);
  Future<void> markRead(String id) async =>
      c.put('/api/notifications/$id/read');
  Future<void> markAllRead() async => c.put('/api/notifications/read-all');
  Future<void> clearNotifications() async =>
      c.delete('/api/notifications/clear-all');

  // ───────── Branches / staff ─────────
  Future<List<Branch>> branches() async =>
      jlist(await c.get('/api/branches'), Branch.new);
  Future<void> saveBranch(Map<String, dynamic> body, {String? id}) async =>
      id == null
      ? c.post('/api/branches', body: body)
      : c.put('/api/branches/$id', body: body);
  Future<void> deactivateBranch(String id) async =>
      c.delete('/api/branches/$id');
  Future<List<Employee>> employees(String branchId) async =>
      jlist(await c.get('/api/branches/$branchId/employees'), Employee.new);
  Future<void> createEmployee(
    String branchId,
    Map<String, dynamic> body,
  ) async => c.post('/api/branches/$branchId/employees', body: body);
  Future<void> toggleEmployee(String branchId, String empId) async =>
      c.put('/api/branches/$branchId/employees/$empId/toggle');

  // ───────── Settings ─────────
  Future<Map<String, dynamic>> settings() async =>
      jm(await c.get('/api/settings'));
  Future<void> updateSettings(Map<String, dynamic> body) async =>
      c.put('/api/settings', body: body);
  Future<Map<String, dynamic>> businessProfile() async =>
      jm(await c.get('/api/settings/business-profile'));
  Future<void> updateBusinessProfile(Map<String, dynamic> body) async =>
      c.put('/api/settings/business-profile', body: body);
  Future<void> updatePaymentDetails(Map<String, dynamic> body) async =>
      c.put('/api/settings/payment-details', body: body);
  Future<Map<String, dynamic>> notificationSettings() async =>
      jm(await c.get('/api/settings/notifications'));
  Future<void> updateNotificationSettings(Map<String, dynamic> body) async =>
      c.put('/api/settings/notifications', body: body);
  Future<List<int>> exportBackup() => c.bytes('/api/settings/backup/export');
}
