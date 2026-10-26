import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../customers/customer_screens.dart' show callNumber, whatsapp;
import '../inventory/inventory_screens.dart'
    show suppliersProvider, purchasesProvider;
import '../invoices/invoice_screens.dart' show showProductPicker;

// ═════════════════════════ Suppliers ═════════════════════════
class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});
  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersState();
}

class _SuppliersState extends ConsumerState<SuppliersScreen> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(suppliersProvider);
    return Scaffold(
      appBar: blueAppBar(
        context,
        'Suppliers',
        subtitle: ref.watch(authProvider).session?.businessName,
        actions: [
          IconButton(
            tooltip: 'RFQs',
            onPressed: () => context.push('/rfqs'),
            icon: const Icon(Icons.request_quote_outlined),
          ),
        ],
      ),
      body: AsyncBody<List<Supplier>>(
        value: async,
        onRetry: () => ref.invalidate(suppliersProvider),
        builder: (all) {
          final l = all
              .where(
                (s) =>
                    s.name.toLowerCase().contains(_q) ||
                    s.phone.contains(_q) ||
                    s.address.toLowerCase().contains(_q),
              )
              .toList();
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(suppliersProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Manage your suppliers and purchases',
                  style: TextStyle(color: C.muted),
                ),
                const SizedBox(height: 10),
                StatTile(
                  label: 'Total Suppliers',
                  value: '${all.length}',
                  icon: Icons.groups_outlined,
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => context
                      .push('/supplier-form')
                      .then((_) => ref.invalidate(suppliersProvider)),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Supplier'),
                ),
                const SizedBox(height: 12),
                AppSearchField(
                  hint: 'Search suppliers by name, phone or city',
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                if (l.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: 'No suppliers yet',
                    ),
                  ),
                for (final s in l)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => context.push('/supplier/${s.id}', extra: s),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Avatar(initials(s.name), size: 48),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (s.address.isNotEmpty)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: C.muted,
                                          ),
                                          Flexible(
                                            child: Text(
                                              s.address,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: C.muted,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: C.muted),
                            ],
                          ),
                          if (s.phone.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () => callNumber(s.phone),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.call_outlined,
                                        size: 18,
                                        color: C.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        s.phone,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  onTap: () =>
                                      whatsapp(s.phone, 'Hello ${s.name},'),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.chat,
                                        size: 18,
                                        color: Color(0xFF25D366),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'WhatsApp',
                                        style: TextStyle(
                                          color: C.success,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
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
            ),
          );
        },
      ),
    );
  }
}

final supplierPurchasesProvider = FutureProvider.autoDispose
    .family<List<Purchase>, String>(
      (ref, id) async =>
          (await ref.watch(apiProvider).purchases(supplierId: id)).items,
    );

