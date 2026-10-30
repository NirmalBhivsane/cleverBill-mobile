import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../home/home_screen.dart';
import 'invoice_actions.dart';
import 'razorpay_flow.dart';
import 'thermal_printer.dart';
import '../../core/utils/sound.dart';
import '../../core/widgets/signature_pad.dart';

// ═════════════════════════ POS (product picker) ═════════════════════════
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});
  @override
  ConsumerState<PosScreen> createState() => _PosState();
}

class _PosState extends ConsumerState<PosScreen> {
  String _q = '';
  int _cat = 0;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final cats = ref.watch(categoriesProvider).valueOrNull ?? [];
    final cart = ref.watch(cartProvider);
    final isGst = ref.watch(authProvider).isGst;
    final labels = ['All', ...cats.map((c) => c.name)];
    if (_cat >= labels.length) _cat = 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Clever Bill',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: C.primary,
                    ),
                  ),
                  const Spacer(),
                  const Flexible(flex: 2, child: BranchPill()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  PopupMenuButton<String>(
                    onSelected: (m) =>
                        ref.read(authProvider.notifier).setBillingMode(m),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'SIMPLE',
                        child: Text('Simple mode (No GST)'),
                      ),
                      PopupMenuItem(value: 'GST', child: Text('GST mode')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: C.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isGst
                                ? Icons.account_balance_outlined
                                : Icons.description_outlined,
                            size: 18,
                            color: C.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isGst ? 'GST mode' : 'Simple mode',
                            style: TextStyle(
                              color: C.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: C.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isGst
                          ? 'Tax invoices with CGST/SGST/IGST'
                          : 'Quick bills for everyday sales\n(No GST)',
                      style: TextStyle(color: C.muted, fontSize: 11.5),
                    ),
                  ),
                  if (isGst)
                    TextButton(
                      onPressed: () => context.push('/invoice-create'),
                      child: const Text('GST invoice'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppSearchField(
                hint: 'Search products or scan barcode',
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                trailing: InkWell(
                  onTap: () => context.push('/scan'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: C.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: C.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilterChips(
                labels: labels,
                selected: _cat,
                onSelect: (i) => setState(() => _cat = i),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AsyncBody<List<Product>>(
                value: products,
                onRetry: () => ref.invalidate(productsProvider),
                builder: (all) {
                  var list = all.where((p) => p.active).toList();
                  if (_cat > 0)
                    list = list
                        .where((p) => p.categoryId == cats[_cat - 1].id)
                        .toList();
                  if (_q.isNotEmpty) {
                    list = list
                        .where(
                          (p) =>
                              p.name.toLowerCase().contains(_q) ||
                              p.sku.toLowerCase().contains(_q) ||
                              p.barcode.toLowerCase().contains(_q),
                        )
                        .toList();
                  }
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: all.isEmpty
                          ? 'No products yet'
                          : 'No matching products',
                      message: all.isEmpty
                          ? 'Add your first product to start billing.'
                          : null,
                      action: all.isEmpty
                          ? ElevatedButton(
                              onPressed: () => context.push('/product-form'),
                              child: const Text('Add product'),
                            )
                          : null,
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _PosProductTile(p: list[i]),
                  );
                },
              ),
            ),
            if (cart.count > 0)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                decoration: BoxDecoration(
                  color: C.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.06),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart_outlined, color: C.primary),
                    const SizedBox(width: 10),
                    Text(
                      '${cart.count} items  •  ${money(cart.total)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 140,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: () => context.push('/cart'),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('View cart'),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PosProductTile extends ConsumerWidget {
  const _PosProductTile({required this.p});
  final Product p;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(cartProvider.select((c) => c.qtyOf(p.id)));
    final ctl = ref.read(cartProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: qty == 0
            ? (p.isOut
                ? () => toast(
                    context,
                    '${p.name} is out of stock',
                    error: true,
                  )
                : () => ctl.add(p))
            : null,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            AppThumb(url: p.imageUrl, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                  Text(
                    p.unit == 'PCS' ? 'per piece' : '1 ${p.unitLabel}',
                    style: TextStyle(color: C.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${money(p.price)} / ${p.unitLabel}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (p.isOut) ...[
                        const SizedBox(width: 8),
                        StatusChip('Out of stock', color: C.danger),
                      ] else if (p.isLow) ...[
                        const SizedBox(width: 8),
                        StatusChip('${p.stock} left', color: C.warning),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (qty == 0)
              InkWell(
                onTap: p.isOut
                    ? () => toast(
                        context,
                        '${p.name} is out of stock',
                        error: true,
                      )
                    : () => ctl.add(p),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: C.primary,
                  child: Icon(Icons.add, color: Colors.white),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: C.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ctl.dec(p.id),
                      icon: Icon(Icons.remove, color: C.primary),
                    ),
                    Text(
                      '$qty',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ctl.inc(p.id),
                      icon: Icon(Icons.add, color: C.primary),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════ Barcode scanner ═════════════════════════
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, this.forProductForm = false});
  final bool forProductForm;
  @override
  ConsumerState<ScanScreen> createState() => _ScanState();
}

class _ScanState extends ConsumerState<ScanScreen> {
  final _ctl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  Product? _found;
  String? _last;
  String? _notFound;
  bool _torch = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _handle(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == _last) return;
    _last = trimmed;
    try {
      PosSound.playBeep();
      HapticFeedback.mediumImpact();
    } catch (_) {}
    if (widget.forProductForm) {
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(trimmed);
        } else {
          context.pop(trimmed);
        }
      }
      return;
    }
    Product? p;
    try {
      final local = ref
          .read(productsProvider)
          .valueOrNull
          ?.where((pr) =>
              pr.barcode.trim().toLowerCase() == trimmed.toLowerCase() ||
              pr.sku.trim().toLowerCase() == trimmed.toLowerCase())
          .firstOrNull;
      p = local ?? await ref.read(apiProvider).productByBarcode(trimmed);
    } catch (e) {
      debugPrint('Error finding product by barcode: ');
    }
    if (!mounted) return;
    setState(() {
      _found = p;
      _notFound = p == null ? trimmed : null;
    });
  }

  Future<void> _manual() async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Enter barcode'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.text,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter barcode or SKU number',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            final text = val.trim();
            if (text.isNotEmpty) Navigator.pop(dlgCtx, text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dlgCtx, c.text.trim()),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    if (code != null && code.isNotEmpty) {
      _last = null;
      _handle(code);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        MobileScanner(
          controller: _ctl,
          errorBuilder: (context, error, child) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_outlined,
                        size: 56, color: Colors.white70),
                    const SizedBox(height: 12),
                    Text(
                      'Camera unavailable ()',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check camera permissions or use manual entry below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _manual,
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Enter Barcode Manually'),
                    ),
                  ],
                ),
              ),
            );
          },
          onDetect: (cap) {
            final v = cap.barcodes.firstOrNull?.rawValue;
            if (v != null && v.isNotEmpty) _handle(v);
          },
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const Text(
                  'Scan barcode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    _ctl.toggleTorch();
                    setState(() => _torch = !_torch);
                  },
                  icon: Icon(
                    _torch ? Icons.flash_on : Icons.flash_off,
                    size: 18,
                  ),
                  label: const Text('Torch'),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: Container(
            width: 280,
            height: 190,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.lightBlueAccent, width: 3),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_found == null && _notFound == null)
                    Text(
                      'Align the barcode within the frame and it will be scanned automatically',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: C.muted),
                    ),
                  if (_notFound != null)
                    Column(
                      children: [
                        Text(
                          'No product found for $_notFound',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextButton(
                          onPressed: () => context.push('/product-form'),
                          child: const Text('Add as new product'),
                        ),
                      ],
                    ),
                  if (_found != null)
                    Row(
                      children: [
                        AppThumb(url: _found!.imageUrl, size: 56),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _found!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                _found!.barcode,
                                style: TextStyle(color: C.muted, fontSize: 12),
                              ),
                              Text(
                                '${money(_found!.price)} / ${_found!.unitLabel}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                            ),
                            onPressed: () {
                              ref.read(cartProvider.notifier).add(_found!);
                              toast(context, '${_found!.name} added');
                              setState(() {
                                _found = null;
                                _last = null;
                              });
                            },
                            child: const Text('Add'),
                          ),
                        ),
                      ],
                    ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: _manual,
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Enter or Paste Barcode Manually'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ═════════════════════════ Cart ═════════════════════════
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  Future<void> _editDiscount(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
  ) async {
    final c = TextEditingController(
      text: cart.discountValue == 0
          ? ''
          : cart.discountValue.toStringAsFixed(
              cart.discountValue % 1 == 0 ? 0 : 2,
            ),
    );
    var percent = cart.percent;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Discount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Amount (₹)')),
                  ButtonSegment(value: true, label: Text('Percent (%)')),
                ],
                selected: {percent},
                onSelectionChanged: (v) => set(() => percent = v.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(prefixText: percent ? '% ' : '₹ '),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      var v = double.tryParse(c.text) ?? 0;
      if (percent && v > 100) v = 100;
      ref.read(cartProvider.notifier).setDiscount(v, percent: percent);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final ctl = ref.read(cartProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your cart'),
        actions: [
          TextButton.icon(
            onPressed: cart.lines.isEmpty
                ? null
                : () async {
                    if (await confirm(
                      context,
                      'Clear cart?',
                      'All items will be removed.',
                      ok: 'Clear',
                      danger: true,
                    )) {
                      ctl.clear();
                      if (context.mounted) context.pop();
                    }
                  },
            icon: Icon(Icons.delete_outline, color: C.muted),
            label: Text('Clear cart', style: TextStyle(color: C.text)),
          ),
        ],
      ),
      body: cart.lines.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Cart is empty',
              message: 'Add products to create a bill.',
              action: ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Add items'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final l in cart.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Dismissible(
                      key: ValueKey(l.product.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => ctl.setQty(l.product.id, 0),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: C.dangerSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.delete, color: C.danger),
                      ),
                      child: AppCard(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            AppThumb(url: l.product.imageUrl, size: 56),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${money(l.product.price)} / ${l.product.unitLabel}',
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: C.primarySoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => ctl.dec(l.product.id),
                                    icon: Icon(
                                      Icons.remove,
                                      size: 18,
                                      color: C.primary,
                                    ),
                                  ),
                                  Text(
                                    '${l.qty}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => ctl.inc(l.product.id),
                                    icon: Icon(
                                      Icons.add,
                                      size: 18,
                                      color: C.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 74,
                              child: Text(
                                money(l.total),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add more items'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Customer',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                AppCard(
                  onTap: () => context.push('/select-customer'),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: C.primarySoft,
                        child: Icon(Icons.person_outline, color: C.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cart.customer?.name ?? 'Walk-in (Cash bill)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              cart.customer?.mobile ??
                                  'No customer details required',
                              style: TextStyle(color: C.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        cart.customer == null ? 'Add' : 'Change',
                        style: TextStyle(
                          color: C.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: TextEditingController(text: cart.notes)
                          ..selection = TextSelection.collapsed(
                            offset: cart.notes.length,
                          ),
                        onChanged: (v) =>
                            ref.read(cartProvider.notifier).setNotes(v),
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: tr('Note on bill (optional)'),
                          prefixIcon: const Icon(Icons.edit_note_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.draw_outlined, color: C.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cart.signature == null
                                  ? 'Customer signature (optional)'
                                  : 'Signature captured',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cart.signature == null
                                    ? C.muted
                                    : C.success,
                              ),
                            ),
                          ),
                          if (cart.signature != null)
                            IconButton(
                              onPressed: () => ref
                                  .read(cartProvider.notifier)
                                  .setSignature(null),
                              icon: Icon(Icons.close, color: C.danger),
                            ),
                          TextButton(
                            onPressed: () async {
                              final sig = await showSignatureDialog(context);
                              if (sig != null)
                                ref
                                    .read(cartProvider.notifier)
                                    .setSignature(sig);
                            },
                            child: Text(
                              cart.signature == null ? 'Add' : 'Redo',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    children: [
                      _SumRow('Subtotal', money(cart.subtotal)),
                      if (cart.tax > 0)
                        _SumRow('Tax (GST)', money(cart.tax)),
                      InkWell(
                        onTap: () => _editDiscount(context, ref, cart),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.remove_circle_outline,
                                size: 20,
                                color: C.muted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Discount',
                                style: TextStyle(color: C.muted, fontSize: 15),
                              ),
                              const Spacer(),
                              Text(
                                cart.discount > 0
                                    ? '${cart.percent ? '${cart.discountValue.toStringAsFixed(cart.discountValue % 1 == 0 ? 0 : 1)}% • ' : ''}${money(cart.discount)}'
                                    : 'Add',
                                style: TextStyle(
                                  color: C.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      _SumRow('Total amount', money(cart.total), bold: true),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: cart.lines.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PrimaryButton(
                  'Continue to payment',
                  icon: Icons.arrow_forward,
                  onPressed: () => context.push('/payment'),
                ),
              ),
            ),
    );
  }
}

class _SumRow extends StatelessWidget {
  const _SumRow(this.a, this.b, {this.bold = false, this.color});
  final String a, b;
  final bool bold;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          a,
          style: TextStyle(
            fontSize: bold ? 17 : 15,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: bold ? C.text : C.muted,
          ),
        ),
        Text(
          b,
          style: TextStyle(
            fontSize: bold ? 22 : 15,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: color ?? C.text,
          ),
        ),
      ],
    ),
  );
}

// ═════════════════════════ Select customer ═════════════════════════
const _walkInMobile = '9999999999';

/// The backend requires a customer on every invoice, so walk-in bills are
/// attached to one shared "Walk-in Customer" record (created on first use).
Future<Customer> ensureWalkIn(WidgetRef ref) async {
  final api = ref.read(apiProvider);
  final found = (await api.searchCustomers(_walkInMobile)).items
      .where((c) => c.mobile == _walkInMobile)
      .firstOrNull;
  if (found != null) return found;
  return api.saveCustomer({
    'name': 'Walk-in Customer',
    'mobileNumber': _walkInMobile,
  });
}

class SelectCustomerScreen extends ConsumerStatefulWidget {
  const SelectCustomerScreen({super.key});
  @override
  ConsumerState<SelectCustomerScreen> createState() => _SelectCustomerState();
}

class _SelectCustomerState extends ConsumerState<SelectCustomerScreen> {
  String _q = '';
  List<Customer>? _remote;

  Future<void> _search(String v) async {
    setState(() => _q = v.trim());
    if (_q.length >= 3) {
      try {
        final r = await ref.read(apiProvider).searchCustomers(_q);
        if (mounted && _q == v.trim()) setState(() => _remote = r.items);
      } catch (_) {}
    } else {
      _remote = null;
    }
  }

  Future<void> _addNew() async {
    final name = TextEditingController();
    final mobile = TextEditingController(
      text: RegExp(r'^\d{10}$').hasMatch(_q) ? _q : '',
    );
    final c = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add new customer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            LabeledField(label: 'Name', controller: name, required: true),
            LabeledField(
              label: 'Mobile number',
              controller: mobile,
              keyboard: TextInputType.phone,
              required: true,
              maxLength: 10,
            ),
            PrimaryButton(
              'Save customer',
              onPressed: () async {
                if (name.text.trim().isEmpty ||
                    !RegExp(r'^[6-9]\d{9}$').hasMatch(mobile.text)) {
                  return toast(
                    ctx,
                    'Enter a name and valid 10-digit mobile',
                    error: true,
                  );
                }
                try {
                  final cu = await ref.read(apiProvider).saveCustomer({
                    'name': name.text.trim(),
                    'mobileNumber': mobile.text,
                  });
                  if (ctx.mounted) Navigator.pop(ctx, cu);
                } catch (e) {
                  if (ctx.mounted) toast(ctx, '$e', error: true);
                }
              },
            ),
          ],
        ),
      ),
    );
    if (c != null) {
      ref.invalidate(customersProvider);
      _choose(c);
    }
  }

  void _choose(Customer? c) {
    ref.read(cartProvider.notifier).setCustomer(c);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(customersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Select customer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSearchField(
            hint: 'Search by name or mobile number',
            onChanged: _search,
          ),
          const SizedBox(height: 14),
          AppCard(
            color: C.primarySoft,
            onTap: () => _choose(null),
            child: Row(
              children: [
                Icon(Icons.directions_walk_rounded, color: C.primary, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue as walk-in (Cash bill)',
                        style: TextStyle(
                          color: C.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'No phone number or details required\nSuitable for quick cash bills',
                        style: TextStyle(color: C.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: C.primary),
              ],
            ),
          ),
          const SectionTitle('Recent customers'),
          all.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('$e'),
            data: (list) {
              var l = _remote ?? list;
              if (_q.isNotEmpty && _remote == null) {
                l = list
                    .where(
                      (c) =>
                          c.name.toLowerCase().contains(_q.toLowerCase()) ||
                          c.mobile.contains(_q),
                    )
                    .toList();
              }
              if (l.isEmpty)
                return Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No customers found',
                      style: TextStyle(color: C.muted),
                    ),
                  ),
                );
              return Column(
                children: [
                  for (final c
                      in l.where((c) => c.mobile != _walkInMobile).take(30))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        onTap: () => _choose(c),
                        child: Row(
                          children: [
                            Avatar(initials(c.name)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    c.mobile,
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: C.muted),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _addNew,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add new customer'),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.primarySoft.withOpacity(.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: C.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Phone number is optional for walk-in cash bills. You can add customer details later, if needed.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════ Payment ═════════════════════════
class UpiArgs {
  UpiArgs({required this.amount, required this.upiId, required this.shop});
  final double amount;
  final String upiId, shop;
}

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});
  @override
  ConsumerState<PaymentScreen> createState() => _PaymentState();
}

class _PaymentState extends ConsumerState<PaymentScreen> {
  String _mode = 'CASH';
  String _creditMode = 'CASH';
  final _received = TextEditingController();
  final _paidNow = TextEditingController(text: '0');
  DateTime _due = DateTime.now().add(const Duration(days: 7));
  bool _busy = false;
  double _outstanding = 0, _limit = 0;

  @override
  void initState() {
    super.initState();
    final t = ref.read(cartProvider).total;
    _received.text = t.toStringAsFixed(t % 1 == 0 ? 0 : 2);
    _received.addListener(() => setState(() {}));
    _paidNow.addListener(() => setState(() {}));
    final c = ref.read(cartProvider).customer;
    if (c != null) _loadBalance(c.id);
  }

  Future<void> _loadBalance(String id) async {
    try {
      final b = await ref.read(apiProvider).customerBalance(id);
      if (mounted)
        setState(() {
          _outstanding = jd(b['totalOutstanding']);
          _limit = jd(b['creditLimit']);
        });
    } catch (_) {}
  }

  Future<void> _submit() async {
    final cart = ref.read(cartProvider);
    final total = cart.total;
    final api = ref.read(apiProvider);
    if (cart.lines.isEmpty) return;
    if (_mode == 'UPI') {
      final pd = await api.paymentDetails().catchError(
        (_) => <String, dynamic>{},
      );
      final upi = js(pd['upiId'] ?? pd['bankUpiId']);
      if (!mounted) return;
      if (upi.isEmpty) {
        toast(
          context,
          'Add your UPI ID in Settings → Bank & UPI to show a QR. Recording as UPI payment.',
        );
      } else {
        context.push(
          '/upi',
          extra: UpiArgs(
            amount: total,
            upiId: upi,
            shop: ref.read(authProvider).session?.businessName ?? 'Shop',
          ),
        );
        return;
      }
    }
    if (_mode == 'CREDIT') {
      if (cart.customer == null)
        return toast(
          context,
          'Select a customer for a credit sale',
          error: true,
        );
      final paid = double.tryParse(_paidNow.text) ?? 0;
      if (paid > total)
        return toast(
          context,
          'Amount received cannot exceed the total',
          error: true,
        );
      if (_limit > 0 && _outstanding + (total - paid) > _limit) {
        final ok = await confirm(
          context,
          'Credit limit exceeded',
          'Projected dues ${money(_outstanding + total - paid)} exceed the limit of ${money(_limit)}. Continue anyway?',
          ok: 'Continue',
        );
        if (!ok) return;
      }
    }
    if (_mode == 'CASH') {
      final r = double.tryParse(_received.text) ?? 0;
      if (r < total)
        return toast(
          context,
          'Amount received is less than the total',
          error: true,
        );
    }
    await checkoutAndFinish(
      context,
      ref,
      mode: _mode,
      received: _mode == 'CASH' ? double.tryParse(_received.text) : null,
      paidNow: _mode == 'CREDIT' ? (double.tryParse(_paidNow.text) ?? 0) : null,
      due: _due,
      creditMode: _creditMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = cart.total;
    final auth = ref.watch(authProvider);
    final received = double.tryParse(_received.text) ?? 0;
    final paidNow = double.tryParse(_paidNow.text) ?? 0;
    final methods = [
      ('CASH', Icons.payments_outlined, 'Cash'),
      ('UPI', Icons.qr_code_2_rounded, 'UPI'),
      ('CARD', Icons.credit_card, 'Card'),
      ('CREDIT', Icons.person_outline, 'Credit'),
    ];
    final isCredit = _mode == 'CREDIT';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isCredit ? 'Credit Sale' : 'Payment'),
            Text(
              auth.session?.businessName ?? '',
              style: TextStyle(
                fontSize: 12,
                color: C.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: StatusChip(
              auth.isGst ? 'GST mode' : 'Simple mode',
              color: C.primary,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shopping_cart_outlined, color: C.primary),
                    SizedBox(width: 8),
                    Text(
                      'Bill summary',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _SumRow('Items (${cart.count})', money(cart.subtotal)),
                if (cart.discount > 0)
                  _SumRow(
                    'Discount',
                    '- ${money(cart.discount)}',
                    color: C.success,
                  ),
                if (cart.tax > 0)
                  _SumRow(
                    'Tax (GST)',
                    '+ ${money(cart.tax)}',
                    color: C.muted,
                  ),
                const Divider(),
                _SumRow('Total amount', money(total), bold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select payment method',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final m in methods)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _mode = m.$1);
                      if (m.$1 == 'CREDIT' && cart.customer == null)
                        context.push('/select-customer').then((_) {
                          final c = ref.read(cartProvider).customer;
                          if (c != null) _loadBalance(c.id);
                        });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _mode == m.$1 ? C.primarySoft : C.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _mode == m.$1 ? C.primary : C.border,
                          width: _mode == m.$1 ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(m.$2, color: C.primary),
                          const SizedBox(height: 4),
                          Text(
                            m.$3,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_mode == 'CASH') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Amount received (₹)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  onPressed: () => _received.text = total.toStringAsFixed(total % 1 == 0 ? 0 : 2),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Exact Total', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _received,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: total.toStringAsFixed(total % 1 == 0 ? 0 : 2),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: received >= total ? C.successSoft : C.warningSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    received >= total ? Icons.payments_outlined : Icons.pending_outlined,
                    color: received >= total ? C.success : C.warning,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    received >= total ? 'Change to return' : 'Pending balance',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: received >= total ? C.success : C.warning,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    received >= total
                        ? money((received - total).clamp(0, double.infinity))
                        : money((total - received).clamp(0, double.infinity)),
                    style: TextStyle(
                      color: received >= total ? C.success : C.warning,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_mode == 'UPI' || _mode == 'CARD') ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: C.primarySoft.withOpacity(.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _mode == 'UPI'
                    ? 'A QR code with your UPI ID will be shown for the customer to scan.'
                    : 'Take the card payment on your POS machine, then create the bill.',
                style: TextStyle(color: C.muted),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await razorpayCheckout(context, ref, mode: _mode);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('Pay online with Razorpay'),
            ),
          ],
          if (isCredit) ...[
            const Text(
              'Customer (required)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            AppCard(
              onTap: () => context.push('/select-customer').then((_) {
                final c = ref.read(cartProvider).customer;
                if (c != null) _loadBalance(c.id);
              }),
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: C.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cart.customer?.name ?? 'Select customer',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cart.customer == null ? C.muted : C.text,
                      ),
                    ),
                  ),
                  if (cart.customer != null)
                    IconButton(
                      onPressed: () =>
                          ref.read(cartProvider.notifier).setCustomer(null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
            if (cart.customer != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.primarySoft.withOpacity(.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer outstanding',
                            style: TextStyle(color: C.muted, fontSize: 12),
                          ),
                          Text(
                            money(_outstanding),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credit limit',
                            style: TextStyle(color: C.muted, fontSize: 12),
                          ),
                          Text(
                            _limit > 0 ? money(_limit) : 'Not set',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              'Amount to receive now (optional)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _paidNow,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: '₹  '),
            ),
            Text(
              'Leave as 0 if no payment received now.',
              style: TextStyle(color: C.muted, fontSize: 12),
            ),
            if (paidNow > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const [
                    ('CASH', 'Cash'),
                    ('UPI', 'UPI'),
                    ('CARD', 'Card'),
                  ])
                    ChoiceChip(
                      label: Text(m.$2),
                      selected: _creditMode == m.$1,
                      onSelected: (_) => setState(() => _creditMode = m.$1),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        if (cart.customer == null)
                          return toast(
                            context,
                            'Select a customer for a credit sale',
                            error: true,
                          );
                        setState(() => _busy = true);
                        try {
                          await razorpayCheckout(
                            context,
                            ref,
                            mode: 'CREDIT',
                            partial: paidNow,
                          );
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Collect this part online (Razorpay)'),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: C.warningSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.credit_card, color: C.warning),
                  const SizedBox(width: 10),
                  const Text(
                    'Balance due',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    money((total - paidNow).clamp(0, double.infinity)),
                    style: TextStyle(
                      color: C.warning,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final d = await pickDate(
                  context,
                  initial: _due,
                  first: DateTime.now(),
                );
                if (d != null) setState(() => _due = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: tr('Due date'),
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(
                  dateShort(_due),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          if (!isCredit) ...[
            const SizedBox(height: 16),
            const Text(
              'Customer (optional)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            AppCard(
              onTap: () => context.push('/select-customer'),
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: C.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cart.customer?.name ?? 'Select or search customer',
                      style: TextStyle(
                        color: cart.customer == null ? C.muted : C.text,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: C.muted),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            isCredit
                ? 'Save credit bill (${money(total)})'
                : _mode == 'UPI'
                ? 'Show UPI QR (${money(total)})'
                : 'Create bill (${money(total)})',
            loading: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              try {
                await _submit();
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Request body for POST /api/pos/checkout (also used by the Razorpay flow).
Map<String, dynamic> buildCheckoutBody(
  CartState cart,
  Customer customer, {
  required String mode,
  required double paid,
  double? received,
  String? creditMode,
  DateTime? due,
}) => {
  'mobileNumber': customer.mobile,
  'customerName': customer.name,
  'items': [
    for (final l in cart.lines) {'productId': l.product.id, 'quantity': l.qty},
  ],
  'paymentMode': mode,
  'paidAmount': paid,
  'discount': cart.discount,
  'discountType': cart.discountType,
  'discountValue': cart.discountValue,
  if (mode == 'CASH' && received != null) ...{
    'receivedAmount': received,
    'cashReceived': received,
  },
  if (mode == 'CREDIT' &&
      paid > 0 &&
      creditMode != null &&
      creditMode != 'NONE')
    'creditPaymentMode': creditMode,
  if (due != null) 'dueDate': iso(due),
  if (cart.notes.trim().isNotEmpty) 'notes': cart.notes.trim(),
  if (cart.signature != null) 'signatureBase64': cart.signature,
};

/// Creates the bill through POST /api/pos/checkout and opens the success screen.
Future<void> checkoutAndFinish(
  BuildContext context,
  WidgetRef ref, {
  required String mode,
  double? received,
  double? paidNow,
  DateTime? due,
  String? creditMode,
}) async {
  final cart = ref.read(cartProvider);
  final api = ref.read(apiProvider);
  try {
    final customer = cart.customer ?? await ensureWalkIn(ref);
    final paid = mode == 'CREDIT' ? (paidNow ?? 0) : cart.total;
    final inv = await api.checkout(
      buildCheckoutBody(
        cart,
        customer,
        mode: mode,
        paid: paid,
        received: received,
        creditMode: creditMode ?? 'CASH',
        due: due,
      ),
    );
    ref.read(cartProvider.notifier).clear();
    ref.invalidate(productsProvider);
    ref.invalidate(homeProvider);
    ref.invalidate(customersProvider);
    if (context.mounted) context.pushReplacement('/bill-success', extra: inv);
  } catch (e) {
    if (context.mounted) toast(context, '$e', error: true);
  }
}

class UpiScreen extends ConsumerStatefulWidget {
  const UpiScreen({super.key, required this.args});
  final UpiArgs args;
  @override
  ConsumerState<UpiScreen> createState() => _UpiState();
}

class _UpiState extends ConsumerState<UpiScreen> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final uri =
        'upi://pay?pa=${Uri.encodeComponent(a.upiId)}&pn=${Uri.encodeComponent(a.shop)}&am=${a.amount.toStringAsFixed(2)}&cu=INR';
    return Scaffold(
      appBar: AppBar(title: const Text('UPI Payment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: C.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: C.primary, size: 36),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total amount to pay',
                      style: TextStyle(color: C.muted),
                    ),
                    Text(
                      money(a.amount),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              children: [
                const Text(
                  'Scan and pay using any UPI app',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                QrImageView(
                  data: uri,
                  size: 220,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(8),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'UPI ID',
                    style: TextStyle(
                      color: C.muted.withOpacity(.9),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.upiId,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: a.upiId));
                          toast(context, 'UPI ID copied');
                        },
                        icon: const Icon(Icons.copy, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.warningSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: C.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Waiting for payment confirmation\nCheck your UPI app for the payment status.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await checkoutAndFinish(context, ref, mode: 'UPI');
                    if (mounted) setState(() => _busy = false);
                  },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Record payment manually'),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.warningSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: C.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Verify receipt before marking paid. Do not mark as paid until you confirm the payment in your bank/UPI app.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════ Bill success ═════════════════════════
class BillSuccessScreen extends ConsumerWidget {
  const BillSuccessScreen({super.key, required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    final s = ref.watch(authProvider).session;
    final shop = s?.businessName ?? '';
    Widget action(IconData i, String t, Color c, VoidCallback f) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: f,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.border),
            ),
            child: Column(
              children: [
                Icon(i, color: c, size: 28),
                const SizedBox(height: 6),
                Text(
                  t,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvoked: (_) => context.go('/pos'),
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 20),
              Center(
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: C.success,
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 46,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Bill created successfully!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              Center(
                child: Text(
                  'Here are the details of your bill.',
                  style: TextStyle(color: C.muted),
                ),
              ),
              const SizedBox(height: 18),
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: C.primarySoft,
                          child: Icon(
                            Icons.description_outlined,
                            color: C.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bill number',
                              style: TextStyle(color: C.muted, fontSize: 12),
                            ),
                            Text(
                              invoice.number,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              dateTime12(invoice.createdAt),
                              style: TextStyle(color: C.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: invoice.due > 0 ? C.warningSoft : C.successSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.currency_rupee,
                            color: invoice.due > 0 ? C.warning : C.success,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                money(invoice.total),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                invoice.due > 0
                                    ? 'Due ${money(invoice.due)} • ${invoice.paymentMode}'
                                    : 'Paid • ${invoice.paymentMode}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: invoice.due > 0
                                      ? C.warning
                                      : C.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: C.primarySoft,
                          child: Icon(
                            Icons.storefront_rounded,
                            color: C.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          shop,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  action(
                    Icons.print_outlined,
                    'Print',
                    C.primary,
                    () => InvoiceActions.print(context, api, invoice),
                  ),
                  action(
                    Icons.chat_rounded,
                    'Share on\nWhatsApp',
                    const Color(0xFF25D366),
                    () =>
                        InvoiceActions.share(context, api, invoice, shop: shop),
                  ),
                  action(
                    Icons.picture_as_pdf_outlined,
                    'Download\nPDF',
                    C.primary,
                    () => InvoiceActions.download(context, api, invoice),
                  ),
                  action(
                    Icons.receipt_long_outlined,
                    'Thermal\nprint',
                    C.primary,
                    () => printThermal(context, ref, invoice),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => context.go('/pos'),
                icon: const Icon(Icons.add),
                label: const Text('New bill'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.push('/invoice/${invoice.id}'),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View invoice'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
