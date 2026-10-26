import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';

/// Shop + branch selector pill used on Home and POS.
class BranchPill extends ConsumerWidget {
  const BranchPill({super.key, this.dark = false});
  final bool dark;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final s = auth.session;
    final selected = ref.watch(selectedBranchProvider);
    final branches = ref.watch(branchesProvider).valueOrNull ?? [];
    final cur = branches
        .where((b) => b.id == (selected ?? s?.branchId))
        .firstOrNull;
    final branchName =
        cur?.name ??
        s?.branchName ??
        (branches.isNotEmpty ? 'All branches' : 'Main branch');
    final canSwitch = (s?.isOwner ?? false) && branches.length > 1;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: !canSwitch ? null : () => _pick(context, ref, branches, selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, color: C.primary, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s?.businessName ?? 'My Shop',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    branchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: C.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (canSwitch)
              Icon(Icons.keyboard_arrow_down_rounded, color: C.muted),
          ],
        ),
      ),
    );
  }

  void _pick(
    BuildContext context,
    WidgetRef ref,
    List<Branch> branches,
    String? selected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select branch',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('All branches'),
              trailing: selected == null
                  ? Icon(Icons.check_circle, color: C.primary)
                  : null,
              onTap: () {
                ref.read(selectedBranchProvider.notifier).select(null);
                Navigator.pop(context);
              },
            ),
            for (final b in branches)
              ListTile(
                leading: const Icon(Icons.store_mall_directory_outlined),
                title: Text(b.name),
                subtitle: Text(b.city),
                trailing: selected == b.id
                    ? Icon(Icons.check_circle, color: C.primary)
                    : null,
                onTap: () {
                  ref.read(selectedBranchProvider.notifier).select(b.id);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, Color? color}) : _color = color;
  final Color? _color;
  Color get color => _color ?? C.text;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    return IconButton(
      onPressed: () => context
          .push('/notifications')
          .then((_) => ref.invalidate(unreadCountProvider)),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_none_rounded, color: color, size: 28),
          if (n > 0)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: C.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.card, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good morning'
        : h < 17
        ? 'Good afternoon'
        : 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeProvider);
    final products = ref.watch(productsProvider).valueOrNull ?? [];
    final customers = ref.watch(customersProvider).valueOrNull ?? [];
    final recent =
        ref
            .watch(
              invoicesProvider(
                DateTime(DateTime.now().year, DateTime.now().month),
              ),
            )
            .valueOrNull ??
        [];
    final s = ref.watch(authProvider).session;
    final low = products.where((p) => p.isLow || p.isOut).toList();
    final dues = customers.fold(0.0, (a, c) => a + c.outstanding);
    final fullName = (s?.name ?? '').trim();
    final firstName = fullName.isEmpty
        ? 'there'
        : fullName.split(RegExp(r'\s+')).first;

    Widget roundBtn(Widget child) => Container(
      decoration: BoxDecoration(
        color: C.card,
        shape: BoxShape.circle,
        border: Border.all(color: C.border),
      ),
      child: child,
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeProvider);
            ref.invalidate(productsProvider);
            ref.invalidate(customersProvider);
            ref.invalidate(unreadCountProvider);
            await ref.read(homeProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              // ── Greeting header ──
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: C.primary, width: 1.6),
                      ),
                      child: Avatar(
                        initials(s?.name ?? 'U'),
                        size: 40,
                        color: C.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: TextStyle(
                            color: C.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$firstName 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: C.text,
                            letterSpacing: -.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  roundBtn(
                    IconButton(
                      onPressed: () => context.push('/search'),
                      icon: Icon(Icons.search_rounded, color: C.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  roundBtn(const NotificationBell()),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: BranchPill()),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: C.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: C.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Today',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AsyncBody<Map<String, dynamic>>(
                value: data,
                onRetry: () => ref.invalidate(homeProvider),
                builder: (d) {
                  final dash = jm(d['dash']);
                  final home = jm(d['home']);
                  final sales = jd(
                    dash['selectedDayRevenue'] ?? home['todaySales'],
                  );
                  final bills = ji(
                    dash['selectedDayInvoiceCount'] ?? home['todayOrders'],
                  );
                  final profit = jd(home['todayProfit']);
                  final growth = jd(
                    dash['dayRevenueGrowth'] ?? home['salesGrowthPercent'],
                  );
                  final weekly = jlist(home['weeklyChart'], (m) => m);
                  List<String> labels = [for (final w in weekly) js(w['day'])];
                  List<double> vals = [for (final w in weekly) jd(w['amount'])];
                  if (vals.isEmpty) {
                    final rc = jlist(dash['revenueChart'], (m) => m);
                    labels = [
                      for (final w in rc)
                        js(w['label'] ?? w['date'] ?? w['day']).split('-').last,
                    ];
                    vals = [
                      for (final w in rc) jd(w['revenue'] ?? w['amount']),
                    ];
                  }
                  final weekTotal = vals.fold(0.0, (a, b) => a + b);
                  final showGrowth = sales > 0 && growth != 0;
                  return Column(
                    children: [
                      // ── Hero summary card ──
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [C.primary, C.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: C.primary.withOpacity(.30),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  "Today's sales",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                if (showGrowth)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(.18),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          growth >= 0
                                              ? Icons.arrow_upward_rounded
                                              : Icons.arrow_downward_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${growth.abs().toStringAsFixed(0)}% vs yesterday',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                money(sales),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.14),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  _HeroStat('Profit', money(profit)),
                                  const _HeroDivider(),
                                  _HeroStat('Bills', '$bills'),
                                  const _HeroDivider(),
                                  _HeroStat(
                                    'Dues',
                                    money(dues),
                                    onTap: () => context.push('/payments'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/pos'),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('New bill'),
                      ),
                      const SizedBox(height: 14),
                      // ── Quick actions (equal size) ──
                      SizedBox(
                        height: 96,
                        child: Row(
                          children: [
                            _Quick(
                              Icons.inventory_2_outlined,
                              'Add product',
                              C.success,
                              () => context.push('/product-form'),
                            ),
                            _Quick(
                              Icons.currency_rupee,
                              'Receive\npayment',
                              C.primary,
                              () => context.push('/payments'),
                            ),
                            _Quick(
                              Icons.receipt_outlined,
                              'Add expense',
                              C.warning,
                              () => context.push('/expenses'),
                            ),
                            _Quick(
                              Icons.qr_code_scanner_rounded,
                              'Scan',
                              C.primary,
                              () => context.push('/scan'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Weekly sales ──
                      AppCard(
                        onTap: () => context.push('/reports'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Sales ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '(Last 7 days)',
                                  style: TextStyle(color: C.muted),
                                ),
                                const Spacer(),
                                if (weekTotal > 0)
                                  Text(
                                    money(weekTotal),
                                    style: TextStyle(
                                      color: C.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (weekTotal > 0)
                              SalesBarChart(labels: labels, values: vals)
                            else
                              Container(
                                height: 130,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: C.primarySoft,
                                      child: Icon(
                                        Icons.bar_chart_rounded,
                                        color: C.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'No sales in the last 7 days',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Create a bill to see your trend here',
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
                      ),
                    ],
                  );
                },
              ),
              if (low.isNotEmpty) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: C.danger),
                          const SizedBox(width: 8),
                          const Text(
                            'Low stock alert',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.go('/inventory'),
                            child: const Text('View all ›'),
                          ),
                        ],
                      ),
                      for (final p in low.take(2))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => context.push('/product/${p.id}'),
                          leading: AppThumb(url: p.imageUrl),
                          title: Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            p.isOut ? 'Out of stock' : 'Only ${p.stock} left',
                            style: TextStyle(
                              color: C.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                    ],
                  ),
                ),
              ],
              SectionTitle(
                'Recent bills',
                action: 'View all ›',
                onAction: () => context.go('/bills'),
              ),
              if (recent.isEmpty)
                AppCard(
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
                        child: Text(
                          'No bills yet. Create your first bill!',
                          style: TextStyle(color: C.muted),
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final inv in recent.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => context.push('/invoice/${inv.id}'),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: C.primarySoft,
                            child: Icon(
                              Icons.description_outlined,
                              color: C.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  inv.number,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  dateTime12(inv.createdAt),
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusChip.forStatus(inv.uiStatus),
                          const SizedBox(width: 10),
                          Text(
                            money(inv.total),
                            style: const TextStyle(fontWeight: FontWeight.w800),
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

class _HeroStat extends StatelessWidget {
  const _HeroStat(this.label, this.value, {this.onTap});
  final String label, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: Colors.white24);
}

class _Quick extends StatelessWidget {
  const _Quick(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: C.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
