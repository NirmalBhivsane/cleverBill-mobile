import '../core/utils/json.dart';

class PageData<T> {
  PageData(this.items, this.total, this.last);
  final List<T> items;
  final int total;
  final bool last;
  static PageData<T> parse<T>(dynamic d, T Function(Map<String, dynamic>) f) {
    final m = jm(d);
    return PageData(
      jlist(m['content'], f),
      ji(m['totalElements']),
      jb(m['last'], true),
    );
  }
}

class Product {
  Product(this.j);
  final Map<String, dynamic> j;
  String get id => js(j['id']);
  String get name => js(j['name']);
  String get sku => js(j['sku']);
  String get barcode => js(j['barcode']);
  double get price => jd(j['price']);
  double get purchasePrice => jd(j['purchasePrice']);
  double get taxPercent {
    final slab = js(j['gstSlab']);
    const m = {
      'ZERO': 0.0,
      'FIVE': 5.0,
      'TWELVE': 12.0,
      'EIGHTEEN': 18.0,
      'TWENTY_EIGHT': 28.0,
    };
    return m[slab] ?? jd(j['taxPercent']);
  }

  int get stock => ji(j['stock']);
  int get lowStockThreshold => ji(j['lowStockThreshold']);
  String get unit => js(j['unit'], 'PCS');
  String get unitLabel => unit.toLowerCase();
  String get category => js(j['categoryName']);
  String? get categoryId => j['categoryId']?.toString();
  String? get imageUrl {
    final v = js(j['imageUrl']);
    return v.isEmpty ? null : v;
  }

  DateTime? get expiryDate => jdt(j['expiryDate']);
  bool get isService => jb(j['isService']);
  bool get active => jb(j['active'], true);
  bool get isLow => !isService && stock > 0 && stock <= lowStockThreshold;
  bool get isOut => !isService && stock <= 0;
  bool get isExpiring {
    final e = expiryDate;
    return e != null &&
        e.isBefore(DateTime.now().add(const Duration(days: 30)));
  }
}

class Category {
  Category(this.j);
  final Map<String, dynamic> j;
  String get id => js(j['id']);
  String get name => js(j['name']);
  double get gst => jd(j['defaultGstPercent']);
  String? get imageUrl => js(j['imageUrl']).isEmpty ? null : js(j['imageUrl']);
}

class Customer {
  Customer(this.j);
  final Map<String, dynamic> j;
  String get id => js(j['id']);
  String get name => js(j['name']);
  String get mobile => js(j['mobileNumber']);
  String get email => js(j['email']);
  String get address => js(j['address']);
  String get gstin => js(j['gstin']);
  String get stateCode => js(j['stateCode']);
  double get creditLimit => jd(j['creditLimit'] ?? j['individualCreditLimit']);
  double get outstanding => jd(j['outstanding']);
}

class LedgerEntry {
  LedgerEntry(this.j);
  final Map<String, dynamic> j;
  DateTime? get date => jdt(j['date']);
  String get type => js(j['type']);
  String get ref => js(j['referenceNo']);
  String get desc => js(j['description']);
  double get debit => jd(j['debit']);
  double get credit => jd(j['credit']);
  double get balance => jd(j['balance']);
}

class InvoiceItem {
  InvoiceItem(this.j);
  final Map<String, dynamic> j;
  String get productId => js(j['productId']);
  String get name => js(j['productName']);
  double get unitPrice => jd(j['unitPrice']);
  int get qty => ji(j['quantity']);
  double get lineTotal => jd(j['lineTotal']);
  double get tax => jd(j['lineTax']);
  String get hsn => js(j['hsnCode']);
}

class Invoice {
  Invoice(this.j);
  final Map<String, dynamic> j;
  String get id => js(j['id']);
  String get number => js(j['invoiceNumber']);
  Customer? get customer =>
      j['customer'] is Map ? Customer(jm(j['customer'])) : null;
  String get customerName =>
      customer?.name.isNotEmpty == true ? customer!.name : 'Walk-in Customer';
  List<InvoiceItem> get items => jlist(j['items'], InvoiceItem.new);
  double get subtotal => jd(j['subtotal']);
  double get tax => jd(j['totalTax']);
  double get discount => jd(j['discountAmount'] ?? j['discount']);
  double get total => jd(j['grandTotal']);
  double get paid => jd(j['paidAmount']);
  double get due => (total - paid).clamp(0, double.infinity).toDouble();
  double get cgst => jd(j['totalCgst']);
  double get sgst => jd(j['totalSgst']);
  double get igst => jd(j['totalIgst']);
  String get paymentMode => js(j['paymentMode']);
  String get status => js(j['status']);
  String get paymentStatus => js(j['paymentStatus']);
  DateTime? get createdAt => jdt(j['createdAt']);
  DateTime? get dueDate => jdt(j['dueDate']);
  double get received => jd(j['receivedAmount'] ?? j['cashReceived']);
  double get change => jd(j['changeReturned'] ?? j['changeAmount']);
  bool get cancelled => status == 'CANCELLED';

  /// UI status: Paid / Partial / Unpaid / Cancelled
  String get uiStatus {
    if (cancelled) return 'Cancelled';
    switch (paymentStatus) {
      case 'PAID':
        return 'Paid';
      case 'PARTIAL':
        return 'Partial';
      default:
        return status == 'PAID' ? 'Paid' : 'Unpaid';
    }
  }

