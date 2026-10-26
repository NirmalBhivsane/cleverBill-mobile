import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';

// ═════════════════════════ Profile ═════════════════════════
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController(), _phone = TextEditingController();
  String _email = '', _photo = '';
  bool _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(apiProvider)
        .profile()
        .then((d) {
          if (!mounted) return;
          setState(() {
            _name.text = js(d['name']);
            _phone.text = js(d['phoneNumber']);
            _email = js(d['email']);
            _photo = js(d['profilePhoto']);
            _loading = false;
          });
        })
        .catchError((_) {
          if (mounted) {
            final s = ref.read(authProvider).session;
            setState(() {
              _name.text = s?.name ?? '';
              _phone.text = s?.phone ?? '';
              _email = s?.email ?? '';
              _loading = false;
            });
          }
        });
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => _busy = true);
    try {
      final url = await ref.read(apiProvider).uploadProductImage(x.path);
      if (url != null) setState(() => _photo = url);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty)
      return toast(context, 'Enter your name', error: true);
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).updateProfile({
        'name': _name.text.trim(),
        'phoneNumber': _phone.text.trim(),
        'profilePhoto': _photo,
      });
      ref.invalidate(profileProvider);
      if (mounted) toast(context, 'Profile updated');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(authProvider).session;
    return Scaffold(
      appBar: blueAppBar(context, 'My profile', subtitle: s?.businessName),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    children: [
                      _photo.isNotEmpty
                          ? ClipOval(
                              child: SizedBox(
                                width: 96,
                                height: 96,
                                child: AppThumb(
                                  url: _photo,
                                  size: 96,
                                  icon: Icons.person,
                                ),
                              ),
                            )
                          : Avatar(initials(_name.text), size: 96),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: InkWell(
                          onTap: _pickPhoto,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: C.primary,
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: StatusChip(
                    (s?.role ?? '').replaceAll('_', ' '),
                    color: C.primary,
                  ),
                ),
                const SizedBox(height: 18),
                LabeledField(
                  label: 'Full name',
                  controller: _name,
                  required: true,
                ),
                LabeledField(
                  label: 'Phone number',
                  controller: _phone,
                  keyboard: TextInputType.phone,
                ),
                Text(
                  'Email',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 6),
                InputDecorator(
                  decoration: const InputDecoration(),
                  child: Text(
                    _email.isEmpty ? '—' : _email,
                    style: TextStyle(color: C.muted),
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryButton('Save profile', loading: _busy, onPressed: _save),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push('/settings/business'),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Business details'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push('/settings/security'),
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Security & privacy'),
                ),
              ],
            ),
    );
  }
}

// ═════════════════════════ Branch activity ═════════════════════════
class BranchActivityScreen extends ConsumerStatefulWidget {
  const BranchActivityScreen({super.key, required this.branch});
  final Branch branch;
  @override
  ConsumerState<BranchActivityScreen> createState() => _BranchActivityState();
}

