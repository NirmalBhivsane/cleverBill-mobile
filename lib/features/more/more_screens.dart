import 'dart:io';

import 'package:flutter/material.dart' hide Text;

import 'language_sheet.dart';
import '../security/app_lock.dart';
import '../../core/i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../home/home_screen.dart';

// ═════════════════════════ More ═════════════════════════
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final s = auth.session;
    final isOwner = s?.isOwner ?? false;
    Widget tile(IconData i, String t, String sub, String route) => ListTile(
      leading: Icon(i, color: C.primary),
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(sub, style: TextStyle(color: C.muted, fontSize: 12.5)),
      trailing: Icon(Icons.chevron_right, color: C.muted),
      onTap: () => context.push(route),
    );
    Widget group(String title, List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1) const Divider(height: 1, indent: 56),
              ],
            ],
          ),
        ),
      ],
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
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
                const NotificationBell(),
              ],
            ),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: C.primarySoft,
                        child: Icon(
                          Icons.storefront_rounded,
                          color: C.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s?.businessName ?? 'My Shop',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${s?.branchName ?? 'Main Branch'} • ${s?.name ?? ''}',
                              style: TextStyle(color: C.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/settings/business'),
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: C.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Mini(
                          Icons.description_outlined,
                          auth.isGst ? 'GST billing' : 'Simple billing',
                        ),
                        const _Mini(Icons.currency_rupee, 'INR'),
                        const _Mini(
                          Icons.inventory_2_outlined,
                          'Stock tracking on',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            group('Business', [
              tile(
                Icons.groups_outlined,
                'Customers',
                'Manage your customers',
                '/customers',
              ),
              tile(
                Icons.currency_rupee,
                'Payments & dues',
                'Receive payments and send reminders',
                '/payments',
              ),
              if (isOwner)
                tile(
                  Icons.local_shipping_outlined,
                  'Suppliers',
                  'Manage your suppliers',
                  '/suppliers',
                ),
              if (isOwner)
                tile(
                  Icons.shopping_cart_outlined,
                  'Purchases',
                  'Record and view your purchases',
                  '/purchases',
                ),
              if (isOwner)
                tile(
                  Icons.request_quote_outlined,
                  'RFQs & quotations',
                  'Create quotes from suppliers',
                  '/rfqs',
                ),
              if (isOwner)
                tile(
                  Icons.mark_email_read_outlined,
                  'Quotations',
                  'Replies from your suppliers',
                  '/quotations',
                ),
              tile(
                Icons.event_busy_outlined,
                'Expiry tracking',
                'Products expiring or expired',
                '/expiry',
              ),
              tile(
                Icons.undo_rounded,
                'Returns',
                'Manage sales and purchase returns',
                '/returns',
              ),
              tile(
                Icons.receipt_outlined,
                'Expenses',
                'Track your business expenses',
                '/expenses',
              ),
            ]),
            if (isOwner)
              group('Reports', [
                if (isOwner)
                  tile(
                    Icons.bar_chart_rounded,
                    'Reports',
                    'Sales, purchases and more',
                    '/reports',
                  ),
                if (isOwner)
                  tile(
                    Icons.insights_rounded,
                    'Insights',
                    'Product, customer, invoice and expense analytics',
                    '/analytics',
                  ),
              ]),
            group('Account', [
              tile(
                Icons.person_outline,
                'My profile',
                'Name, phone and photo',
                '/profile',
              ),
            ]),
            group('Settings & support', [
              if (s?.isOwner ?? false)
                if (isOwner)
                  tile(
                    Icons.store_mall_directory_outlined,
                    'Branches & staff',
                    'Manage branches and team members',
                    '/branches',
                  ),
              tile(
                Icons.settings_outlined,
                'Settings',
                'App preferences and billing setup',
                '/settings',
              ),
              tile(
                Icons.help_outline,
                'Help & support',
                'Get help, contact us',
                '/help',
              ),
            ]),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                if (await confirm(
                  context,
                  'Sign out?',
                  'You will need to sign in again.',
                  ok: 'Sign out',
                  danger: true,
                ))
                  ref.read(authProvider.notifier).signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.danger,
                side: BorderSide(color: C.danger),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Clever Bill v1.0.0  |  Made for Indian businesses 🇮🇳',
                style: TextStyle(color: C.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.i, this.t);
  final IconData i;
  final String t;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(i, size: 16, color: C.primary),
      const SizedBox(width: 4),
      Text(
        t,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

// ═════════════════════════ Expenses ═════════════════════════
final expensesProvider = FutureProvider.autoDispose<List<Expense>>((ref) async {
  ref.watch(selectedBranchProvider);
  final n = DateTime.now();
  return (await ref
          .watch(apiProvider)
          .expenses(
            from: DateTime(n.year, n.month, 1),
            to: DateTime(n.year, n.month + 1, 0),
          ))
      .items;
});

Map<String, (String, IconData, Color)> get _expCats => {
  'RENT': ('Rent', Icons.home_outlined, Color(0xFF8B5CF6)),
  'SALARY': ('Salary', Icons.badge_outlined, C.primary),
  'UTILITY': ('Utilities', Icons.bolt, C.warning),
  'PURCHASE': ('Purchase', Icons.shopping_bag_outlined, C.success),
  'MAINTENANCE': ('Maintenance', Icons.build_outlined, Color(0xFF0EA5E9)),
  'MARKETING': ('Marketing', Icons.campaign_outlined, Color(0xFFEC4899)),
  'OTHER': ('Others', Icons.more_horiz, C.muted),
};

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});
  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesState();
}

class _ExpensesState extends ConsumerState<ExpensesScreen> {
  String _cat = 'ALL';

  Future<void> _add([Expense? e]) async {
    final amount = TextEditingController(text: e == null ? '' : '${e.amount}');
    final title = TextEditingController(text: e?.title);
    final note = TextEditingController(text: e?.note);
    var cat = _expCats.containsKey((e?.category ?? '').toUpperCase())
        ? e!.category.toUpperCase()
        : 'OTHER';
    var date = e?.date ?? DateTime.now();
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
                Text(
                  e == null ? 'Add expense' : 'Edit expense',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: 'Amount',
                        controller: amount,
                        keyboard: TextInputType.number,
                        required: true,
                        prefix: const Icon(Icons.currency_rupee, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category *',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: cat,
                            isExpanded: true,
                            items: [
                              for (final c in _expCats.entries)
                                DropdownMenuItem(
                                  value: c.key,
                                  child: Text(c.value.$1),
                                ),
                            ],
                            onChanged: (v) => set(() => cat = v ?? 'OTHER'),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ],
                ),
                LabeledField(
                  label: 'Title',
                  controller: title,
                  hint: 'e.g. Electricity bill',
                ),
                LabeledField(label: 'Note (optional)', controller: note),
                InkWell(
                  onTap: () async {
                    final d = await pickDate(ctx, initial: date);
                    if (d != null) set(() => date = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: tr('Date'),
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(dateShort(date)),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  'Save expense',
                  onPressed: () async {
                    final a = double.tryParse(amount.text);
                    if (a == null || a <= 0)
                      return toast(ctx, 'Enter a valid amount', error: true);
                    try {
                      await ref.read(apiProvider).saveExpense({
                        'title': title.text.trim().isEmpty
                            ? (_expCats[cat]!.$1)
                            : title.text.trim(),
                        'category': cat,
                        'amount': a,
                        'date': iso(date),
                        'note': note.text.trim(),
                      }, id: e?.id);
                      ref.invalidate(expensesProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (err) {
                      if (ctx.mounted) toast(ctx, '$err', error: true);
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
    final async = ref.watch(expensesProvider);
    return Scaffold(
      appBar: blueAppBar(
        context,
        'Expenses',
        subtitle: ref.watch(authProvider).session?.businessName,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
        backgroundColor: C.primary,
        foregroundColor: Colors.white,
      ),
      body: AsyncBody<List<Expense>>(
        value: async,
        onRetry: () => ref.invalidate(expensesProvider),
        builder: (all) {
          final total = all.fold(0.0, (a, e) => a + e.amount);
          final l = _cat == 'ALL'
              ? all
              : all.where((e) => e.category == _cat).toList();
          final keys = ['ALL', ..._expCats.keys];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expenses this month',
                            style: TextStyle(color: C.muted),
                          ),
                          Text(
                            money(total),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      backgroundColor: C.primarySoft,
                      child: Icon(
                        Icons.receipt_long_outlined,
                        color: C.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilterChips(
                labels: [
                  for (final k in keys) k == 'ALL' ? 'All' : _expCats[k]!.$1,
                ],
                selected: keys.indexOf(_cat),
                onSelect: (i) => setState(() => _cat = keys[i]),
              ),
              const SizedBox(height: 12),
              if (l.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.receipt_outlined,
                    title: 'No expenses',
                    message: 'Tap “Add expense” to record one.',
                  ),
                ),
              for (final e in l)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    onTap: () => _add(e),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: (_expCats[e.category]?.$3 ?? C.muted)
                              .withOpacity(.14),
                          child: Icon(
                            _expCats[e.category]?.$2 ?? Icons.receipt,
                            color: _expCats[e.category]?.$3 ?? C.muted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                dateShort(e.date),
                                style: TextStyle(color: C.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (e.approval == 'PENDING' ||
                            e.approval == 'REJECTED') ...[
                          StatusChip(
                            e.approval == 'PENDING' ? 'Pending' : 'Rejected',
                            color: e.approval == 'PENDING'
                                ? C.warning
                                : C.danger,
                          ),
                          const SizedBox(width: 6),
                        ],
                        StatusChip(
                          _expCats[e.category]?.$1 ?? e.category,
                          color: _expCats[e.category]?.$3 ?? C.muted,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          money(e.amount),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) async {
                            try {
                              if (v == 'approve') {
                                await ref
                                    .read(apiProvider)
                                    .approveExpense(e.id);
                                ref.invalidate(expensesProvider);
                              } else if (v == 'reject') {
                                await ref.read(apiProvider).rejectExpense(e.id);
                                ref.invalidate(expensesProvider);
                              } else if (v == 'del' &&
                                  await confirm(
                                    context,
                                    'Delete expense?',
                                    'This cannot be undone.',
                                    ok: 'Delete',
                                    danger: true,
                                  )) {
                                await ref.read(apiProvider).deleteExpense(e.id);
                                ref.invalidate(expensesProvider);
                              }
                            } catch (err) {
                              if (context.mounted)
                                toast(context, '$err', error: true);
                            }
                          },
                          itemBuilder: (_) => [
                            if (e.approval == 'PENDING' &&
                                (ref.read(authProvider).session?.isOwner ??
                                    false)) ...[
                              const PopupMenuItem(
                                value: 'approve',
                                child: Text('Approve'),
                              ),
                              const PopupMenuItem(
                                value: 'reject',
                                child: Text('Reject'),
                              ),
                            ],
                            PopupMenuItem(
                              value: 'del',
                              child: Text(
                                'Delete',
                                style: TextStyle(color: C.danger),
                              ),
                            ),
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
}

// ═════════════════════════ Settings hub ═════════════════════════
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isOwner = auth.session?.isOwner ?? false;
    Widget tile(
      IconData i,
      String t,
      String sub, {
      String? route,
      VoidCallback? onTap,
      String? trailing,
    }) => ListTile(
      leading: Icon(i, color: C.primary),
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(sub, style: TextStyle(color: C.muted, fontSize: 12.5)),
      trailing: trailing != null
          ? Text(trailing, style: TextStyle(color: C.muted))
          : Icon(Icons.chevron_right, color: C.muted),
      onTap: onTap ?? () => context.push(route!),
    );
    return Scaffold(
      appBar: blueAppBar(context, 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: C.primarySoft,
                  child: Icon(Icons.storefront_rounded, color: C.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.session?.businessName ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        auth.isGst
                            ? 'Billing with GST'
                            : 'Billing without GST (for small businesses)',
                        style: TextStyle(color: C.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  auth.isGst ? 'GST mode' : 'Simple mode',
                  color: C.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (isOwner)
                  tile(
                    Icons.settings_outlined,
                    'Business & tax setup',
                    'Business details, GST or Simple mode',
                    route: '/settings/business',
                  ),
                if (isOwner) const Divider(height: 1, indent: 56),
                if (isOwner)
                  tile(
                    Icons.description_outlined,
                    'Invoice & receipt design',
                    'Logo, receipt layout, terms',
                    route: '/settings/invoice',
                  ),
                if (isOwner) const Divider(height: 1, indent: 56),
                tile(
                  Icons.palette_outlined,
                  'Appearance',
                  'Dark mode, brand colour, font size',
                  route: '/settings/appearance',
                ),
                const Divider(height: 1, indent: 56),
                if (isOwner)
                  tile(
                    Icons.receipt_long_outlined,
                    'GST & tax',
                    'GSTIN, PAN, default tax rate',
                    route: '/settings/gst',
                  ),
                if (isOwner) const Divider(height: 1, indent: 56),
                if (isOwner)
                  tile(
                    Icons.tune,
                    'Business defaults',
                    'Credit limit, alerts, backup',
                    route: '/settings/defaults',
                  ),
                if (isOwner) const Divider(height: 1, indent: 56),
                tile(
                  Icons.print_outlined,
                  'Printer & barcode',
                  'Thermal printer layout, scanner',
                  route: '/settings/hardware',
                ),
                const Divider(height: 1, indent: 56),
                tile(
                  Icons.bluetooth,
                  'Bluetooth printer',
                  'Pair a thermal receipt printer',
                  route: '/settings/printer',
                ),
                const Divider(height: 1, indent: 56),
                tile(
                  Icons.qr_code_scanner_rounded,
                  'Phone scanner for web POS',
                  'Use this phone as a barcode scanner for desktop billing',
                  route: '/scan-to-web',
                ),
                const Divider(height: 1, indent: 56),
                if (isOwner)
                  tile(
                    Icons.business_outlined,
                    'Branches',
                    'Manage your shop branches',
                    route: '/branches',
                  ),
                if (isOwner) const Divider(height: 1, indent: 56),
                if (isOwner)
                  tile(
                    Icons.account_balance_outlined,
                    'Bank & UPI',
                    'UPI, bank accounts, payment settings',
                    route: '/settings/bank',
                  ),
                if (isOwner) const Divider(height: 1, indent: 56),
                if (isOwner)
                  tile(
                    Icons.cloud_upload_outlined,
                    'Backup & export',
                    'Backup data, export reports',
                    route: '/settings/backup',
                  ),
                if (isOwner) const Divider(height: 1, indent: 56),
                tile(
                  Icons.language,
                  'Language',
                  'App language',
                  trailing: I18n.names[ref.watch(languageProvider)],
                  onTap: () => showLanguageSheet(context, ref),
                ),
                const Divider(height: 1, indent: 56),
                tile(
                  Icons.notifications_outlined,
                  'Notifications',
                  'Bill alerts, low stock, reminders',
                  route: '/settings/notifications',
                ),
                const Divider(height: 1, indent: 56),
                tile(
                  Icons.shield_outlined,
                  'Security & privacy',
                  'Password, account, sign out',
                  route: '/settings/security',
                ),
                const Divider(height: 1, indent: 56),
                tile(
                  Icons.policy_outlined,
                  'Privacy policy',
                  'How we handle your data',
                  route: '/settings/privacy',
                ),
                const Divider(height: 1, indent: 56),
                tile(
                  Icons.help_outline,
                  'Help & support',
                  'FAQs, guides and contact us',
                  route: '/help',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Clever Bill v1.0.0  |  Made for Indian businesses 🇮🇳',
              style: TextStyle(color: C.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class BusinessSettingsScreen extends ConsumerStatefulWidget {
  const BusinessSettingsScreen({super.key});
  @override
  ConsumerState<BusinessSettingsScreen> createState() => _BizState();
}

class _BizState extends ConsumerState<BusinessSettingsScreen> {
  String _logo = '';
  bool _logoBusy = false;

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => _logoBusy = true);
    try {
      final url = await ref.read(apiProvider).uploadProductImage(x.path);
      if (url != null) setState(() => _logo = url);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _logoBusy = false);
    }
  }

  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _email = TextEditingController(),
      _addr = TextEditingController();
  final _gstin = TextEditingController(),
      _pan = TextEditingController(),
      _state = TextEditingController(),
      _prefix = TextEditingController();
  String _mode = 'SIMPLE';
  bool _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    _mode = ref.read(authProvider).billingMode;
    ref
        .read(apiProvider)
        .businessProfile()
        .then((d) {
          if (!mounted) return;
          setState(() {
            _name.text = js(d['businessName']);
            _phone.text = js(d['phone']);
            _email.text = js(d['email']);
            _addr.text = js(d['address']);
            _gstin.text = js(d['gstin'], js(d['gstNumber']));
            _pan.text = js(d['panNumber']);
            _state.text = js(d['stateCode']);
            _prefix.text = js(d['invoicePrefix']);
            _logo = js(d['logoUrl']);
            _loading = false;
          });
        })
        .catchError((_) {
          if (mounted) setState(() => _loading = false);
        });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty)
      return toast(context, 'Enter business name', error: true);
    if (_mode == 'GST' && _gstin.text.trim().isEmpty)
      return toast(context, 'Enter your GSTIN for GST billing', error: true);
    setState(() => _busy = true);
    try {
      String? n(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();
      await ref.read(apiProvider).updateBusinessProfile({
        'businessName': _name.text.trim(),
        'phone': n(_phone),
        'email': n(_email),
        'address': n(_addr),
        'gstin': n(_gstin)?.toUpperCase(),
        'gstNumber': n(_gstin)?.toUpperCase(),
        'panNumber': n(_pan)?.toUpperCase(),
        'stateCode': n(_state),
        'invoicePrefix': n(_prefix),
        'logoUrl': _logo.isEmpty ? null : _logo,
      });
      ref.read(authProvider.notifier).updateBusinessName(_name.text.trim());
      await ref.read(authProvider.notifier).setBillingMode(_mode);
      if (mounted) {
        toast(context, 'Saved');
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
    appBar: blueAppBar(context, 'Business & tax setup'),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(
                  children: [
                    AppThumb(
                      url: _logo.isEmpty ? null : _logo,
                      size: 64,
                      icon: Icons.storefront_rounded,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Business logo',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(100, 42),
                      ),
                      onPressed: _logoBusy ? null : _pickLogo,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(_logo.isEmpty ? 'Add logo' : 'Change'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Billing mode',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'SIMPLE',
                    label: Text('Simple (No GST)'),
                    icon: Icon(Icons.description_outlined),
                  ),
                  ButtonSegment(
                    value: 'GST',
                    label: Text('GST'),
                    icon: Icon(Icons.account_balance_outlined),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 18),
              LabeledField(
                label: 'Business name',
                controller: _name,
                required: true,
              ),
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
              LabeledField(
                label: 'Invoice prefix',
                controller: _prefix,
                hint: 'e.g. INV',
              ),
              if (_mode == 'GST') ...[
                LabeledField(
                  label: 'GSTIN',
                  controller: _gstin,
                  required: true,
                ),
                Row(
                  children: [
                    Expanded(
                      child: LabeledField(label: 'PAN', controller: _pan),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LabeledField(
                        label: 'State code',
                        controller: _state,
                        hint: 'e.g. 27',
                      ),
                    ),
                  ],
                ),
              ],
              PrimaryButton('Save changes', loading: _busy, onPressed: _save),
            ],
          ),
  );
}

class _SwitchSettingsScreen extends ConsumerStatefulWidget {
  const _SwitchSettingsScreen({
    required this.title,
    required this.path,
    required this.switches,
  });
  final String title, path;
  final Map<String, String> switches;
  @override
  ConsumerState<_SwitchSettingsScreen> createState() => _SwitchSettingsState();
}

class _SwitchSettingsState extends ConsumerState<_SwitchSettingsScreen> {
  Map<String, dynamic> _d = {};
  bool _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(apiClientProvider)
        .get(widget.path)
        .then((d) {
          if (mounted)
            setState(() {
              _d = jm(d);
              _loading = false;
            });
        })
        .catchError((_) {
          if (mounted) setState(() => _loading = false);
        });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).put(widget.path, body: _d);
      if (mounted) {
        toast(context, 'Saved');
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
    appBar: blueAppBar(context, widget.title),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final e in widget.switches.entries)
                      SwitchListTile(
                        value: jb(_d[e.key]),
                        title: Text(e.value),
                        onChanged: (v) => setState(() => _d[e.key] = v),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton('Save', loading: _busy, onPressed: _save),
            ],
          ),
  );
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _SwitchSettingsScreen(
    title: 'Notifications',
    path: '/api/settings/notifications',
    switches: {
      'lowStockNotifications': 'Low stock alerts',
      'expiryNotifications': 'Product expiry alerts',
      'lowStockAlertEnabled': 'Enable stock alert emails',
    },
  );
}

class BankUpiScreen extends ConsumerStatefulWidget {
  const BankUpiScreen({super.key});
  @override
  ConsumerState<BankUpiScreen> createState() => _BankState();
}

class _BankState extends ConsumerState<BankUpiScreen> {
  final _upi = TextEditingController(),
      _bank = TextEditingController(),
      _acc = TextEditingController(),
      _ifsc = TextEditingController();
  bool _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(apiProvider)
        .paymentDetails()
        .then((d) {
          if (!mounted) return;
          setState(() {
            _upi.text = js(d['upiId']);
            _bank.text = js(d['bankName']);
            _acc.text = js(d['bankAccountNo']);
            _ifsc.text = js(d['bankIfscCode']);
            _loading = false;
          });
        })
        .catchError((_) {
          if (mounted) setState(() => _loading = false);
        });
  }

  Future<void> _save() async {
    if (_upi.text.trim().isNotEmpty &&
        !RegExp(r'^[\w.\-]{2,}@[\w]{2,}$').hasMatch(_upi.text.trim()))
      return toast(context, 'Enter a valid UPI ID (name@bank)', error: true);
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).updatePaymentDetails({
        'upiId': _upi.text.trim(),
        'bankName': _bank.text.trim(),
        'bankAccountNo': _acc.text.trim(),
        'bankIfscCode': _ifsc.text.trim().toUpperCase(),
      });
      if (mounted) {
        toast(context, 'Saved');
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
    appBar: blueAppBar(context, 'Bank & UPI'),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LabeledField(
                label: 'UPI ID',
                controller: _upi,
                hint: 'shopname@bank',
              ),
              LabeledField(label: 'Bank name', controller: _bank),
              LabeledField(
                label: 'Account number',
                controller: _acc,
                keyboard: TextInputType.number,
              ),
              LabeledField(label: 'IFSC code', controller: _ifsc),
              PrimaryButton('Save', loading: _busy, onPressed: _save),
            ],
          ),
  );
}

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});
  @override
  ConsumerState<BackupScreen> createState() => _BackupState();
}

class _BackupState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(apiProvider).exportBackup();
      final dir = await getTemporaryDirectory();
      final f = File(
        '${dir.path}/cleverbill-backup-${iso(DateTime.now())}.json',
      );
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)], text: 'Clever Bill backup');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: blueAppBar(context, 'Backup & export'),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Text(
            'Export a full backup of your business data. Save it to Drive or email it to yourself.',
            style: TextStyle(color: C.muted),
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          'Export backup',
          icon: Icons.cloud_download_outlined,
          loading: _busy,
          onPressed: _export,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => context.push('/reports'),
          icon: const Icon(Icons.bar_chart),
          label: const Text('Export reports (Excel / CSV)'),
        ),
      ],
    ),
  );
}

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: blueAppBar(context, 'Security & privacy'),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.pin_outlined, color: C.primary),
                title: const Text(
                  'App lock',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  ref.watch(appLockProvider).enabled
                      ? 'PIN enabled'
                      : 'Protect the app with a 4-digit PIN',
                ),
                trailing: Switch(
                  value: ref.watch(appLockProvider).enabled,
                  onChanged: (_) => toggleAppLock(context, ref),
                ),
                onTap: () => toggleAppLock(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.lock_reset, color: C.primary),
                title: const Text(
                  'Change password',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('For email accounts'),
                onTap: () => _changePw(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.logout, color: C.primary),
                title: const Text(
                  'Sign out',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () async {
                  if (await confirm(
                    context,
                    'Sign out?',
                    'You will need to sign in again.',
                    ok: 'Sign out',
                    danger: true,
                  ))
                    ref.read(authProvider.notifier).signOut();
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: C.danger),
                title: Text(
                  'Delete account',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: C.danger,
                  ),
                ),
                subtitle: const Text(
                  'Permanently remove your account and data',
                ),
                onTap: () async {
                  if (await confirm(
                    context,
                    'Delete account?',
                    'This permanently deletes your account and business data. This cannot be undone.',
                    ok: 'Delete',
                    danger: true,
                  )) {
                    try {
                      await ref.read(apiProvider).deleteAccount(null);
                      await ref
                          .read(authProvider.notifier)
                          .signOut(callApi: false);
                    } catch (e) {
                      if (context.mounted) toast(context, '$e', error: true);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _changePw(BuildContext context, WidgetRef ref) async {
    final o = TextEditingController(), n = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: o,
              obscureText: true,
              decoration: InputDecoration(labelText: tr('Current password')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: n,
              obscureText: true,
              decoration: InputDecoration(labelText: tr('New password')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(apiProvider).changePassword(o.text, n.text);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  toast(context, 'Password changed');
                }
              } catch (e) {
                if (ctx.mounted) toast(ctx, '$e', error: true);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════ Branches & staff ═════════════════════════
class BranchesScreen extends ConsumerWidget {
  const BranchesScreen({super.key});

  Future<void> _addBranch(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(),
        city = TextEditingController(),
        addr = TextEditingController();
    await showModalBottomSheet(
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
              'Add branch',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Branch name',
              controller: name,
              required: true,
            ),
            LabeledField(label: 'City', controller: city),
            LabeledField(label: 'Address', controller: addr),
            PrimaryButton(
              'Save branch',
              onPressed: () async {
                if (name.text.trim().isEmpty)
                  return toast(ctx, 'Enter branch name', error: true);
                try {
                  await ref.read(apiProvider).saveBranch({
                    'name': name.text.trim(),
                    'city': city.text.trim(),
                    'address': addr.text.trim(),
                  });
                  ref.invalidate(branchesProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) toast(ctx, '$e', error: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _staff(BuildContext context, WidgetRef ref, Branch b) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _StaffSheet(branch: b),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(branchesProvider);
    return Scaffold(
      appBar: blueAppBar(context, 'Branches & staff'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addBranch(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add branch'),
        backgroundColor: C.primary,
        foregroundColor: Colors.white,
      ),
      body: AsyncBody<List<Branch>>(
        value: async,
        onRetry: () => ref.invalidate(branchesProvider),
        builder: (l) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            for (final b in l)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => _staff(context, ref, b),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: C.primarySoft,
                        child: Icon(
                          Icons.store_mall_directory_outlined,
                          color: C.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  b.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (b.isMain) ...[
                                  const SizedBox(width: 6),
                                  StatusChip('Main', color: C.primary),
                                ],
                              ],
                            ),
                            Text(
                              b.city.isEmpty ? b.address : b.city,
                              style: TextStyle(color: C.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Activity',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            context.push('/branch-activity', extra: b),
                        icon: Icon(Icons.insights_rounded, color: C.primary),
                      ),
                      Text(
                        'Staff',
                        style: TextStyle(
                          color: C.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: C.muted),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StaffSheet extends ConsumerStatefulWidget {
  const _StaffSheet({required this.branch});
  final Branch branch;
  @override
  ConsumerState<_StaffSheet> createState() => _StaffSheetState();
}

class _StaffSheetState extends ConsumerState<_StaffSheet> {
  late Future<List<Employee>> _f = ref
      .read(apiProvider)
      .employees(widget.branch.id);
  void _reload() =>
      setState(() => _f = ref.read(apiProvider).employees(widget.branch.id));

  Future<void> _add() async {
    final name = TextEditingController(),
        email = TextEditingController(),
        pw = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add staff'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: tr('Name')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: tr('Email')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pw,
              obscureText: true,
              decoration: InputDecoration(labelText: tr('Password')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(apiProvider).createEmployee(widget.branch.id, {
                  'name': name.text.trim(),
                  'email': email.text.trim(),
                  'password': pw.text,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _reload();
              } catch (e) {
                if (ctx.mounted) toast(ctx, '$e', error: true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.of(context).size.height * .65,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.branch.name} — Staff',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add'),
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<Employee>>(
              future: _f,
              builder: (_, s) {
                if (!s.hasData)
                  return Center(
                    child: s.hasError
                        ? Text('${s.error}')
                        : const CircularProgressIndicator(),
                  );
                if (s.data!.isEmpty)
                  return const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No staff yet',
                  );
                return ListView(
                  children: [
                    for (final e in s.data!)
                      ListTile(
                        leading: Avatar(initials(e.name), size: 40),
                        title: Text(e.name),
                        subtitle: Text(e.email),
                        trailing: Switch(
                          value: e.active,
                          onChanged: (_) async {
                            try {
                              await ref
                                  .read(apiProvider)
                                  .toggleEmployee(widget.branch.id, e.id);
                              _reload();
                            } catch (err) {
                              if (mounted) toast(context, '$err', error: true);
                            }
                          },
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

// ═════════════════════════ Help ═════════════════════════
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const faqs = [
      (
        'How do I create a bill?',
        'Tap the + New Bill button, add products (or scan a barcode), choose a customer and payment method.',
      ),
      (
        'How do I add stock?',
        'Open Inventory → Stock → tap a product → Adjust stock, or record a Purchase from a supplier.',
      ),
      (
        'How do I receive a pending payment?',
        'Go to More → Payments & dues and tap Receive on the invoice.',
      ),
      (
        'Can I switch between Simple and GST billing?',
        'Yes, from More → Settings → Business & tax setup.',
      ),
    ];
    return Scaffold(
      appBar: blueAppBar(context, 'Help & support'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final f in faqs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  shape: const Border(),
                  title: Text(
                    f.$1,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(f.$2, style: TextStyle(color: C.muted)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () =>
                launchUrl(Uri.parse('mailto:support@cleverbill.in')),
            icon: const Icon(Icons.email_outlined),
            label: const Text('Email support'),
          ),
        ],
      ),
    );
  }
}
