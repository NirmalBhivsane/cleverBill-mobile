import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';

Future<void> callNumber(String n) => launchUrl(Uri.parse('tel:$n'));
Future<void> whatsapp(String mobile, String text) {
  final d = mobile.replaceAll(RegExp(r'\D'), '');
  final n = d.length == 10 ? '91$d' : d;
  return launchUrl(
    Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(text)}'),
    mode: LaunchMode.externalApplication,
  );
}

String _shop(WidgetRef ref) =>
    ref.read(authProvider).session?.businessName ?? '';

// ═════════════════════════ Customers ═════════════════════════
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersState();
}

class _CustomersState extends ConsumerState<CustomersScreen> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(customersProvider);
    return Scaffold(
      appBar: blueAppBar(
        context,
        'Customers',
        subtitle: ref.watch(authProvider).session?.businessName,
      ),
      body: AsyncBody<List<Customer>>(
        value: async,
        onRetry: () => ref.invalidate(customersProvider),
        builder: (all) {
          final people = all.where((c) => c.mobile != '9999999999').toList();
          final l = people
              .where(
                (c) =>
                    c.name.toLowerCase().contains(_q) || c.mobile.contains(_q),
              )
              .toList();
          final due = people.fold(0.0, (a, c) => a + c.outstanding);
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(customersProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Total Customers',
                        value: '${people.length}',
                        icon: Icons.groups_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: 'Total Due',
                        value: money(due),
                        color: C.warning,
                        icon: Icons.currency_rupee,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => context
                      .push('/customer-form')
                      .then((_) => ref.invalidate(customersProvider)),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add Customer'),
                ),
                const SizedBox(height: 12),
                AppSearchField(
                  hint: 'Search customers by name or phone',
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                if (l.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No customers found',
                    ),
                  ),
                for (final c in l)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => context.push('/customer/${c.id}'),
                      child: Row(
                        children: [
                          Avatar(
                            initials(c.name),
                            color:
                                Colors.primaries[c.name.length %
                                    Colors.primaries.length],
                          ),
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
                                  '+91 ${c.mobile}',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Due',
                                style: TextStyle(color: C.muted, fontSize: 11),
                              ),
                              Text(
                                money(c.outstanding),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: c.outstanding > 0 ? C.danger : C.text,
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
            ),
          );
        },
      ),
    );
  }
}

final customerLedgerProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, id) => ref.watch(apiProvider).customerLedger(id),
    );