class _BranchActivityState extends ConsumerState<BranchActivityScreen> {
  late Future<Map<String, dynamic>> _f = ref
      .read(apiProvider)
      .branchActivity(widget.branch.id);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: blueAppBar(
      context,
      widget.branch.name,
      subtitle: 'Branch activity',
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _f,
      builder: (_, snap) {
        if (!snap.hasData)
          return snap.hasError
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load',
                  message: '${snap.error}',
                  action: OutlinedButton(
                    onPressed: () => setState(
                      () => _f = ref
                          .read(apiProvider)
                          .branchActivity(widget.branch.id),
                    ),
                    child: const Text('Retry'),
                  ),
                )
              : const Center(child: CircularProgressIndicator());
        final d = snap.data!;
        final weekly = jlist(d['weeklyChart'], (m) => m);
        final recent = jlist(d['recentTransactions'], (m) => m);
        Widget gr(double g, bool pos) => Text(
          '${pos ? '↑' : '↓'} ${g.abs().toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 11,
            color: pos ? C.success : C.danger,
            fontWeight: FontWeight.w700,
          ),
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Today revenue',
                    value: money(jd(d['todayRevenue'])),
                    sub: '${ji(d['todayOrders'])} orders',
                    icon: Icons.today_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Today profit',
                    value: money(jd(d['todayProfit'])),
                    color: C.success,
                    icon: Icons.trending_up,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Month revenue',
                    value: money(jd(d['monthRevenue'])),
                    sub: '${ji(d['monthOrders'])} orders',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Net profit',
                    value: money(jd(d['netProfit'])),
                    color: C.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Inventory value',
                    value: money(jd(d['inventoryValue'])),
                    color: C.warning,
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Staff active',
                    value: '${ji(d['activeStaff'])}/${ji(d['totalStaff'])}',
                    icon: Icons.groups_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                gr(
                  jd(d['revenueGrowthPercent']),
                  jb(d['revenueGrowthPositive'], true),
                ),
                const Text('  revenue growth', style: TextStyle(fontSize: 11)),
              ],
            ),
            if (weekly.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This week',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SalesBarChart(
                        labels: [for (final w in weekly) js(w['day'])],
                        values: [for (final w in weekly) jd(w['revenue'])],
                      ),
                    ],
                  ),
                ),
              ),
            const SectionTitle('Recent transactions'),
            if (recent.isEmpty)
              AppCard(
                child: Text(
                  'No transactions yet',
                  style: TextStyle(color: C.muted),
                ),
              ),
            for (final t in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: C.primarySoft,
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: C.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              js(t['invoiceNo']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${js(t['customerName'], 'Walk-in')} • ${js(t['time'])}',
                              style: TextStyle(color: C.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money(jd(t['amount'])),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            js(t['paymentMode']),
                            style: TextStyle(color: C.muted, fontSize: 11),
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

// ═════════════════════════ Generic settings form ═════════════════════════
enum FType { toggle, text, number, choice }

class SField {
  const SField(
    this.key,
    this.label,
    this.type, {
    this.options = const [],
    this.hint,
    this.max,
  });
  final String key, label;
  final FType type;
  final List<String> options;
  final String? hint;
  final int? max;
}

/// Loads a settings document from [path] (GET), edits the listed fields and PUTs the whole document back.
class SettingsFormScreen extends ConsumerStatefulWidget {
  const SettingsFormScreen({
    super.key,
    required this.title,
    required this.path,
    required this.fields,
    this.intro,
  });
  final String title, path;
  final String? intro;
  final List<SField> fields;
  @override
  ConsumerState<SettingsFormScreen> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<SettingsFormScreen> {
  Map<String, dynamic> _d = {};
  final Map<String, TextEditingController> _c = {};
  bool _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(apiClientProvider)
        .get(widget.path)
        .then((d) {
          if (!mounted) return;
          _d = jm(d);
          for (final f in widget.fields.where(
            (f) => f.type == FType.text || f.type == FType.number,
          )) {
            final v = _d[f.key];
            _c[f.key] = TextEditingController(text: v == null ? '' : '$v');
          }
          setState(() => _loading = false);
        })
        .catchError((e) {
          if (mounted) {
            setState(() => _loading = false);
            toast(context, '$e', error: true);
          }
        });
  }

  Future<void> _save() async {
    for (final f in widget.fields) {
      if (f.type == FType.text)
        _d[f.key] = _c[f.key]!.text.trim().isEmpty
            ? null
            : _c[f.key]!.text.trim();
      if (f.type == FType.number)
        _d[f.key] = _c[f.key]!.text.trim().isEmpty
            ? null
            : (num.tryParse(_c[f.key]!.text.trim()) ?? _d[f.key]);
    }
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
              if (widget.intro != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(widget.intro!, style: TextStyle(color: C.muted)),
                ),
              for (final f in widget.fields) ...[
                if (f.type == FType.toggle)
                  AppCard(
                    padding: EdgeInsets.zero,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: SwitchListTile(
                      value: jb(_d[f.key]),
                      title: Text(
                        f.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onChanged: (v) => setState(() => _d[f.key] = v),
                    ),
                  )
                else if (f.type == FType.choice)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: f.options.contains('${_d[f.key]}')
                              ? '${_d[f.key]}'
                              : null,
                          isExpanded: true,
                          items: [
                            for (final o in f.options)
                              DropdownMenuItem(value: o, child: Text(o)),
                          ],
                          onChanged: (v) => setState(() => _d[f.key] = v),
                        ),
                      ],
                    ),
                  )
                else
                  LabeledField(
                    label: f.label,
                    controller: _c[f.key]!,
                    hint: f.hint,
                    keyboard: f.type == FType.number
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : null,
                    maxLines: f.max ?? 1,
                  ),
              ],
              const SizedBox(height: 8),
              PrimaryButton('Save changes', loading: _busy, onPressed: _save),
            ],
          ),
  );
}

