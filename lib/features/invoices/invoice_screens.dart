import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../home/home_screen.dart';
import '../pos/invoice_actions.dart';
import '../pos/thermal_printer.dart';
import '../../core/utils/sound.dart';

Future<Product?> showProductPicker(BuildContext context, WidgetRef ref) {
  final all = ref.read(productsProvider).valueOrNull ?? [];
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      var q = '';
      return StatefulBuilder(
        builder: (ctx, set) {
          final l = all
              .where(
                (p) =>
                    p.name.toLowerCase().contains(q) ||
                    p.sku.toLowerCase().contains(q) ||
                    p.barcode.toLowerCase().contains(q),
              )
              .toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * .8,
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Select product',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: AppSearchField(
                    hint: 'Search products',
                    onChanged: (v) => set(() => q = v.toLowerCase()),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: l.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: AppThumb(url: l[i].imageUrl, size: 44),
                      title: Text(l[i].name),
                      subtitle: Text(
                        '${money(l[i].price)} • Stock ${l[i].stock}',
                      ),
                      onTap: () {
                        PosSound.playBeep();
                        Navigator.pop(ctx, l[i]);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<Customer?> showCustomerPicker(BuildContext context, WidgetRef ref) {
  final all = ref.read(customersProvider).valueOrNull ?? [];
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      var q = '';
      return StatefulBuilder(
        builder: (ctx, set) {
          final l = all
              .where(
                (c) => c.name.toLowerCase().contains(q) || c.mobile.contains(q),
              )
              .toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * .75,
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Select customer',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: AppSearchField(
                    hint: 'Search by name or mobile',
                    onChanged: (v) => set(() => q = v.toLowerCase()),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: l.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: Avatar(initials(l[i].name), size: 40),
                      title: Text(l[i].name),
                      subtitle: Text(l[i].mobile),
                      onTap: () {
                        PosSound.playBeep();
                        Navigator.pop(ctx, l[i]);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ═════════════════════════ Bills list ═════════════════════════
class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});
  @override
  ConsumerState<BillsScreen> createState() => _BillsState();
}

class _BillsState extends ConsumerState<BillsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _status = 'All', _mode = 'All', _q = '';
  List<Invoice>? _search;

  Future<void> _doSearch(String v) async {
    _q = v.trim();
    if (_q.length < 2) return setState(() => _search = null);
    try {
      final r = await ref.read(apiProvider).searchInvoices(_q);
      if (mounted) setState(() => _search = r);
    } catch (_) {}
  }

  Future<void> _pickMonth() async {
    final d = await pickDate(context, initial: _month, last: DateTime.now());
    if (d != null) setState(() => _month = DateTime(d.year, d.month));
  }

  void _filters() {
    var s = _status, m = _mode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Widget group(
            String t,
            List<String> opts,
            String cur,
            void Function(String) f,
          ) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8),
                child: Text(
                  t,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final o in opts)
                    ChoiceChip(
                      label: Text(o),
                      selected: cur == o,
                      onSelected: (_) => set(() => f(o)),
                    ),
                ],
              ),
            ],
          );
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter invoices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                group(
                  'Payment status',
                  const ['All', 'Paid', 'Partial', 'Unpaid', 'Cancelled'],
                  s,
                  (v) => s = v,
                ),
                group(
                  'Payment method',
                  const ['All', 'CASH', 'UPI', 'CARD', 'CREDIT'],
                  m,
                  (v) => m = v,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _status = 'All';
                            _mode = 'All';
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear filters'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _status = s;
                            _mode = m;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Apply filters'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(invoicesProvider(_month));
    final s = ref.watch(authProvider).session;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Clever Bill',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: C.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _filters,
                    icon: Icon(
                      Icons.tune_rounded,
                      color: (_status != 'All' || _mode != 'All')
                          ? C.primary
                          : C.text,
                    ),
                  ),
                  const NotificationBell(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s?.businessName ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  InkWell(
                    onTap: _pickMonth,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            color: C.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            monthLabel(_month),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.keyboard_arrow_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppSearchField(
                    hint: 'Search by invoice no., customer or amount',
                    onChanged: _doSearch,
                  ),
                ],
              ),
            ),
            Expanded(
              child: AsyncBody<List<Invoice>>(
                value: async,
                onRetry: () => ref.invalidate(invoicesProvider(_month)),
                builder: (month) {
                  final base = _search ?? month;
                  final totalSales = month
                      .where((i) => !i.cancelled)
                      .fold(0.0, (a, i) => a + i.total);
                  int cnt(String st) =>
                      base.where((i) => i.uiStatus == st).length;
                  var list = base
                      .where((i) => _status == 'All' || i.uiStatus == _status)
                      .where((i) => _mode == 'All' || i.paymentMode == _mode)
                      .toList();
                  if (_q.isNotEmpty && _search == null) {
                    list = list
                        .where(
                          (i) =>
                              i.number.toLowerCase().contains(
                                _q.toLowerCase(),
                              ) ||
                              i.customerName.toLowerCase().contains(
                                _q.toLowerCase(),
                              ) ||
                              i.total.toStringAsFixed(0).contains(_q),
                        )
                        .toList();
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: C.primarySoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Sales (${monthLabel(_month, short: true)})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              money(totalSales),
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${month.length} invoices',
                              style: TextStyle(color: C.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final st in const [
                              'All',
                              'Paid',
                              'Partial',
                              'Unpaid',
                              'Cancelled',
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    '$st ${st == 'All' ? base.length : cnt(st)}',
                                  ),
                                  selected: _status == st,
                                  showCheckmark: false,
                                  selectedColor: C.primary,
                                  labelStyle: TextStyle(
                                    color: _status == st
                                        ? Colors.white
                                        : C.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _status = st),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (list.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No invoices found',
                          ),
                        )
                      else
                        for (final i in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                              onTap: () => context.push('/invoice/${i.id}'),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              i.number,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            StatusChip.forStatus(i.uiStatus),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              size: 16,
                                              color: C.muted,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                i.customerName,
                                                style: TextStyle(
                                                  color: C.muted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        dateShort(i.createdAt),
                                        style: TextStyle(
                                          color: C.muted,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      Text(
                                        timeOnly(i.createdAt),
                                        style: TextStyle(
                                          color: C.muted,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      Text(
                                        money(i.total),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ],
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
            ),
          ],
        ),
      ),
    );
  }
}

String monthLabel(DateTime d, {bool short = false}) {
  const m = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return short
      ? '${m[d.month - 1].substring(0, 3)} ${d.year}'
      : '${m[d.month - 1]} ${d.year}';
}

// ═════════════════════════ Invoice detail ═════════════════════════
final invoiceDetailProvider = FutureProvider.autoDispose
    .family<Invoice, String>((ref, id) => ref.watch(apiProvider).invoice(id));

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invoiceDetailProvider(id));
    final api = ref.read(apiProvider);
    final shop = ref.watch(authProvider).session?.businessName ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Details')),
      body: AsyncBody<Invoice>(
        value: async,
        onRetry: () => ref.invalidate(invoiceDetailProvider(id)),
        builder: (inv) {
          final isPaid = inv.uiStatus == 'Paid';
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? C.successSoft
                            : inv.cancelled
                            ? C.dangerSoft
                            : C.warningSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Text(
                            inv.number,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 10),
                          StatusChip.forStatus(inv.uiStatus),
                          const Spacer(),
                          Text(
                            dateTime12(inv.createdAt),
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 12, color: C.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                color: C.primary,
                                size: 30,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                shop,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: C.primary,
                                size: 30,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inv.customerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${inv.customer?.mobile ?? ''} • ${inv.paymentMode}',
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: C.bg,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    'Item',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Qty',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Rate',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Amount',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final it in inv.items)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      it.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${it.qty}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      money(it.unitPrice),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      money(it.lineTotal),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                _kv('Subtotal', money(inv.subtotal)),
                                if (inv.tax > 0) ...[
                                  if (inv.cgst > 0)
                                    _kv('CGST', money(inv.cgst)),
                                  if (inv.sgst > 0)
                                    _kv('SGST', money(inv.sgst)),
                                  if (inv.igst > 0)
                                    _kv('IGST', money(inv.igst)),
                                ],
                                if (inv.discount > 0)
                                  _kv(
                                    'Discount',
                                    '- ${money(inv.discount)}',
                                    color: C.success,
                                  ),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: C.primarySoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: _kv(
                                    'Total Amount',
                                    money(inv.total),
                                    bold: true,
                                  ),
                                ),
                                _kv(
                                  'Amount paid (${inv.paymentMode})',
                                  money(inv.paid),
                                ),
                                if (inv.change > 0)
                                  _kv(
                                    'Change returned',
                                    money(inv.change),
                                    color: C.success,
                                  ),
                                if (inv.due > 0 && !inv.cancelled)
                                  _kv(
                                    'Balance due',
                                    money(inv.due),
                                    color: C.danger,
                                    bold: true,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              InvoiceActions.print(context, api, inv),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Print'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => InvoiceActions.share(
                            context,
                            api,
                            inv,
                            shop: shop,
                          ),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'thermal') {
                            await printThermal(context, ref, inv);
                            return;
                          }
                          if (v == 'pdf') {
                            await InvoiceActions.download(context, api, inv);
                            return;
                          }
                          if (v == 'pay') {
                            await context.push('/receive-payment', extra: inv);
                            ref.invalidate(invoiceDetailProvider(id));
                            return;
                          }
                          if (v == 'return') {
                            await context.push('/return-create', extra: inv);
                            return;
                          }
                          if (v == 'cancel') {
                            if (await confirm(
                              context,
                              'Cancel invoice?',
                              'Stock will be restored. This cannot be undone.',
                              ok: 'Cancel invoice',
                              danger: true,
                            )) {
                              try {
                                await api.cancelInvoice(inv.id);
                                ref.invalidate(invoiceDetailProvider(id));
                                ref.invalidate(productsProvider);
                                if (context.mounted)
                                  toast(context, 'Invoice cancelled');
                              } catch (e) {
                                if (context.mounted)
                                  toast(context, '$e', error: true);
                              }
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          if (inv.due > 0 && !inv.cancelled)
                            const PopupMenuItem(
                              value: 'pay',
                              child: Text('Receive payment'),
                            ),
                          const PopupMenuItem(
                            value: 'thermal',
                            child: Text('Print receipt (Bluetooth)'),
                          ),
                          const PopupMenuItem(
                            value: 'pdf',
                            child: Text('Download PDF'),
                          ),
                          if (!inv.cancelled)
                            const PopupMenuItem(
                              value: 'return',
                              child: Text('Return items'),
                            ),
                          if (!inv.cancelled)
                            PopupMenuItem(
                              value: 'cancel',
                              child: Text(
                                'Cancel invoice',
                                style: TextStyle(color: C.danger),
                              ),
                            ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: C.primary),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.more_horiz, color: C.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String a, String b, {Color? color, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          a,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            fontSize: bold ? 16 : 14,
          ),
        ),
        Text(
          b,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            fontSize: bold ? 18 : 14,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ═════════════════════════ Create GST invoice (3 steps) ═════════════════════════
class _GstLine {
  _GstLine(this.p, this.qty);
  Product p;
  int qty;
  double get base => p.price * qty;
  double get tax => base * p.taxPercent / 100;
}

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});
  @override
  ConsumerState<CreateInvoiceScreen> createState() => _CreateInvoiceState();
}

class _CreateInvoiceState extends ConsumerState<CreateInvoiceScreen> {
  int _step = 0;
  Customer? _customer;
  final List<_GstLine> _lines = [];
  String _mode = 'CASH';
  bool _busy = false;

  double get _taxable => _lines.fold(0.0, (a, l) => a + l.base);
  double get _tax => _lines.fold(0.0, (a, l) => a + l.tax);

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final total = _taxable + _tax;
      final inv = await ref.read(apiProvider).createInvoice({
        'customerId': _customer!.id,
        'items': [
          for (final l in _lines) {'productId': l.p.id, 'quantity': l.qty},
        ],
        'paymentMode': _mode == 'CREDIT' ? 'CREDIT' : _mode,
        'paidAmount': _mode == 'CREDIT' ? 0 : total,
        if (_mode == 'CREDIT')
          'dueDate': iso(DateTime.now().add(const Duration(days: 15))),
      });
      ref.invalidate(productsProvider);
      ref.invalidate(homeProvider);
      if (mounted) context.pushReplacement('/bill-success', extra: inv);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    if (_step == 0 && _customer == null)
      return toast(context, 'Select a customer', error: true);
    if (_step == 1 && _lines.isEmpty)
      return toast(context, 'Add at least one item', error: true);
    if (_step < 2)
      setState(() => _step++);
    else
      _submit();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(authProvider).session;
    const steps = ['Details', 'Items', 'Review'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Invoice'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: StatusChip('GST Mode', color: C.primary),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: InkWell(
                      onTap: i < _step ? () => setState(() => _step = i) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: i == _step ? C.primary : C.border,
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: i <= _step
                                  ? C.primary
                                  : C.border,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              steps[i],
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: i == _step ? C.primary : C.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_step == 0) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Business details',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s?.businessName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          s?.branchName ?? 'Main Branch',
                          style: TextStyle(color: C.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    onTap: () async {
                      final c = await showCustomerPicker(context, ref);
                      if (c != null) setState(() => _customer = c);
                    },
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, color: C.primary, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _customer == null
                              ? Text(
                                  'Select customer',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _customer!.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _customer!.gstin.isEmpty
                                          ? _customer!.mobile
                                          : 'GSTIN: ${_customer!.gstin}',
                                      style: TextStyle(color: C.muted),
                                    ),
                                  ],
                                ),
                        ),
                        Icon(Icons.chevron_right, color: C.muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tax type (CGST+SGST or IGST) is decided automatically from the customer’s state code.',
                    style: TextStyle(color: C.muted, fontSize: 12.5),
                  ),
                ],
                if (_step == 1) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Items (Tax Exclusive)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final p = await showProductPicker(context, ref);
                          if (p == null) return;
                          setState(() {
                            final ex = _lines
                                .where((l) => l.p.id == p.id)
                                .firstOrNull;
                            if (ex != null) {
                              ex.qty++;
                            } else {
                              _lines.add(_GstLine(p, 1));
                            }
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  if (_lines.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text(
                          'No items added',
                          style: TextStyle(color: C.muted),
                        ),
                      ),
                    ),
                  for (final l in _lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${money(l.p.price)} • GST ${l.p.taxPercent.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() {
                                if (l.qty > 1) {
                                  l.qty--;
                                } else {
                                  _lines.remove(l);
                                }
                              }),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '${l.qty}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => l.qty++),
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: C.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (_step == 2) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _customer?.name ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const Divider(),
                        for (final l in _lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(child: Text('${l.p.name} × ${l.qty}')),
                                Text(money(l.base)),
                              ],
                            ),
                          ),
                        const Divider(),
                        _r('Taxable amount', money(_taxable)),
                        _r('Estimated GST', money(_tax)),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: C.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _r(
                            'Total (incl. tax)',
                            money(_taxable + _tax),
                            bold: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Payment',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in const ['CASH', 'UPI', 'CARD', 'CREDIT'])
                        ChoiceChip(
                          label: Text(m == 'CREDIT' ? 'Credit (unpaid)' : m),
                          selected: _mode == m,
                          onSelected: (_) => setState(() => _mode = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Final CGST/SGST/IGST split is calculated by the server.',
                    style: TextStyle(color: C.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PrimaryButton(
                _step == 2
                    ? 'Create invoice'
                    : _step == 1
                    ? 'Review Bill'
                    : 'Next',
                icon: _step == 2 ? null : Icons.arrow_forward,
                loading: _busy,
                onPressed: _next,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _r(String a, String b, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          a,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        Text(
          b,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            fontSize: bold ? 18 : 14,
          ),
        ),
      ],
    ),
  );
}

// ═════════════════════════ Returns ═════════════════════════
class ReturnCreateScreen extends ConsumerStatefulWidget {
  const ReturnCreateScreen({super.key, required this.invoice});
  final Invoice invoice;
  @override
  ConsumerState<ReturnCreateScreen> createState() => _ReturnCreateState();
}

class _ReturnCreateState extends ConsumerState<ReturnCreateScreen> {
  final Map<String, int> _qty = {};
  String _reason = 'Damaged';
  String _refund = 'CASH';
  bool _busy = false;
  static const reasons = [
    'Damaged',
    'Wrong item',
    'Expired',
    'Customer changed mind',
    'Other',
  ];

  double get _refundAmount {
    var t = 0.0;
    for (final it in widget.invoice.items) {
      final q = _qty[it.productId] ?? 0;
      if (q > 0) t += it.unitPrice * q;
    }
    return t;
  }

  Future<void> _submit() async {
    final items = [
      for (final e in _qty.entries.where((e) => e.value > 0))
        {'productId': e.key, 'quantity': e.value},
    ];
    if (items.isEmpty)
      return toast(context, 'Select at least one item to return', error: true);
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).createReturn({
        'invoiceId': widget.invoice.id,
        'returnReason': _reason,
        'refundMode': _refund,
        'items': items,
      });
      ref.invalidate(productsProvider);
      if (mounted) {
        toast(context, 'Return recorded');
        context.pop();
      }
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    return Scaffold(
      appBar: AppBar(title: const Text('Return & refund')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original invoice',
                        style: TextStyle(color: C.muted, fontSize: 12),
                      ),
                      Text(
                        inv.number,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        dateTime12(inv.createdAt),
                        style: TextStyle(color: C.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/invoice/${inv.id}'),
                  child: const Text('View invoice'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final it in inv.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                color: (_qty[it.productId] ?? 0) > 0
                    ? C.primarySoft.withOpacity(.5)
                    : null,
                child: Row(
                  children: [
                    Checkbox(
                      value: (_qty[it.productId] ?? 0) > 0,
                      onChanged: (v) => setState(
                        () => _qty[it.productId] = v == true ? 1 : 0,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${money(it.unitPrice)} each • ${it.qty} sold',
                            style: TextStyle(color: C.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    if ((_qty[it.productId] ?? 0) > 0) ...[
                      IconButton(
                        onPressed: () => setState(
                          () => _qty[it.productId] =
                              ((_qty[it.productId] ?? 1) - 1).clamp(1, it.qty),
                        ),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${_qty[it.productId]}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        onPressed: () => setState(
                          () => _qty[it.productId] =
                              ((_qty[it.productId] ?? 1) + 1).clamp(1, it.qty),
                        ),
                        icon: Icon(Icons.add_circle_outline, color: C.primary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Reason for return *',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _reason,
            items: [
              for (final r in reasons)
                DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: (v) => setState(() => _reason = v ?? _reason),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Refund amount',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      money(_refundAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _refund,
                  decoration: InputDecoration(labelText: tr('Refund method')),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                    DropdownMenuItem(value: 'CARD', child: Text('Card')),
                    DropdownMenuItem(
                      value: 'CREDIT',
                      child: Text('Adjust against dues'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _refund = v ?? _refund),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton('Submit return', loading: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}

class ReturnsScreen extends ConsumerStatefulWidget {
  const ReturnsScreen({super.key});
  @override
  ConsumerState<ReturnsScreen> createState() => _ReturnsState();
}

class _ReturnsState extends ConsumerState<ReturnsScreen> {
  late Future<PageData<ReturnRec>> _f = ref.read(apiProvider).returns();
  void _reload() => setState(() => _f = ref.read(apiProvider).returns());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: blueAppBar(context, 'Returns', subtitle: 'Sales returns & refunds'),
    body: FutureBuilder<PageData<ReturnRec>>(
      future: _f,
      builder: (_, snap) {
        if (!snap.hasData)
          return snap.hasError
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load',
                  message: '${snap.error}',
                )
              : const Center(child: CircularProgressIndicator());
        final l = snap.data!.items;
        if (l.isEmpty)
          return const EmptyState(
            icon: Icons.assignment_return_outlined,
            title: 'No returns yet',
            message:
                'Returns are created from an invoice → More → Return items.',
          );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final r in l)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            r.number,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          StatusChip.forStatus(
                            r.status.isEmpty
                                ? ''
                                : r.status[0] +
                                      r.status.substring(1).toLowerCase(),
                          ),
                        ],
                      ),
                      Text(
                        '${r.invoiceNumber} • ${r.customerName}',
                        style: TextStyle(color: C.muted),
                      ),
                      Text(
                        '${r.reason}  •  ${dateShort(r.createdAt)}',
                        style: TextStyle(color: C.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Refund ${money(r.refund)}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          if (r.status == 'PENDING') ...[
                            TextButton(
                              onPressed: () async {
                                await ref.read(apiProvider).rejectReturn(r.id);
                                _reload();
                              },
                              child: Text(
                                'Reject',
                                style: TextStyle(color: C.danger),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await ref.read(apiProvider).approveReturn(r.id);
                                ref.invalidate(productsProvider);
                                _reload();
                              },
                              child: const Text('Approve'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
