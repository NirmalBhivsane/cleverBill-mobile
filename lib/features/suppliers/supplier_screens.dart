import 'dart:typed_data';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../inventory/inventory_screens.dart'
    show suppliersProvider, purchasesProvider;
import '../invoices/invoice_screens.dart' show showProductPicker;

export 'supplier_constants.dart';
export 'supplier_export.dart';
export 'supplier_analytics_sheet.dart';
export 'supplier_main_screens.dart';
export 'supplier_detail_screen.dart';
export 'supplier_form_screen.dart';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• RFQ â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
String rfqLabel(String s) => switch (s) {
  'DRAFT' => 'Draft',
  'SENT' => 'Sent',
  'QUOTATION_RECEIVED' => 'Quote received',
  'CONVERTED_TO_PO' => 'Converted',
  'CANCELLED' => 'Cancelled',
  _ => s,
};

final rfqsProvider = FutureProvider.autoDispose<List<Rfq>>(
  (ref) => ref.watch(apiProvider).rfqs(),
);

class RfqScreen extends ConsumerStatefulWidget {
  const RfqScreen({super.key});
  @override
  ConsumerState<RfqScreen> createState() => _RfqState();
}

class _RfqState extends ConsumerState<RfqScreen> {
  int _tab = 0;

  Future<void> _create() async {
    List<Supplier> sup = ref.read(suppliersProvider).valueOrNull ?? [];
    if (sup.isEmpty) {
      try {
        sup = await ref.read(suppliersProvider.future);
      } catch (e) {
        debugPrint('Error loading suppliers: $e');
      }
    }
    String? supplierId;
    DateTime delivery = DateTime.now().add(const Duration(days: 3));
    final items =
        <
          ({Product p, TextEditingController qty, TextEditingController price})
        >[];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New RFQ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Supplier *',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Consumer(
                  builder: (ctx, ref, _) {
                    final supAsync = ref.watch(suppliersProvider);
                    final list = supAsync.valueOrNull ?? sup;
                    if (supAsync.isLoading && list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      );
                    }
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'No suppliers found. Please add a supplier first.',
                                style: TextStyle(color: C.muted, fontSize: 13),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                context.push('/supplier-form');
                              },
                              child: const Text('+ Add Supplier'),
                            ),
                          ],
                        ),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      value: list.any((s) => s.id == supplierId) ? supplierId : null,
                      hint: const Text('Select supplier'),
                      isExpanded: true,
                      items: [
                        for (final s in list)
                          DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name.isNotEmpty ? s.name : 'Unnamed Supplier'),
                          ),
                      ],
                      onChanged: (v) => set(() => supplierId = v),
                      validator: (v) => v == null ? 'Please select a supplier' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final d = await pickDate(
                      ctx,
                      initial: delivery,
                      first: DateTime.now(),
                    );
                    if (d != null) set(() => delivery = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: tr('Delivery date *'),
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(dateShort(delivery)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Requested items *',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final it in items)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            it.p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: it.qty,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: tr('Qty'),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: it.price,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: tr('â‚¹ each'),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => set(() => items.remove(it)),
                          icon: Icon(Icons.delete_outline, color: C.danger),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final p = await showProductPicker(ctx, ref);
                    if (p != null)
                      set(
                        () => items.add((
                          p: p,
                          qty: TextEditingController(text: '1'),
                          price: TextEditingController(
                            text: '${p.purchasePrice}',
                          ),
                        )),
                      );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add another item'),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  'Send RFQ',
                  icon: Icons.send_outlined,
                  onPressed: () async {
                    if (supplierId == null || items.isEmpty)
                      return toast(
                        ctx,
                        'Select a supplier and add items',
                        error: true,
                      );
                    try {
                      await ref.read(apiProvider).createRfq({
                        'supplierId': supplierId,
                        'deliveryDate': iso(delivery),
                        'items': [
                          for (final i in items)
                            {
                              'productId': i.p.id,
                              'quantity': int.tryParse(i.qty.text) ?? 1,
                              'expectedPrice':
                                  double.tryParse(i.price.text) ?? 0,
                              'unit': i.p.unit,
                            },
                        ],
                      });
                      ref.invalidate(rfqsProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) toast(ctx, '$e', error: true);
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rfqsProvider);
    ref.watch(suppliersProvider);
    const tabs = ['All', 'Draft', 'Sent', 'Converted'];
    return Scaffold(
      appBar: blueAppBar(
        context,
        'Supplier RFQs',
        subtitle: 'Request quotations and compare prices',
        actions: [
          TextButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New RFQ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: AsyncBody<List<Rfq>>(
        value: async,
        onRetry: () => ref.invalidate(rfqsProvider),
        builder: (all) {
          bool match(Rfq r) => switch (_tab) {
            1 => r.status == 'DRAFT',
            2 => r.status == 'SENT' || r.status == 'QUOTATION_RECEIVED',
            3 => r.status == 'CONVERTED_TO_PO',
            _ => true,
          };
          final l = all.where(match).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilterChips(
                  labels: [
                    for (var i = 0; i < tabs.length; i++)
                      '${tabs[i]} (${all.where((r) => switch (i) {
                        1 => r.status == 'DRAFT',
                        2 => r.status == 'SENT' || r.status == 'QUOTATION_RECEIVED',
                        3 => r.status == 'CONVERTED_TO_PO',
                        _ => true,
                      }).length})',
                  ],
                  selected: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: l.isEmpty
                    ? const EmptyState(
                        icon: Icons.request_quote_outlined,
                        title: 'No RFQs',
                        message:
                            'Create an RFQ to get quotations from suppliers.',
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final r in l)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                onTap: () =>
                                    context.push('/rfq-detail', extra: r),
                                child: Row(
                                  children: [
                                    Avatar(initials(r.supplierName), size: 44),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.number,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            r.supplierName,
                                            style: TextStyle(color: C.muted),
                                          ),
                                          Text(
                                            'Delivery: ${dateShort(r.delivery)}',
                                            style: TextStyle(
                                              color: C.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusChip.forStatus(rfqLabel(r.status)),
                                    Icon(Icons.chevron_right, color: C.muted),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class QuotationScreen extends ConsumerStatefulWidget {
  const QuotationScreen({super.key, required this.rfq});
  final Rfq rfq;
  @override
  ConsumerState<QuotationScreen> createState() => _QuotationState();
}

class _QuotationState extends ConsumerState<QuotationScreen> {
  late Future<List<Quotation>> _f = ref
      .read(apiProvider)
      .quotationsForRfq(widget.rfq.id);

  Future<void> _act(Quotation q, String action) async {
    try {
      await ref.read(apiProvider).quotationAction(q.id, action, '');
      ref.invalidate(rfqsProvider);
      ref.invalidate(purchasesProvider);
      setState(
        () => _f = ref.read(apiProvider).quotationsForRfq(widget.rfq.id),
      );
      if (mounted)
        toast(
          context,
          action == 'ACCEPTED' ? 'Quotation accepted' : 'Quotation rejected',
        );
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rfq;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Quotation'),
        actions: [
          IconButton(
            tooltip: 'RFQ PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              try {
                final bytes = await ref.read(apiProvider).rfqPdf(widget.rfq.id);
                await Printing.sharePdf(
                  bytes: Uint8List.fromList(bytes),
                  filename: '${widget.rfq.number}.pdf',
                );
              } catch (e) {
                if (mounted) toast(context, '$e', error: true);
              }
            },
          ),
          if (widget.rfq.status == 'DRAFT' || widget.rfq.status == 'SENT')
            IconButton(
              tooltip: 'Cancel RFQ',
              icon: Icon(Icons.cancel_outlined, color: C.danger),
              onPressed: () async {
                if (!await confirm(
                  context,
                  'Cancel RFQ?',
                  'The supplier will no longer be able to quote on it.',
                  ok: 'Cancel RFQ',
                  danger: true,
                ))
                  return;
                try {
                  await ref.read(apiProvider).cancelRfq(widget.rfq.id);
                  ref.invalidate(rfqsProvider);
                  if (mounted) context.pop();
                } catch (e) {
                  if (mounted) toast(context, '$e', error: true);
                }
              },
            ),
        ],
      ),
      body: FutureBuilder<List<Quotation>>(
        future: _f,
        builder: (_, snap) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: C.successSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, color: C.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Linked to ${r.number}\nStatus: ${rfqLabel(r.status)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Requested items',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    for (final i in r.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(i.name)),
                            Text(
                              '${i.qty} Ã— ${money(i.expected)}',
                              style: TextStyle(color: C.muted),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!snap.hasData)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Center(
                    child: snap.hasError
                        ? Text('${snap.error}')
                        : const CircularProgressIndicator(),
                  ),
                )
              else if (snap.data!.isEmpty)
                const EmptyState(
                  icon: Icons.hourglass_empty,
                  title: 'No quotation yet',
                  message: 'The supplier has not replied to this RFQ.',
                )
              else
                for (final q in snap.data!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                q.number,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              const Spacer(),
                              StatusChip.forStatus(
                                q.status[0] +
                                    q.status
                                        .substring(1)
                                        .toLowerCase()
                                        .replaceAll('_', ' '),
                              ),
                            ],
                          ),
                          Text(
                            'From ${q.supplierName}',
                            style: TextStyle(color: C.muted),
                          ),
                          Text(
                            'Valid until ${dateShort(q.validUntil)}',
                            style: TextStyle(color: C.muted, fontSize: 12),
                          ),
                          const Divider(height: 22),
                          for (final i in q.items)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(js(i['productName'])),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${ji(i['quantity'])}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      money(jd(i['unitPrice'])),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      money(jd(i['totalAmount'])),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                money(q.finalAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () async {
                              try {
                                final bytes = await ref
                                    .read(apiProvider)
                                    .quotationPdf(q.id);
                                await Printing.sharePdf(
                                  bytes: Uint8List.fromList(bytes),
                                  filename: '${q.number}.pdf',
                                );
                              } catch (e) {
                                if (mounted) toast(context, '$e', error: true);
                              }
                            },
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Download / share PDF'),
                          ),
                          if (q.status == 'SENT' || q.status == 'PENDING') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _act(q, 'REJECTED'),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: C.danger,
                                      side: BorderSide(color: C.danger),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _act(q, 'ACCEPTED'),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Accept'),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• All quotations (across RFQs) â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
final _allQuotesProvider = FutureProvider.autoDispose<List<(Rfq, Quotation)>>((
  ref,
) async {
  final api = ref.watch(apiProvider);
  final rfqs = (await api.rfqs())
      .where(
        (r) =>
            r.status == 'QUOTATION_RECEIVED' ||
            r.status == 'CONVERTED_TO_PO' ||
            r.status == 'SENT',
      )
      .toList();
  final res = await Future.wait(
    rfqs.map(
      (r) => api
          .quotationsForRfq(r.id)
          .then((qs) => [for (final q in qs) (r, q)])
          .catchError((_) => <(Rfq, Quotation)>[]),
    ),
  );
  return res.expand((e) => e).toList();
});

class QuotationsListScreen extends ConsumerWidget {
  const QuotationsListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_allQuotesProvider);
    return Scaffold(
      appBar: blueAppBar(
        context,
        'Quotations',
        subtitle: 'Replies from your suppliers',
      ),
      body: AsyncBody<List<(Rfq, Quotation)>>(
        value: async,
        onRetry: () => ref.invalidate(_allQuotesProvider),
        builder: (l) => l.isEmpty
            ? const EmptyState(
                icon: Icons.request_quote_outlined,
                title: 'No quotations yet',
                message:
                    'Quotations appear here when suppliers reply to your RFQs.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.refresh(_allQuotesProvider.future),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final (r, q) in l)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          onTap: () => context.push('/quotation', extra: r),
                          child: Row(
                            children: [
                              Avatar(initials(q.supplierName), size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      q.number,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${q.supplierName} â€¢ ${r.number}',
                                      style: TextStyle(
                                        color: C.muted,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    Text(
                                      'Valid until ${dateShort(q.validUntil)}',
                                      style: TextStyle(
                                        color: C.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    money(q.finalAmount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  StatusChip.forStatus(
                                    q.status.isEmpty
                                        ? ''
                                        : q.status[0] +
                                              q.status
                                                  .substring(1)
                                                  .toLowerCase()
                                                  .replaceAll('_', ' '),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• RFQ detail (web: /rfqs/:id) â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class RfqDetailScreen extends ConsumerStatefulWidget {
  const RfqDetailScreen({super.key, required this.rfq});
  final Rfq rfq;
  @override
  ConsumerState<RfqDetailScreen> createState() => _RfqDetailState();
}

class _RfqDetailState extends ConsumerState<RfqDetailScreen> {
  late Future<Map<String, dynamic>> _f = ref
      .read(apiProvider)
      .rfqDetail(widget.rfq.id);

  Widget _kv(String a, String b) => b.isEmpty
      ? const SizedBox()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(a, style: TextStyle(color: C.muted)),
              ),
              Expanded(
                child: Text(
                  b,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );

  @override
  Widget build(BuildContext context) {
    final r = widget.rfq;
    return Scaffold(
      appBar: AppBar(
        title: Text(r.number),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              try {
                final bytes = await ref.read(apiProvider).rfqPdf(r.id);
                await Printing.sharePdf(
                  bytes: Uint8List.fromList(bytes),
                  filename: '${r.number}.pdf',
                );
              } catch (e) {
                if (mounted) toast(context, '$e', error: true);
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (_, snap) {
          if (!snap.hasData) {
            return snap.hasError
                ? EmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load',
                    message: '${snap.error}',
                    action: OutlinedButton(
                      onPressed: () => setState(
                        () => _f = ref.read(apiProvider).rfqDetail(r.id),
                      ),
                      child: const Text('Retry'),
                    ),
                  )
                : const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          final items = jlist(d['items'], (m) => m);
          final grand = items.fold(
            0.0,
            (a, i) =>
                a +
                jd(
                  i['totalAmount'] ??
                      i['total'] ??
                      (jd(i['quantity']) * jd(i['expectedPrice'])),
                ),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  StatusChip.forStatus(rfqLabel(js(d['status'], r.status))),
                  const Spacer(),
                  Text(
                    dateShort(jdt(d['createdAt'])),
                    style: TextStyle(color: C.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Supplier information',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _kv('Name', js(d['supplierName'], r.supplierName)),
                    _kv('Contact', js(d['supplierContact'])),
                    _kv(
                      'GSTIN / State',
                      [
                        js(d['supplierGstin']),
                        js(d['supplierStateCode']),
                      ].where((e) => e.isNotEmpty).join(' / '),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery & terms',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _kv('Delivery date', dateShort(jdt(d['deliveryDate']))),
                    _kv(
                      'Quotation validity',
                      d['validityDate'] == null
                          ? ''
                          : dateShort(jdt(d['validityDate'])),
                    ),
                    _kv('Payment terms', js(d['paymentTerms'])),
                    _kv('Shipping terms', js(d['shippingTerms'])),
                    _kv('Delivery location', js(d['deliveryLocation'])),
                    _kv('Delivery address', js(d['deliveryAddress'])),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: const [
                          Text(
                            'Requested items',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final i in items)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                js(
                                  i['productName'],
                                  js(i['requestedProductName']),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${ji(i['quantity'])}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                money(jd(i['expectedPrice'])),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                money(
                                  jd(
                                    i['totalAmount'] ??
                                        i['total'] ??
                                        (jd(i['quantity']) *
                                            jd(i['expectedPrice'])),
                                  ),
                                ),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grand Total',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            money(grand),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (js(d['notes']).isNotEmpty) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(js(d['notes'])),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/quotation', extra: r),
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text('View quotations'),
              ),
            ],
          );
        },
      ),
    );
  }
}