class SupplierDetailScreen extends ConsumerWidget {
  const SupplierDetailScreen({super.key, required this.supplier});
  final Supplier supplier;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = supplier;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Details'),
        actions: [
          IconButton(
            onPressed: () => context
                .push('/supplier-form', extra: s)
                .then((_) => ref.invalidate(suppliersProvider)),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Avatar(initials(s.name), size: 58),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (s.contact.isNotEmpty)
                              Text(s.contact, style: TextStyle(color: C.muted)),
                            if (s.address.isNotEmpty)
                              Text(
                                s.address,
                                style: TextStyle(
                                  color: C.muted,
                                  fontSize: 12.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: s.phone.isEmpty
                              ? null
                              : () => callNumber(s.phone),
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Call'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: s.phone.isEmpty
                              ? null
                              : () => whatsapp(s.phone, 'Hello ${s.name},'),
                          icon: const Icon(
                            Icons.chat,
                            color: Color(0xFF25D366),
                          ),
                          label: const Text('WhatsApp'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: C.success,
                            side: BorderSide(color: C.success),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              tabs: [
                Tab(child: Text('Purchases')),
                Tab(child: Text('Details')),
              ],
              labelColor: C.primary,
              indicatorColor: C.primary,
              unselectedLabelColor: C.muted,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ref
                      .watch(supplierPurchasesProvider(s.id))
                      .when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => EmptyState(
                          icon: Icons.error_outline,
                          title: 'Could not load',
                          message: '$e',
                        ),
                        data: (l) => l.isEmpty
                            ? const EmptyState(
                                icon: Icons.local_shipping_outlined,
                                title: 'No purchases yet',
                              )
                            : ListView(
                                padding: const EdgeInsets.all(12),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Purchase History',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const Spacer(),
                                        StatusChip(
                                          '${l.length} Purchases',
                                          color: C.muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                  for (final p in l)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: AppCard(
                                        child: Row(
                                          children: [
                                            Column(
                                              children: [
                                                Text(
                                                  dateShort(p.date)
                                                      .substring(0, 6),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                                Text(
                                                  '${p.date?.year ?? ''}',
                                                  style: TextStyle(
                                                    color: C.muted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    p.items.isEmpty
                                                        ? '#${p.number}'
                                                        : p.items
                                                              .map(
                                                                (i) => i.name,
                                                              )
                                                              .join(', '),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${p.items.length} items',
                                                    style: TextStyle(
                                                      color: C.muted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              money(p.total),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AppCard(
                        child: Column(
                          children: [
                            _kv('Name', s.name),
                            _kv(
                              'Contact person',
                              s.contact.isEmpty ? '—' : s.contact,
                            ),
                            _kv('Phone', s.phone.isEmpty ? '—' : s.phone),
                            _kv('Email', s.email.isEmpty ? '—' : s.email),
                            _kv('Address', s.address.isEmpty ? '—' : s.address),
                            _kv('GSTIN', s.gstin.isEmpty ? '—' : s.gstin),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => context
                      .push('/purchase-form')
                      .then(
                        (_) => ref.invalidate(supplierPurchasesProvider(s.id)),
                      ),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('New Purchase'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(a, style: TextStyle(color: C.muted)),
        ),
        Expanded(
          child: Text(b, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

class SupplierFormScreen extends ConsumerStatefulWidget {
  const SupplierFormScreen({super.key, this.supplier});
  final Supplier? supplier;
  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormState();
}

class _SupplierFormState extends ConsumerState<SupplierFormScreen> {
  late final _name = TextEditingController(text: widget.supplier?.name);
  late final _contact = TextEditingController(text: widget.supplier?.contact);
  late final _phone = TextEditingController(text: widget.supplier?.phone);
  late final _email = TextEditingController(text: widget.supplier?.email);
  late final _addr = TextEditingController(text: widget.supplier?.address);
  late final _gst = TextEditingController(text: widget.supplier?.gstin);
  bool _busy = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty)
      return toast(context, 'Enter supplier name', error: true);
    setState(() => _busy = true);
    try {
      String? n(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();
      await ref.read(apiProvider).saveSupplier({
        'name': _name.text.trim(),
        'contactPerson': n(_contact),
        'phone': n(_phone),
        'email': n(_email),
        'address': n(_addr),
        'gstin': n(_gst)?.toUpperCase(),
        'active': true,
      }, id: widget.supplier?.id);
      ref.invalidate(suppliersProvider);
      if (mounted) {
        toast(context, 'Supplier saved');
        context.pop();
      }
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.supplier == null ? 'Add supplier' : 'Edit supplier'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LabeledField(label: 'Supplier name', controller: _name, required: true),
        LabeledField(label: 'Contact person', controller: _contact),
        LabeledField(
          label: 'Phone',
          controller: _phone,
          keyboard: TextInputType.phone,
        ),
        LabeledField(
          label: 'Email',
          controller: _email,
          keyboard: TextInputType.emailAddress,
        ),
        LabeledField(label: 'Address', controller: _addr, maxLines: 2),
        LabeledField(label: 'GSTIN (optional)', controller: _gst),
        PrimaryButton('Save supplier', loading: _busy, onPressed: _save),
      ],
    ),
  );
}

// ═════════════════════════ RFQ ═════════════════════════
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
    final sup = ref.read(suppliersProvider).valueOrNull ?? [];
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
                DropdownButtonFormField<String>(
                  value: supplierId,
                  hint: const Text('Select supplier'),
                  items: [
                    for (final s in sup)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => set(() => supplierId = v),
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
                              labelText: tr('₹ each'),
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
                              '${i.qty} × ${money(i.expected)}',
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

// ═════════════════════════ All quotations (across RFQs) ═════════════════════════
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
                                      '${q.supplierName} • ${r.number}',
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

// ═════════════════════════ RFQ detail (web: /rfqs/:id) ═════════════════════════
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