  List<Map<String, dynamic>> get paymentHistory =>
      (j['paymentHistory'] is List ? j['paymentHistory'] as List : [])
          .map((e) => jm(e))
          .toList();
}

class Supplier {
  Supplier(this.j);
  final Map<String, dynamic> j;
  String get id => js(j['id']);
  String get name => js(j['name']);
  String get contact => js(j['contactPerson']);
  String get phone => js(j['phone']);
  String get email => js(j['email']);
  String get address => js(j['address']);
  String get gstin => js(j['gstin'], js(j['gstNumber']));
  String get stateCode => js(j['stateCode']);
}

class PurchaseItem {
  PurchaseItem(this.j);
  final Map<String, dynamic> j;
  String get name => js(j['productName']);
  int get qty => ji(j['quantity']);
  double get rate => jd(j['purchasePrice']);
  double get total => jd(j['totalAmount'] ?? j['lineTotal']);
}

class Purchase {
  Purchase(this.j);
  final Map<String, dynamic> j;
  String get id => js(j['id']);
  String get number => js(j['purchaseNumber']);
  String get supplierId => js(j['supplierId']);
  String get supplierName => js(j['supplierName']);
  List<PurchaseItem> get items => jlist(j['items'], PurchaseItem.new);
  double get total => jd(j['totalAmount']);
  String get mode => js(j['paymentMode']);
  DateTime? get date => jdt(j['purchaseDate']);
  bool get cancelled => jb(j['cancelled']);
  String get note => js(j['note']);
}

class Expense {
  Expense(this.j);
  final Map<String, dynamic> j;
  String get id => js(j['id']);
  String get title => js(j['title']);
  String get category => js(j['category']);
  double get amount => jd(j['amount']);
  DateTime? get date => jdt(j['date']);
  String get note => js(j['note']);
  String get approval => js(j['approvalStatus']);
}

class ReturnRec {
  ReturnRec(this.j);
  final Map<String, dynamic> j;
  String get id => js(j['id']);
  String get number => js(j['returnNumber']);
  String get invoiceNumber => js(j['invoiceNumber']);
  String get customerName => js(j['customerName'], 'Walk-in');
  double get refund => jd(j['refundAmount']);
  String get status => js(j['status']);
  String get reason => js(j['returnReason']);
  DateTime? get createdAt => jdt(j['createdAt']);
}

class RfqItem {
  RfqItem(this.j);
  final Map<String, dynamic> j;
  String get name => js(j['productName'], js(j['requestedProductName']));
  int get qty => ji(j['quantity']);
  double get expected => jd(j['expectedPrice']);
}

class Rfq {
  Rfq(this.j);
  final Map<String, dynamic> j;
  String get id => js(j['id']);
  String get number => js(j['rfqNumber']);
  String get supplierName => js(j['supplierName']);
  String get status => js(j['status']);
  DateTime? get delivery => jdt(j['deliveryDate']);
  List<RfqItem> get items => jlist(j['items'], RfqItem.new);
  int get itemCount => ji(j['itemCount']);
}

class Quotation {
  Quotation(this.j);
  final Map<String, dynamic> j;
  String get id => js(j['id']);
  String get number => js(j['quotationNumber']);
  String get rfqNumber => js(j['rfqNumber']);
  String get rfqId => js(j['rfqId']);
  String get supplierName => js(j['supplierName']);
  String get status => js(j['status']);
  DateTime? get validUntil => jdt(j['validUntil']);
  double get finalAmount => jd(j['finalAmount']);
  double get subtotal => jd(j['subtotal']);
  double get tax => jd(j['totalTax']);
  List<Map<String, dynamic>> get items =>
      (j['items'] is List ? j['items'] as List : []).map((e) => jm(e)).toList();
}

class Notif {
  Notif(this.j);
  final Map<String, dynamic> j;
  String get id => js(j['id']);
  String get type => js(j['type']);
  String get title => js(j['title']);
  String get message => js(j['message']);
  bool get read => jb(j['isRead']);
  DateTime? get createdAt => jdt(j['createdAt']);
  String get refId => js(j['referenceId']);
  String get refType => js(j['referenceType']);
}

class Branch {
  Branch(this.j);
  final Map<String, dynamic> j;
  String get id => js(j['id']);
  String get name => js(j['name']);
  String get city => js(j['city']);
  String get address => js(j['address']);
  bool get isMain => jb(j['main']) || jb(j['isMainBranch']);
  bool get active => jb(j['active'], true);
  double get todayRevenue => jd(j['todayRevenue']);
}

class Employee {
  Employee(this.j);
  final Map<String, dynamic> j;
  String get id => js(j['id']);
  String get name => js(j['name']);
  String get email => js(j['email']);
  bool get active => jb(j['active'], true);
  bool get captain => jb(j['isBranchCaptain']);
  String get branchName => js(j['branchName']);
}

class StockMovement {
  StockMovement(this.j);
  final Map<String, dynamic> j;
  String get type => js(j['movementType']);
  int get change => ji(j['quantityChanged']);
  int get before => ji(j['stockBefore']);
  int get after => ji(j['stockAfter']);
  String get note => js(j['note']);
  DateTime? get at => jdt(j['createdAt']);
}
