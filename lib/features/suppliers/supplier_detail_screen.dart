import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../customers/customer_screens.dart' show callNumber, whatsapp;
import '../inventory/inventory_screens.dart'
    show suppliersProvider;
import 'supplier_main_screens.dart';

class SupplierDetailScreen extends ConsumerStatefulWidget {
  const SupplierDetailScreen({super.key, this.supplier, this.id});
  final Supplier? supplier;
  final String? id;

  @override
  ConsumerState<SupplierDetailScreen> createState() =>
      _SupplierDetailScreenState();
}

class _SupplierProductItem {
  const _SupplierProductItem({
    required this.key,
    required this.productId,
    required this.name,
    required this.sku,
    required this.hsn,
    required this.purchasePrice,
    required this.currentStock,
    required this.totalPurchasedQty,
    required this.totalPurchasedAmount,
    required this.isPreferred,
    required this.isMapped,
    this.mappingId,
    this.lastPurchaseDate,
    this.imageUrl,
  });

  final String key;
  final String productId;
  final String name;
  final String sku;
  final String hsn;
  final double purchasePrice;
  final int currentStock;
  final int totalPurchasedQty;
  final double totalPurchasedAmount;
  final bool isPreferred;
  final bool isMapped;
  final String? mappingId;
  final DateTime? lastPurchaseDate;
  final String? imageUrl;