class GstTaxScreen extends StatelessWidget {
  const GstTaxScreen({super.key});
  @override
  Widget build(BuildContext context) => const SettingsFormScreen(
    title: 'GST & tax',
    path: '/api/settings',
    intro: 'Your GST details are printed on tax invoices.',
    fields: [
      SField('gstin', 'GSTIN', FType.text, hint: '22AAAAA0000A1Z5'),
      SField('panNumber', 'PAN', FType.text),
      SField(
        'stateCode',
        'State code',
        FType.text,
        hint: 'e.g. 27 for Maharashtra',
      ),
      SField(
        'defaultTaxRate',
        'Default tax rate (%)',
        FType.choice,
        options: ['0', '5', '12', '18', '28'],
      ),
      SField('invoicePrefix', 'Invoice number prefix', FType.text, hint: 'INV'),
    ],
  );
}

class BusinessDefaultsScreen extends StatelessWidget {
  const BusinessDefaultsScreen({super.key});
  @override
  Widget build(BuildContext context) => const SettingsFormScreen(
    title: 'Business defaults',
    path: '/api/settings',
    fields: [
      SField(
        'defaultCreditLimit',
        'Default customer credit limit (₹)',
        FType.number,
      ),
      SField(
        'expenseAutoApprovalLimit',
        'Auto-approve expenses up to (₹)',
        FType.number,
      ),
      SField('lowStockThreshold', 'Default low-stock threshold', FType.number),
      SField('expiryAlertDays', 'Expiry alert (days before)', FType.number),
      SField('lowStockAlertEnabled', 'Low stock alerts', FType.toggle),
      SField('autoBackupEnabled', 'Automatic backup', FType.toggle),
      SField('backupEmail', 'Backup email', FType.text),
    ],
  );
}

class HardwareScreen extends StatelessWidget {
  const HardwareScreen({super.key});
  @override
  Widget build(BuildContext context) => const SettingsFormScreen(
    title: 'Printer & barcode',
    path: '/api/settings/thermal-print',
    intro: 'Thermal (receipt) printer layout. Barcode scanning uses your phone camera from the New Bill and Products screens.',
    fields: [
      SField('thermalShowLogo', 'Show logo', FType.toggle),
      SField('thermalShowBusinessName', 'Show business name', FType.toggle),
      SField('thermalShowAddress', 'Show address', FType.toggle),
      SField('thermalShowPhone', 'Show phone', FType.toggle),
      SField('thermalShowSku', 'Show SKU', FType.toggle),
      SField('thermalShowHsn', 'Show HSN', FType.toggle),
      SField('thermalShowMrp', 'Show MRP', FType.toggle),
      SField('thermalShowUpi', 'Show UPI QR', FType.toggle),
      SField('thermalAutoCut', 'Auto-cut paper', FType.toggle),
      SField(
        'thermalShowPoweredBy',
        'Show “Powered by Clever Bill”',
        FType.toggle,
      ),
      SField('thermalPrintCopies', 'Number of copies', FType.number),
      SField('thermalFooterText', 'Footer text', FType.text),
    ],
  );
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: blueAppBar(context, 'Privacy policy'),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AppCard(
          child: Text(
            'Clever Bill stores your business data (products, customers, invoices and payments) securely to provide billing and inventory services. '
            'We do not sell your data. You can export a backup or delete your account at any time from Settings → Security & privacy.',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => launchUrl(
            Uri.parse('https://cleverbill.in/privacy-policy'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Read the full policy'),
        ),
      ],
    ),
  );
}