final customerInvoicesProvider = FutureProvider.autoDispose
    .family<List<Invoice>, String>(
      (ref, id) async =>
          (await ref.watch(apiProvider).invoicesByCustomer(id)).items,
    );

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(customerLedgerProvider(id));
    final cust = ref
        .watch(customersProvider)
        .valueOrNull
        ?.where((c) => c.id == id)
        .firstOrNull;
    return Scaffold(
      appBar: blueAppBar(
        context,
        cust?.name ?? 'Customer',
        subtitle:
            'Customer • ${ref.watch(authProvider).session?.businessName ?? ''}',
        actions: [
          if (cust != null)
            IconButton(
              onPressed: () =>
                  context.push('/customer-form', extra: cust).then((_) {
                    ref.invalidate(customersProvider);
                    ref.invalidate(customerLedgerProvider(id));
                  }),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: AsyncBody<Map<String, dynamic>>(
        value: ledger,
        onRetry: () => ref.invalidate(customerLedgerProvider(id)),
        builder: (d) {
          final info = jm(d['customer']);
          final sum = jm(d['summary']);
          final tx = jlist(d['transactions'], LedgerEntry.new);
          final name = js(info['name'], cust?.name ?? '');
          final phone = js(info['phone'], cust?.mobile ?? '');
          final outstanding = jd(
            sum['outstanding'] ?? info['outstanding'] ?? cust?.outstanding,
          );
          final limit = jd(
            sum['creditLimit'] ?? info['creditLimit'] ?? cust?.creditLimit,
          );
          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Avatar(initials(name), size: 60),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '+91 $phone',
                                  style: TextStyle(color: C.muted),
                                ),
                                if ((cust?.address ?? '').isNotEmpty)
                                  Text(
                                    cust!.address,
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: C.success,
                            ),
                            onPressed: () => callNumber(phone),
                            icon: const Icon(Icons.call, color: Colors.white),
                          ),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                            ),
                            onPressed: () => whatsapp(phone, 'Hello $name,'),
                            icon: const Icon(Icons.chat, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: StatTile(
                              label: 'Balance Due',
                              value: money(outstanding),
                              color: C.warning,
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatTile(
                              label: 'Credit Limit',
                              value: limit > 0 ? money(limit) : 'Not set',
                              icon: Icons.credit_card,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  tabs: [
                    Tab(child: Text('Ledger')),
                    Tab(child: Text('Bills')),
                    Tab(child: Text('Details')),
                  ],
                  labelColor: C.primary,
                  indicatorColor: C.primary,
                  unselectedLabelColor: C.muted,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      tx.isEmpty
                          ? const EmptyState(
                              icon: Icons.menu_book_outlined,
                              title: 'No transactions yet',
                            )
                          : ListView(
                              padding: const EdgeInsets.all(12),
                              children: [
                                for (final t in tx.reversed)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: t.credit > 0
                                          ? C.successSoft.withOpacity(.6)
                                          : C.dangerSoft.withOpacity(.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: C.card,
                                          child: Icon(
                                            t.type == 'PAYMENT'
                                                ? Icons.currency_rupee
                                                : t.type == 'RETURN'
                                                ? Icons.undo
                                                : Icons.description_outlined,
                                            color: t.credit > 0
                                                ? C.success
                                                : C.danger,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                dateShort(t.date),
                                                style: TextStyle(
                                                  color: C.muted,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                              Text(
                                                t.type == 'PAYMENT'
                                                    ? 'Payment received'
                                                    : '${t.type == 'RETURN' ? 'Return' : 'Invoice'} #${t.ref}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              if (t.desc.isNotEmpty)
                                                Text(
                                                  t.desc,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: C.muted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              t.credit > 0 ? 'Credit' : 'Debit',
                                              style: TextStyle(
                                                color: C.muted,
                                                fontSize: 11,
                                              ),
                                            ),
                                            Text(
                                              money(
                                                t.credit > 0
                                                    ? t.credit
                                                    : t.debit,
                                              ),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: t.credit > 0
                                                    ? C.success
                                                    : C.danger,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                      _CustomerBills(id: id),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          AppCard(
                            child: Column(
                              children: [
                                _kv('Name', name),
                                _kv('Mobile', phone),
                                _kv(
                                  'Email',
                                  js(info['email'], cust?.email ?? '—'),
                                ),
                                _kv(
                                  'Address',
                                  cust?.address.isEmpty ?? true
                                      ? '—'
                                      : cust!.address,
                                ),
                                _kv(
                                  'GSTIN',
                                  cust?.gstin.isEmpty ?? true
                                      ? '—'
                                      : cust!.gstin,
                                ),
                                _kv(
                                  'Total invoices',
                                  '${ji(sum['totalInvoices'])}',
                                ),
                                _kv(
                                  'Total purchase',
                                  money(jd(sum['totalPurchaseAmount'])),
                                ),
                                _kv('Total paid', money(jd(sum['totalPaid']))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (outstanding > 0)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.currency_rupee),
                        label: const Text('Receive payment'),
                        onPressed: () async {
                          final inv = (await ref.read(
                            customerInvoicesProvider(id).future,
                          )).where((i) => i.due > 0 && !i.cancelled).toList();
                          if (!context.mounted) return;
                          if (inv.isEmpty)
                            return toast(
                              context,
                              'No unpaid invoices for this customer',
                            );
                          Invoice? pick = inv.first;
                          if (inv.length > 1) {
                            pick = await showModalBottomSheet<Invoice>(
                              context: context,
                              builder: (ctx) => ListView(
                                shrinkWrap: true,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'Select invoice',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  for (final i in inv)
                                    ListTile(
                                      title: Text('#${i.number}'),
                                      subtitle: Text(dateShort(i.createdAt)),
                                      trailing: Text(
                                        'Due ${money(i.due)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: C.danger,
                                        ),
                                      ),
                                      onTap: () => Navigator.pop(ctx, i),
                                    ),
                                ],
                              ),
                            );
                          }
                          if (pick != null && context.mounted) {
                            await context.push('/receive-payment', extra: pick);
                            ref.invalidate(customerLedgerProvider(id));
                            ref.invalidate(customersProvider);
                          }
                        },
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

  Widget _kv(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
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

class _CustomerBills extends ConsumerWidget {
  const _CustomerBills({required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(customerInvoicesProvider(id))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
          message: '$e',
        ),
        data: (l) => l.isEmpty
            ? const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No bills yet',
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final i in l)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        onTap: () => context.push('/invoice/${i.id}'),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    i.number,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    dateTime12(i.createdAt),
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusChip.forStatus(i.uiStatus),
                            const SizedBox(width: 10),
                            Text(
                              money(i.total),
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
      );
}

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customer});
  final Customer? customer;
  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormState();
}

class _CustomerFormState extends ConsumerState<CustomerFormScreen> {
  late final _name = TextEditingController(text: widget.customer?.name);
  late final _mobile = TextEditingController(text: widget.customer?.mobile);
  late final _email = TextEditingController(text: widget.customer?.email);
  late final _addr = TextEditingController(text: widget.customer?.address);
  late final _gstin = TextEditingController(text: widget.customer?.gstin);
  late final _limit = TextEditingController(
    text: (widget.customer?.creditLimit ?? 0) > 0
        ? '${widget.customer!.creditLimit}'
        : '',
  );
  bool _busy = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty)
      return toast(context, 'Enter customer name', error: true);
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_mobile.text.trim()))
      return toast(
        context,
        'Enter a valid 10-digit mobile number',
        error: true,
      );
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).saveCustomer({
        'name': _name.text.trim(),
        'mobileNumber': _mobile.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'address': _addr.text.trim().isEmpty ? null : _addr.text.trim(),
        'gstin': _gstin.text.trim().isEmpty
            ? null
            : _gstin.text.trim().toUpperCase(),
        if (_limit.text.isNotEmpty)
          'creditLimit': double.tryParse(_limit.text) ?? 0,
      }, id: widget.customer?.id);
      ref.invalidate(customersProvider);
      if (mounted) {
        toast(context, 'Customer saved');
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
      title: Text(widget.customer == null ? 'Add customer' : 'Edit customer'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LabeledField(label: 'Name', controller: _name, required: true),
        LabeledField(
          label: 'Mobile number',
          controller: _mobile,
          keyboard: TextInputType.phone,
          required: true,
          maxLength: 10,
        ),
        LabeledField(
          label: 'Email',
          controller: _email,
          keyboard: TextInputType.emailAddress,
        ),
        LabeledField(label: 'Address', controller: _addr, maxLines: 2),
        if (ref.watch(authProvider).isGst)
          LabeledField(label: 'GSTIN', controller: _gstin),
        LabeledField(
          label: 'Credit limit (₹)',
          controller: _limit,
          keyboard: TextInputType.number,
          hint: 'Optional',
        ),
        PrimaryButton('Save customer', loading: _busy, onPressed: _save),
      ],
    ),
  );
}

// ═════════════════════════ Receive payment ═════════════════════════
class ReceivePaymentScreen extends ConsumerStatefulWidget {
  const ReceivePaymentScreen({super.key, required this.invoice});
  final Invoice invoice;
  @override
  ConsumerState<ReceivePaymentScreen> createState() => _ReceiveState();
}

class _ReceiveState extends ConsumerState<ReceivePaymentScreen> {
  late final _amount = TextEditingController(
    text: widget.invoice.due.toStringAsFixed(
      widget.invoice.due % 1 == 0 ? 0 : 2,
    ),
  );
  final _ref = TextEditingController();
  String _mode = 'CASH';
  bool _busy = false;

  Future<void> _save() async {
    final a = double.tryParse(_amount.text) ?? 0;
    if (a <= 0) return toast(context, 'Enter an amount', error: true);
    if (a > widget.invoice.due + 0.001)
      return toast(context, 'Amount exceeds the balance due', error: true);
    setState(() => _busy = true);
    try {
      await ref
          .read(apiProvider)
          .recordPayment(widget.invoice.id, a, _mode, _ref.text.trim());
      ref.invalidate(customersProvider);
      ref.invalidate(duesProvider);
      if (mounted) {
        toast(context, 'Payment recorded');
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
    final a = double.tryParse(_amount.text) ?? 0;
    return Scaffold(
      appBar: blueAppBar(context, 'Receive payment'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Avatar(initials(inv.customerName), size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
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
                            inv.customer?.mobile ?? '',
                            style: TextStyle(color: C.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 22),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: C.dangerSoft,
                      child: Icon(Icons.description_outlined, color: C.danger),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice #${inv.number}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            dateShort(inv.createdAt),
                            style: TextStyle(color: C.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Amount due',
                          style: TextStyle(color: C.muted, fontSize: 11),
                        ),
                        Text(
                          money(inv.due),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: C.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('Amount *', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(prefixText: '₹  '),
          ),
          const SizedBox(height: 14),
          const Text(
            'Payment method *',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _mode,
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
              DropdownMenuItem(value: 'UPI', child: Text('UPI')),
              DropdownMenuItem(value: 'CARD', child: Text('Card')),
            ],
            onChanged: (v) => setState(() => _mode = v ?? 'CASH'),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Reference (optional)',
            controller: _ref,
            hint: 'e.g. UPI ID / Transaction ID',
          ),
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
                    'This only records the payment in Clever Bill. It does not initiate any bank transfer or UPI payment.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.successSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Remaining due after this payment',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  money((inv.due - a).clamp(0, double.infinity)),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: C.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton('Record payment', loading: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

// ═════════════════════════ Payments & dues ═════════════════════════
final duesProvider = FutureProvider.autoDispose<List<Invoice>>((ref) async {
  ref.watch(selectedBranchProvider);
  final l = (await ref.watch(apiProvider).invoices(size: 300)).items;
  return l.where((i) => !i.cancelled && i.due > 0.001).toList();
});

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsState();
}

class _PaymentsState extends ConsumerState<PaymentsScreen> {
  int _tab = 0;
  bool _overdue(Invoice i) =>
      i.dueDate != null &&
      i.dueDate!.isBefore(DateTime.now().subtract(const Duration(days: 0)));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(duesProvider);
    return Scaffold(
      appBar: blueAppBar(
        context,
        'Payments & Dues',
        subtitle: ref.watch(authProvider).session?.businessName,
      ),
      body: AsyncBody<List<Invoice>>(
        value: async,
        onRetry: () => ref.invalidate(duesProvider),
        builder: (all) {
          final total = all.fold(0.0, (a, i) => a + i.due);
          final over = all.where(_overdue).toList();
          final overAmt = over.fold(0.0, (a, i) => a + i.due);
          var l = switch (_tab) {
            1 => all.where((i) => i.paid > 0).toList(),
            2 => all.where((i) => i.paid == 0).toList(),
            3 => over,
            _ => all,
          };
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(duesProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Total Due',
                        value: money(total),
                        color: C.warning,
                        icon: Icons.currency_rupee,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: 'Overdue',
                        value: money(overAmt),
                        color: C.danger,
                        icon: Icons.schedule,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilterChips(
                  labels: const ['All', 'Partial', 'Unpaid', 'Overdue'],
                  selected: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 12),
                if (l.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 50),
                    child: EmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'No pending dues',
                      message: 'All caught up!',
                    ),
                  ),
                for (final i in l)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#${i.number}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                dateShort(i.createdAt),
                                style: TextStyle(color: C.muted, fontSize: 12),
                              ),
                              const Spacer(),
                              if (_overdue(i))
                                StatusChip(
                                  'Overdue ${DateTime.now().difference(i.dueDate!).inDays} days',
                                  color: C.danger,
                                )
                              else if (i.dueDate != null)
                                StatusChip(
                                  'Due ${dateShort(i.dueDate).substring(0, 6)}',
                                  color: C.success,
                                ),
                            ],
                          ),
                          Text(
                            i.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _col('Bill Amount', money(i.total)),
                              _col('Paid', money(i.paid)),
                              _col('Due', money(i.due), color: C.danger),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 42),
                                  ),
                                  onPressed: () => context
                                      .push('/receive-payment', extra: i)
                                      .then((_) {
                                        ref.invalidate(duesProvider);
                                        ref.invalidate(customersProvider);
                                      }),
                                  icon: const Icon(
                                    Icons.currency_rupee,
                                    size: 18,
                                  ),
                                  label: const Text('Receive'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 42),
                                  ),
                                  onPressed: () async {
                                    String msg;
                                    try {
                                      msg = await ref
                                          .read(apiProvider)
                                          .paymentReminder(i.id);
                                    } catch (_) {
                                      msg =
                                          'Hello ${i.customerName}, a payment of ${money(i.due)} for invoice ${i.number} is pending at ${_shop(ref)}. Please pay at the earliest. Thank you!';
                                    }
                                    await whatsapp(
                                      i.customer?.mobile ?? '',
                                      msg,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.send_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Remind'),
                                ),
                              ),
                            ],
                          ),
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

  Widget _col(String a, String b, {Color? color}) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(a, style: TextStyle(color: C.muted, fontSize: 11.5)),
        Text(
          b,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: color,
          ),
        ),
      ],
    ),
  );
}