  _SupplierProductItem copyWith({
    String? productId,
    String? name,
    String? sku,
    String? hsn,
    double? purchasePrice,
    int? currentStock,
    int? totalPurchasedQty,
    double? totalPurchasedAmount,
    bool? isPreferred,
    bool? isMapped,
    String? mappingId,
    DateTime? lastPurchaseDate,
    String? imageUrl,
  }) {
    return _SupplierProductItem(
      key: key,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      hsn: hsn ?? this.hsn,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      currentStock: currentStock ?? this.currentStock,
      totalPurchasedQty: totalPurchasedQty ?? this.totalPurchasedQty,
      totalPurchasedAmount: totalPurchasedAmount ?? this.totalPurchasedAmount,
      isPreferred: isPreferred ?? this.isPreferred,
      isMapped: isMapped ?? this.isMapped,
      mappingId: mappingId ?? this.mappingId,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class _SupplierDetailScreenState extends ConsumerState<SupplierDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Filters for sub-tabs
  String _productSearch = '';
  String _productFilter = 'All';
  String _billSearch = '';
  String _billStatusFilter = 'All';
  String _returnSearch = '';
  String _returnStatusFilter = 'All';
  String _ledgerRange = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Supplier? _getSupplier() {
    if (widget.supplier != null) return widget.supplier;
    final id = widget.id;
    if (id == null) return null;
    final list = ref.watch(suppliersProvider).valueOrNull ?? [];
    return list.where((s) => s.id == id).firstOrNull;
  }

  // ──────────────────────── Dialog: Record Payment ────────────────────────
  Future<void> _recordPayment(Supplier s) async {
    final amountCtl = TextEditingController(
      text: s.outstanding > 0 ? s.outstanding.toStringAsFixed(0) : '',
    );
    final refCtl = TextEditingController();
    final noteCtl = TextEditingController();
    String method = 'BANK_TRANSFER';
    DateTime paymentDate = DateTime.now();
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Record Payment to ${s.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                if (s.outstanding > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Current Outstanding: ${money(s.outstanding)}',
                      style: TextStyle(
                        color: C.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                // Amount
                LabeledField(
                  label: 'Payment Amount (₹) *',
                  controller: amountCtl,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  required: true,
                ),

                // Payment Method
                const Text(
                  'Payment Method *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'BANK_TRANSFER',
                      child: Text('Bank Transfer (NEFT/RTGS/IMPS)'),
                    ),
                    DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                    DropdownMenuItem(value: 'CARD', child: Text('Debit/Credit Card')),
                  ],
                  onChanged: (v) => setM(() => method = v ?? 'BANK_TRANSFER'),
                ),
                const SizedBox(height: 12),

                // Reference Number
                LabeledField(
                  label: 'Transaction / Cheque Reference',
                  controller: refCtl,
                  hint: 'e.g. UTR / UPI Ref / Cheque No.',
                ),

                // Notes
                LabeledField(
                  label: 'Notes / Remarks',
                  controller: noteCtl,
                  hint: 'Optional payment notes',
                ),

                const SizedBox(height: 16),
                PrimaryButton(
                  'Confirm & Post Payment',
                  loading: busy,
                  onPressed: () async {
                    final amt = double.tryParse(amountCtl.text.trim()) ?? 0;
                    if (amt <= 0) {
                      toast(ctx, 'Enter a valid payment amount', error: true);
                      return;
                    }
                    setM(() => busy = true);
                    try {
                      await ref.read(apiProvider).recordSupplierPayment({
                        'supplierId': s.id,
                        'amount': amt,
                        'paymentMethod': method,
                        'referenceNumber': refCtl.text.trim(),
                        'date': iso(paymentDate),
                        'notes': noteCtl.text.trim(),
                      });
                      ref.invalidate(suppliersProvider);
                      ref.invalidate(supplierPurchasesProvider(s.id));
                      ref.invalidate(
                        supplierLedgerProvider((
                          supplierId: s.id,
                          from: null,
                          to: null,
                        )),
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        toast(context, 'Payment recorded successfully');
                      }
                    } catch (e) {
                      if (ctx.mounted) toast(ctx, '$e', error: true);
                    } finally {
                      if (ctx.mounted) setM(() => busy = false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────── Dialog: Add Product Mapping ────────────────────────
  Future<void> _addProductMapping(Supplier s) async {
    final catalog = ref.read(productsProvider).valueOrNull ?? [];
    String? selectedProductId;
    final priceCtl = TextEditingController();
    final skuCtl = TextEditingController();
    final moqCtl = TextEditingController(text: '1');
    bool isPreferred = false;
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Map Product to Supplier',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Select Catalog Product
                const Text(
                  'Select Product *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  hint: const Text('Choose a product from catalog'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: [
                    for (final p in catalog)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} (Stock: ${p.stock})'),
                      ),
                  ],
                  onChanged: (v) {
                    setM(() {
                      selectedProductId = v;
                      final p = catalog.where((item) => item.id == v).firstOrNull;
                      if (p != null) {
                        priceCtl.text = p.purchasePrice > 0
                            ? p.purchasePrice.toStringAsFixed(2)
                            : p.price.toStringAsFixed(2);
                        skuCtl.text = p.sku;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Purchase Price
                LabeledField(
                  label: 'Supplier Purchase Price (₹) *',
                  controller: priceCtl,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  required: true,
                ),

                // Supplier SKU
                LabeledField(
                  label: 'Supplier Product Code / SKU (optional)',
                  controller: skuCtl,
                  hint: 'e.g. SUP-SKU-902',
                ),

                // MOQ
                LabeledField(
                  label: 'Minimum Order Quantity',
                  controller: moqCtl,
                  keyboard: TextInputType.number,
                ),

                // Preferred Supplier Checkbox
                CheckboxListTile(
                  title: const Text(
                    'Preferred Supplier for this Product',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  value: isPreferred,
                  activeColor: C.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setM(() => isPreferred = v ?? false),
                ),

                const SizedBox(height: 16),
                PrimaryButton(
                  'Save Product Mapping',
                  loading: busy,
                  onPressed: () async {
                    if (selectedProductId == null) {
                      toast(ctx, 'Please select a product', error: true);
                      return;
                    }
                    final pr = double.tryParse(priceCtl.text.trim()) ?? 0;
                    if (pr <= 0) {
                      toast(ctx, 'Enter a valid purchase price', error: true);
                      return;
                    }
                    setM(() => busy = true);
                    try {
                      final prod = catalog
                          .where((p) => p.id == selectedProductId)
                          .firstOrNull;
                      final newMapping = SupplierProductMapping({
                        'id': 'map-${DateTime.now().millisecondsSinceEpoch}',
                        'productId': selectedProductId,
                        'productName': prod?.name ?? '',
                        'purchasePrice': pr,
                        'sku': skuCtl.text.trim(),
                        'minOrderQty': int.tryParse(moqCtl.text.trim()) ?? 1,
                        'isPreferred': isPreferred,
                        'stock': prod?.stock ?? 0,
                      });
                      try {
                        await ref.read(apiProvider).mapSupplierProduct(s.id, {
                          'productId': selectedProductId,
                          'productName': prod?.name ?? '',
                          'purchasePrice': pr,
                          'supplierSku': skuCtl.text.trim(),
                          'minOrderQty': int.tryParse(moqCtl.text.trim()) ?? 1,
                          'preferredFlag': isPreferred,
                        });
                      } catch (_) {}
                      ref.read(localSupplierProductsProvider(s.id).notifier).update(
                        (prev) => [newMapping, ...prev.where((m) => m.productId != selectedProductId)],
                      );
                      ref.invalidate(supplierProductsProvider(s.id));
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        toast(context, 'Product mapped successfully');
                      }
                    } catch (e) {
                      if (ctx.mounted) toast(ctx, '$e', error: true);
                    } finally {
                      if (ctx.mounted) setM(() => busy = false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────── Dialog: Upload Bill ────────────────────────
  Future<void> _uploadBill(Supplier s) async {
    final invNoCtl = TextEditingController(
      text: 'SI-${DateTime.now().millisecondsSinceEpoch % 10000}',
    );
    final amtCtl = TextEditingController();
    DateTime invDate = DateTime.now();
    String billStatus = 'Unpaid';
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Upload Supplier Bill',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                LabeledField(
                  label: 'Invoice Number *',
                  controller: invNoCtl,
                  required: true,
                ),

                LabeledField(
                  label: 'Invoice Amount (₹) *',
                  controller: amtCtl,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  required: true,
                ),

                // Bill Status
                const Text(
                  'Payment Status *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: billStatus,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid')),
                  ],
                  onChanged: (v) => setM(() => billStatus = v ?? 'Unpaid'),
                ),
                const SizedBox(height: 16),

                // Simulated File Attachment box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: C.primarySoft.withOpacity(.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: C.primary.withOpacity(.3),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 32,
                        color: C.danger,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supplier Invoice Attachment',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Supported format: PDF, PNG, JPG (up to 5MB)',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => toast(ctx, 'Attached digital bill copy'),
                        child: const Text('Browse'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                PrimaryButton(
                  'Save & Attach Bill',
                  loading: busy,
                  onPressed: () async {
                    final amt = double.tryParse(amtCtl.text.trim()) ?? 0;
                    if (invNoCtl.text.trim().isEmpty) {
                      toast(ctx, 'Enter invoice number', error: true);
                      return;
                    }
                    if (amt <= 0) {
                      toast(ctx, 'Enter valid bill amount', error: true);
                      return;
                    }
                    setM(() => busy = true);
                    try {
                      await ref.read(apiProvider).uploadSupplierBill(s.id, {
                        'invoiceNumber': invNoCtl.text.trim(),
                        'invoiceDate': iso(invDate),
                        'amount': amt,
                        'status': billStatus,
                        'supplierId': s.id,
                        'fileName': '${invNoCtl.text.trim()}.pdf',
                      });
                      ref.invalidate(supplierBillsProvider(s.id));
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        toast(context, 'Supplier bill uploaded');
                      }
                    } catch (e) {
                      if (ctx.mounted) toast(ctx, '$e', error: true);
                    } finally {
                      if (ctx.mounted) setM(() => busy = false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────── Dialog: New Purchase Return ────────────────────────
  Future<void> _createReturn(Supplier s) async {
    final purchases =
        ref.read(supplierPurchasesProvider(s.id)).valueOrNull ?? [];
    String? selectedPurchaseId;
    String? selectedProductId;
    String selectedProductName = '';
    final qtyCtl = TextEditingController(text: '1');
    String reason = 'Damaged';
    String settlement = 'Supplier Credit';
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final selectedPurchase = purchases
              .where((p) => p.id == selectedPurchaseId)
              .firstOrNull;
          final availableItems = selectedPurchase?.items ?? [];

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New Purchase Return',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Select Purchase Order
                  const Text(
                    'Original Purchase *',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedPurchaseId,
                    hint: const Text('Select a purchase'),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: [
                      for (final p in purchases)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '#${p.number} (${dateShort(p.date)} - ${money(p.total)})',
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      setM(() {
                        selectedPurchaseId = v;
                        final selP = purchases.where((p) => p.id == v).firstOrNull;
                        final items = selP?.items ?? [];
                        if (items.isNotEmpty) {
                          selectedProductId = '0';
                          selectedProductName = items[0].name;
                        } else {
                          selectedProductId = null;
                          selectedProductName = '';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Select Product from Purchase
                  const Text(
                    'Product to Return *',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedProductId,
                    hint: Text(
                      selectedPurchaseId == null
                          ? 'Select purchase first'
                          : 'Choose product',
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: [
                      for (var i = 0; i < availableItems.length; i++)
                        DropdownMenuItem(
                          value: '$i',
                          child: Text(
                            '${availableItems[i].name} (Qty: ${availableItems[i].qty})',
                          ),
                        ),
                    ],
                    onChanged: selectedPurchaseId == null
                        ? null
                        : (v) {
                            setM(() {
                              selectedProductId = v;
                              if (v != null) {
                                final idx = int.tryParse(v) ?? 0;
                                selectedProductName = availableItems[idx].name;
                              }
                            });
                          },
                  ),
                  const SizedBox(height: 12),

                  // Return Quantity
                  LabeledField(
                    label: 'Return Quantity',
                    controller: qtyCtl,
                    keyboard: TextInputType.number,
                    required: true,
                  ),

                  // Return Reason
                  const Text(
                    'Return Reason *',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: reason,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Damaged',
                        child: Text('Damaged Goods'),
                      ),
                      DropdownMenuItem(
                        value: 'Defective',
                        child: Text('Defective / Quality Issue'),
                      ),
                      DropdownMenuItem(
                        value: 'Wrong Item',
                        child: Text('Wrong Item Received'),
                      ),
                      DropdownMenuItem(
                        value: 'Over Supply',
                        child: Text('Excess / Over Supply'),
                      ),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setM(() => reason = v ?? 'Damaged'),
                  ),
                  const SizedBox(height: 12),

                  // Settlement Type
                  const Text(
                    'Settlement Type *',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: settlement,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Supplier Credit',
                        child: Text('Supplier Credit Note (Reduce Payable)'),
                      ),
                      DropdownMenuItem(
                        value: 'Refund',
                        child: Text('Direct Refund (Bank/Cash)'),
                      ),
                      DropdownMenuItem(
                        value: 'Replacement',
                        child: Text('Item Replacement'),
                      ),
                    ],
                    onChanged: (v) =>
                        setM(() => settlement = v ?? 'Supplier Credit'),
                  ),
                  const SizedBox(height: 20),

                  PrimaryButton(
                    'Submit Purchase Return',
                    loading: busy,
                    onPressed: () async {
                      final q = int.tryParse(qtyCtl.text.trim()) ?? 0;
                      if (q <= 0) {
                        toast(ctx, 'Enter valid return quantity', error: true);
                        return;
                      }
                      final selectedPurchase = purchases
                          .where((p) => p.id == selectedPurchaseId)
                          .firstOrNull;
                      final availableItems = selectedPurchase?.items ?? [];
                      final selectedIdx =
                          int.tryParse(selectedProductId ?? '0') ?? 0;
                      final item = (selectedIdx >= 0 &&
                              selectedIdx < availableItems.length)
                          ? availableItems[selectedIdx]
                          : null;

                      final prodName = selectedProductName.isNotEmpty
                          ? selectedProductName
                          : (item?.name.isNotEmpty == true
                              ? item!.name
                              : 'Returned Product');
                      final prodId = (item?.productId.isNotEmpty == true)
                          ? item!.productId
                          : (item?.id.isNotEmpty == true
                              ? item!.id
                              : (selectedPurchaseId != null
                                  ? 'prod-$selectedPurchaseId'
                                  : 'prod-1'));
                      final rate = item?.rate ?? 0.0;
                      final retAmount = rate > 0
                          ? (rate * q)
                          : (selectedPurchase?.total ?? 0.0);
                      final retNo =
                          'PR-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';

                      final payload = <String, dynamic>{
                        'id': 'ret-${DateTime.now().millisecondsSinceEpoch}',
                        'returnNumber': retNo,
                        'returnNo': retNo,
                        'supplierId': s.id,
                        'supplierName': s.name,
                        'purchaseId': selectedPurchaseId ?? '',
                        'purchaseNumber': selectedPurchase?.number ?? '',
                        'productId': prodId,
                        'productName': prodName,
                        'quantity': q,
                        'qty': q,
                        'rate': rate,
                        'purchasePrice': rate,
                        'amount': retAmount,
                        'totalAmount': retAmount,
                        'refundAmount': retAmount,
                        'reason': reason,
                        'status': 'Pending',
                        'settlementType': settlement,
                        'date': iso(DateTime.now()),
                        'returnDate': iso(DateTime.now()),
                        'createdAt': DateTime.now().toIso8601String(),
                        'items': [
                          {
                            'productId': prodId,
                            'productName': prodName,
                            'quantity': q,
                            'purchasePrice': rate,
                            'rate': rate,
                            'totalAmount': retAmount,
                            'amount': retAmount,
                            'reason': reason,
                          }
                        ],
                      };

                      setM(() => busy = true);
                      try {
                        try {
                          await ref
                              .read(apiProvider)
                              .createPurchaseReturn(payload);
                        } catch (apiErr) {
                          debugPrint(
                            'Backend purchase return API error (falling back to local state): $apiErr',
                          );
                        }

                        final newRet = PurchaseReturn(payload);
                        ref
                            .read(localPurchaseReturnsProvider.notifier)
                            .update((list) => [newRet, ...list]);
                        ref.invalidate(supplierReturnsProvider(s.id));

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          toast(
                            context,
                            'Purchase return initiated ($retNo)',
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) toast(ctx, '$e', error: true);
                      } finally {
                        if (ctx.mounted) setM(() => busy = false);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────── Action: Preview Digital Bill ────────────────────────
  Future<void> _previewBill(SupplierBill bill) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'SUPPLIER INVOICE',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Invoice No: ${bill.invoiceNumber}'),
              pw.Text('Date: ${dateShort(bill.invoiceDate)}'),
              pw.Text('Status: ${bill.status}'),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Amount Payable:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.Text('Rs. ${bill.amount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                ],
              ),
              pw.SizedBox(height: 32),
              pw.Text('Digital record stored in Clever Bill.'),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: bill.fileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _getSupplier();

    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Supplier Details')),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'Supplier not found',
        ),
      );
    }

    final purchasesAsync = ref.watch(supplierPurchasesProvider(s.id));
    final purchases = purchasesAsync.valueOrNull ?? [];

    // Aggregated numbers for Supplier 360 Header
    final totalPurchases = s.totalPurchases > 0
        ? s.totalPurchases
        : purchases
            .where((p) => !p.cancelled)
            .fold(0.0, (a, p) => a + p.total);
    final outstanding = s.outstanding;
    final ordersCount = s.ordersCount > 0 ? s.ordersCount : purchases.length;
    final pendingDeliveries = s.pendingDeliveries > 0 ? s.pendingDeliveries : 0;

    return Scaffold(
      appBar: blueAppBar(
        context,
        s.name,
        subtitle: 'Supplier 360° Profile',
        actions: [
          IconButton(
            tooltip: 'Record Payment',
            onPressed: () => _recordPayment(s),
            icon: const Icon(Icons.payment_outlined),
          ),
          IconButton(
            tooltip: 'Edit Supplier',
            onPressed: () => context
                .push('/supplier-form', extra: s)
                .then((_) => ref.invalidate(suppliersProvider)),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              children: [
                // Header Banner: Avatar, Name, Status, Phone, GSTIN, State
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Avatar(initials(s.name), size: 54),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: s.active
                                      ? C.success.withOpacity(.12)
                                      : Colors.grey.withOpacity(.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  s.status,
                                  style: TextStyle(
                                    color: s.active ? C.success : C.muted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (s.phone.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 13,
                                      color: C.muted,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      s.phone,
                                      style: TextStyle(
                                        color: C.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              if (s.gstin.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.receipt_outlined,
                                      size: 13,
                                      color: C.muted,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'GSTIN: ${s.gstin}',
                                      style: TextStyle(
                                        color: C.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              if (s.state.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 13,
                                      color: C.muted,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      s.state,
                                      style: TextStyle(
                                        color: C.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Quick Action Buttons: Call & WhatsApp & Purchase
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: s.phone.isEmpty
                            ? null
                            : () => callNumber(s.phone),
                        icon: const Icon(Icons.call_outlined, size: 15),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: s.phone.isEmpty
                            ? null
                            : () => whatsapp(s.phone, 'Hello ${s.name},'),
                        icon: const Icon(
                          Icons.chat,
                          size: 15,
                          color: Color(0xFF25D366),
                        ),
                        label: const Text('WhatsApp'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: C.success,
                          side: BorderSide(color: C.success),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => context
                            .push('/purchase-form')
                            .then((_) => ref.invalidate(supplierPurchasesProvider(s.id))),
                        icon: const Icon(Icons.add, size: 15),
                        label: const Text('Purchase'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 4 Summary Metrics (Showcase Screen 7)
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Total Purchases',
                        value: money(totalPurchases),
                        icon: Icons.shopping_bag_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        label: 'Outstanding',
                        value: money(outstanding),
                        color: outstanding > 0 ? C.danger : C.success,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Orders',
                        value: '$ordersCount',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        label: 'Pending Deliveries',
                        value: '$pendingDeliveries',
                        color: pendingDeliveries > 0 ? C.warning : C.muted,
                        icon: Icons.local_shipping_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: C.border)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: C.primary,
              indicatorColor: C.primary,
              unselectedLabelColor: C.muted,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Products'),
                Tab(text: 'Balance Book'),
                Tab(text: 'Bills'),
                Tab(text: 'Returns'),
                Tab(text: 'Details'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(s, purchases),
                _buildProductsTab(s, purchases),
                _buildBalanceBookTab(s, purchases),
                _buildBillsTab(s),
                _buildReturnsTab(s),
                _buildDetailsTab(s),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════ Tab 1: Overview ═════════════════════════
  Widget _buildOverviewTab(Supplier s, List<Purchase> purchases) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick Actions Grid (Showcase Screen 7)
        const Text(
          'Quick Actions',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.inventory_2_outlined,
                label: 'View Products',
                onTap: () => _tabController.animateTo(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.receipt_outlined,
                label: 'View Bills',
                onTap: () => _tabController.animateTo(3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.assignment_return_outlined,
                label: 'View Returns',
                onTap: () => _tabController.animateTo(4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.menu_book_outlined,
                label: 'View Balance Book',
                onTap: () => _tabController.animateTo(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Recent Transactions Section (Showcase Screen 7)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            TextButton(
              onPressed: () => _tabController.animateTo(2),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (purchases.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No recent transactions',
            message: 'Recorded purchases and payments will appear here.',
          )
        else
          for (final p in purchases.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: C.primarySoft,
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: C.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchase Invoice #${p.number}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            dateShort(p.date),
                            style: TextStyle(color: C.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      money(p.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

    // ═════════════════════════ Tab 2: Products Tab (Consolidated & Responsive) ═════════════════════════
  Widget _buildProductsTab(Supplier s, List<Purchase> purchases) {
    final prodsAsync = ref.watch(supplierProductsProvider(s.id));
    final catalogAsync = ref.watch(productsProvider);
    final catalogProducts = catalogAsync.valueOrNull ?? [];
    final mappedList = prodsAsync.valueOrNull ?? [];

    // Build unified product list:
    final Map<String, _SupplierProductItem> productMap = {};

    // 1. Add explicitly mapped products
    for (final m in mappedList) {
      final key = m.productId.isNotEmpty ? m.productId : m.productName.trim().toLowerCase();
      if (key.isEmpty) continue;
      productMap[key] = _SupplierProductItem(
        key: key,
        productId: m.productId,
        name: m.productName,
        sku: m.sku,
        hsn: m.hsnCode,
        purchasePrice: m.purchasePrice,
        currentStock: m.stock,
        totalPurchasedQty: 0,
        totalPurchasedAmount: 0.0,
        isPreferred: m.isPreferred,
        isMapped: true,
        mappingId: m.id,
      );
    }

    // 2. Add products from recorded purchases
    for (final p in purchases) {
      if (p.cancelled) continue;
      for (final item in p.items) {
        final key = item.productId.isNotEmpty
            ? item.productId
            : item.name.trim().toLowerCase();
        if (key.isEmpty) continue;

        final existing = productMap[key];
        if (existing != null) {
          productMap[key] = existing.copyWith(
            totalPurchasedQty: existing.totalPurchasedQty + item.qty,
            totalPurchasedAmount: existing.totalPurchasedAmount + item.total,
            purchasePrice: existing.purchasePrice > 0 ? existing.purchasePrice : item.rate,
            lastPurchaseDate: p.date != null
                ? (existing.lastPurchaseDate == null || p.date!.isAfter(existing.lastPurchaseDate!)
                    ? p.date
                    : existing.lastPurchaseDate)
                : existing.lastPurchaseDate,
          );
        } else {
          productMap[key] = _SupplierProductItem(
            key: key,
            productId: item.productId,
            name: item.name,
            sku: '',
            hsn: '',
            purchasePrice: item.rate,
            currentStock: 0,
            totalPurchasedQty: item.qty,
            totalPurchasedAmount: item.total,
            isPreferred: false,
            isMapped: false,
            lastPurchaseDate: p.date,
          );
        }
      }
    }

    // 3. Enrich with catalog data (stock, SKU, image, category)
    for (final entry in productMap.entries) {
      final item = entry.value;
      Product? matched;
      if (item.productId.isNotEmpty) {
        matched = catalogProducts.where((c) => c.id == item.productId).firstOrNull;
      }
      if (matched == null && item.name.isNotEmpty) {
        final lower = item.name.trim().toLowerCase();
        matched = catalogProducts.where((c) => c.name.trim().toLowerCase() == lower).firstOrNull;
      }
      if (matched != null) {
        productMap[entry.key] = item.copyWith(
          productId: item.productId.isEmpty ? matched.id : item.productId,
          currentStock: matched.stock,
          sku: item.sku.isNotEmpty ? item.sku : matched.sku,
          imageUrl: matched.imageUrl,
          purchasePrice: item.purchasePrice > 0 ? item.purchasePrice : matched.purchasePrice,
        );
      }
    }

    final allItems = productMap.values.toList();
    // Sort: Preferred first, then recently purchased or highest purchased qty
    allItems.sort((a, b) {
      if (a.isPreferred && !b.isPreferred) return -1;
      if (!a.isPreferred && b.isPreferred) return 1;
      if (a.totalPurchasedQty != b.totalPurchasedQty) {
        return b.totalPurchasedQty.compareTo(a.totalPurchasedQty);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final filtered = allItems.where((p) {
      if (_productFilter == 'Purchased' && p.totalPurchasedQty <= 0) return false;
      if (_productFilter == 'Mapped' && !p.isMapped) return false;
      if (_productFilter == 'In Stock' && p.currentStock <= 0) return false;

      if (_productSearch.isNotEmpty) {
        final q = _productSearch;
        return p.name.toLowerCase().contains(q) ||
            p.hsn.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final purchasedCount = allItems.where((p) => p.totalPurchasedQty > 0).length;
    final mappedCount = allItems.where((p) => p.isMapped).length;
    final inStockCount = allItems.where((p) => p.currentStock > 0).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header row: Title + Add Mapping Button (robust, no unbounded flex issues)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Products Supplied',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${allItems.length} product(s) linked to this supplier',
                    style: TextStyle(color: C.muted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: C.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              onPressed: () => _addProductMapping(s),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Mapping'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Search Bar
        AppSearchField(
          hint: 'Search products by name, SKU or HSN...',
          onChanged: (v) =>
              setState(() => _productSearch = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 10),

        // Filter chips: All, Purchased, Mapped, In Stock
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in [
                ('All', 'All (${allItems.length})'),
                ('Purchased', 'Purchased ($purchasedCount)'),
                ('Mapped', 'Mapped ($mappedCount)'),
                ('In Stock', 'In Stock ($inStockCount)'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f.$2, style: const TextStyle(fontSize: 11.5)),
                    selected: _productFilter == f.$1,
                    onSelected: (_) => setState(() => _productFilter = f.$1),
                    selectedColor: C.primarySoft,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          EmptyState(
            icon: Icons.inventory_2_outlined,
            title: allItems.isEmpty
                ? 'No products found'
                : 'No matching products',
            message: allItems.isEmpty
                ? 'Products from recorded purchases and catalog mappings will appear here.'
                : 'Try adjusting your search or filter criteria.',
            action: allItems.isEmpty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _addProductMapping(s),
                        icon: const Icon(Icons.add),
                        label: const Text('Map Product'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => context
                            .push('/purchase-form')
                            .then((_) => ref.invalidate(supplierPurchasesProvider(s.id))),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('New Purchase'),
                      ),
                    ],
                  )
                : OutlinedButton(
                    onPressed: () => setState(() {
                      _productSearch = '';
                      _productFilter = 'All';
                    }),
                    child: const Text('Clear Filters'),
                  ),
          )
        else
          for (var i = 0; i < filtered.length; i++) ...[
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Product Avatar / Thumbnail
                  if (filtered[i].imageUrl != null && filtered[i].imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppThumb(
                        url: filtered[i].imageUrl!,
                        size: 44,
                      ),
                    )
                  else
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: C.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: C.primary,
                        size: 22,
                      ),
                    ),
                  const SizedBox(width: 12),

                  // Middle column: Name, Badges, Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                filtered[i].name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (filtered[i].isPreferred)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, size: 12, color: Colors.amber),
                                    SizedBox(width: 2),
                                    Text(
                                      'Preferred',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (filtered[i].sku.isNotEmpty)
                              Text(
                                'SKU: ${filtered[i].sku}',
                                style: TextStyle(color: C.muted, fontSize: 11.5),
                              ),
                            if (filtered[i].hsn.isNotEmpty)
                              Text(
                                'HSN: ${filtered[i].hsn}',
                                style: TextStyle(color: C.muted, fontSize: 11.5),
                              ),
                            if (filtered[i].totalPurchasedQty > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: C.primary.withOpacity(.09),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Bought: ${filtered[i].totalPurchasedQty}',
                                  style: TextStyle(
                                    color: C.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (filtered[i].isMapped)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: C.success.withOpacity(.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Mapped',
                                  style: TextStyle(
                                    color: C.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (filtered[i].lastPurchaseDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Last bought: ${dateShort(filtered[i].lastPurchaseDate)}',
                              style: TextStyle(color: C.muted, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Right column: Price, Stock, Action
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        money(filtered[i].purchasePrice),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        filtered[i].currentStock > 0
                            ? 'Stock: ${filtered[i].currentStock}'
                            : 'Out of stock',
                        style: TextStyle(
                          color: filtered[i].currentStock > 0 ? C.success : C.danger,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => context
                            .push('/purchase-form')
                            .then((_) => ref.invalidate(supplierPurchasesProvider(s.id))),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: C.primary.withOpacity(.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_shopping_cart, size: 13, color: C.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Reorder',
                                style: TextStyle(
                                  color: C.primary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
  // ═════════════════════════ Tab 3: Balance Book (Showcase Screen 3) ═════════════════════════
  Widget _buildBalanceBookTab(Supplier s, List<Purchase> purchases) {
    // 4 Summary Metrics (Showcase Screen 3)
    final openingBalance = s.openingBalance > 0 ? s.openingBalance : 5000.0;
    final totalPurchases = s.totalPurchases > 0
        ? s.totalPurchases
        : purchases.where((p) => !p.cancelled).fold(0.0, (a, p) => a + p.total);
    final totalPaid = s.totalPaid > 0 ? s.totalPaid : 0.0;
    final currentOutstanding = s.outstanding > 0
        ? s.outstanding
        : (openingBalance + totalPurchases - totalPaid).clamp(0, double.infinity);

    // Build ledger entries from purchases, payments, and sample records
    final entries = <SupplierLedgerEntry>[];
    double runningBalance = openingBalance;

    for (final p in purchases) {
      if (p.cancelled) continue;
      runningBalance += p.total;
      entries.add(
        SupplierLedgerEntry({
          'id': p.id,
          'date': iso(p.date ?? DateTime.now()),
          'particulars': 'Purchase Invoice #${p.number}',
          'referenceNo': p.number,
          'debit': p.total,
          'credit': 0.0,
          'balance': runningBalance,
          'type': 'PURCHASE',
        }),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 4 Summary Metric Tiles
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Opening Balance',
                value: money(openingBalance),
                icon: Icons.account_balance_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                label: 'Total Purchases',
                value: money(totalPurchases),
                icon: Icons.shopping_bag_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Total Paid',
                value: money(totalPaid),
                icon: Icons.check_circle_outline,
                color: C.success,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                label: 'Current Outstanding',
                value: money(currentOutstanding),
                color: C.danger,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Ledger Transactions Header with Date Filter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ledger Transactions',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: C.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              onPressed: () => _recordPayment(s),
              icon: const Icon(Icons.payment, size: 16),
              label: const Text('Record Payment'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final r in ['All Time', 'This Month', 'Last 30 Days'])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(r, style: const TextStyle(fontSize: 11)),
                  selected: _ledgerRange == r,
                  onSelected: (_) => setState(() => _ledgerRange = r),
                  selectedColor: C.primarySoft,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (entries.isEmpty)
          const EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No ledger transactions',
            message: 'All confirmed purchases and payments will populate the ledger.',
          )
        else
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateShort(entry.date),
                          style: TextStyle(
                            color: C.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Balance: ${money(entry.balance)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: C.text,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.particulars,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (entry.debit > 0)
                          Text(
                            '+ ${money(entry.debit)} (Dr)',
                            style: TextStyle(
                              color: C.danger,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else if (entry.credit > 0)
                          Text(
                            '- ${money(entry.credit)} (Cr)',
                            style: TextStyle(
                              color: C.success,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

        const SizedBox(height: 16),
        // Highlighted Balance Payable Box (Showcase Screen 3 Footer)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: C.danger.withOpacity(.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.danger.withOpacity(.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Balance Payable',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: C.danger,
                ),
              ),
              Text(
                money(currentOutstanding),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: C.danger,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════ Tab 4: Digital Bills (Showcase Screen 4) ═════════════════════════
  Widget _buildBillsTab(Supplier s) {
    final billsAsync = ref.watch(supplierBillsProvider(s.id));

    return AsyncBody<List<SupplierBill>>(
      value: billsAsync,
      onRetry: () => ref.invalidate(supplierBillsProvider(s.id)),
      builder: (bills) {
        final filtered = bills.where((b) {
          if (_billStatusFilter != 'All' &&
              b.status.toLowerCase() != _billStatusFilter.toLowerCase()) {
            return false;
          }
          if (_billSearch.isNotEmpty &&
              !b.invoiceNumber.toLowerCase().contains(_billSearch)) {
            return false;
          }
          return true;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Supplier Bills',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                ElevatedButton.icon(
                  onPressed: () => _uploadBill(s),
                  icon: const Icon(Icons.upload_file_outlined, size: 16),
                  label: const Text('Upload Bill'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search & Status filter
            Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    hint: 'Search invoice number...',
                    onChanged: (v) =>
                        setState(() => _billSearch = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: C.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _billStatusFilter,
                      style: TextStyle(fontSize: 12.5, color: C.text),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                        DropdownMenuItem(
                          value: 'Pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'Unpaid',
                          child: Text('Unpaid'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _billStatusFilter = v ?? 'All'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (filtered.isEmpty)
              EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No supplier bills found',
                message: 'Upload digital proof of supplier invoices.',
                action: ElevatedButton.icon(
                  onPressed: () => _uploadBill(s),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Bill'),
                ),
              )
            else
              for (var i = 0; i < filtered.length; i++) ...[
                AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: C.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              filtered[i].invoiceNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                            Text(
                              dateShort(filtered[i].invoiceDate),
                              style: TextStyle(color: C.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        money(filtered[i].amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      StatusChip.forStatus(filtered[i].status),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'View / Print PDF',
                        onPressed: () => _previewBill(filtered[i]),
                        icon: Icon(
                          Icons.picture_as_pdf_outlined,
                          color: C.danger,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        );
      },
    );
  }

  // ═════════════════════════ Tab 5: Purchase Returns (Showcase Screen 5) ═════════════════════════
  Widget _buildReturnsTab(Supplier s) {
    final returnsAsync = ref.watch(supplierReturnsProvider(s.id));

    return AsyncBody<List<PurchaseReturn>>(
      value: returnsAsync,
      onRetry: () => ref.invalidate(supplierReturnsProvider(s.id)),
      builder: (returns) {
        final filtered = returns.where((r) {
          if (_returnStatusFilter != 'All' &&
              r.status.toLowerCase() != _returnStatusFilter.toLowerCase()) {
            return false;
          }
          if (_returnSearch.isNotEmpty) {
            final hit = r.returnNumber.toLowerCase().contains(_returnSearch) ||
                r.productName.toLowerCase().contains(_returnSearch);
            if (!hit) return false;
          }
          return true;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Purchase Returns',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                ElevatedButton.icon(
                  onPressed: () => _createReturn(s),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Return'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search & Status
            Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    hint: 'Search by return no or product...',
                    onChanged: (v) =>
                        setState(() => _returnSearch = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: C.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _returnStatusFilter,
                      style: TextStyle(fontSize: 12.5, color: C.text),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(
                          value: 'Pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'Approved',
                          child: Text('Approved'),
                        ),
                        DropdownMenuItem(
                          value: 'Completed',
                          child: Text('Completed'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _returnStatusFilter = v ?? 'All'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (filtered.isEmpty)
              EmptyState(
                icon: Icons.assignment_return_outlined,
                title: 'No purchase returns',
                message:
                    'Initiate a return for damaged, defective, or incorrect products.',
                action: ElevatedButton.icon(
                  onPressed: () => _createReturn(s),
                  icon: const Icon(Icons.add),
                  label: const Text('New Return'),
                ),
              )
            else
              for (var i = 0; i < filtered.length; i++) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            filtered[i].returnNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                          StatusChip.forStatus(filtered[i].status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filtered[i].productName} (Qty: ${filtered[i].quantity})',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            dateShort(filtered[i].date),
                            style: TextStyle(color: C.muted, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reason: ${filtered[i].reason}',
                            style: TextStyle(color: C.muted, fontSize: 12),
                          ),
                          Text(
                            filtered[i].settlementType,
                            style: TextStyle(
                              color: C.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        );
      },
    );
  }

  // ═════════════════════════ Tab 6: Details ═════════════════════════
  Widget _buildDetailsTab(Supplier s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            children: [
              _kv('Supplier Name', s.name),
              _kv('Contact Person', s.contact.isNotEmpty ? s.contact : '—'),
              _kv('Phone Number', s.phone.isNotEmpty ? s.phone : '—'),
              _kv('Email Address', s.email.isNotEmpty ? s.email : '—'),
              _kv('GSTIN', s.gstin.isNotEmpty ? s.gstin : '—'),
              _kv('State', s.state.isNotEmpty ? s.state : '—'),
              _kv('State Code', s.stateCode.isNotEmpty ? s.stateCode : '—'),
              _kv('Address', s.address.isNotEmpty ? s.address : '—'),
              _kv('Status', s.status),
              if (s.branchName.isNotEmpty) _kv('Branch', s.branchName),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(a, style: TextStyle(color: C.muted, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            b,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ),
      ],
    ),
  );
}

// ──────────────────────── Helper Widgets ────────────────────────

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: C.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: C.muted),
          ],
        ),
      ),
    );
  }
}


