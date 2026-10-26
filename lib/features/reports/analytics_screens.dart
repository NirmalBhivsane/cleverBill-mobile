import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/widgets.dart';
import '../../providers.dart';

typedef _Key = ({String kind, String period});
final _analyticsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, _Key>((ref, k) {
      ref.watch(selectedBranchProvider);
      return ref.watch(apiProvider).analytics(k.kind, k.period);
    });

/// Insights: product / category / customer / invoice / expense analytics (web "Analytics" pages).
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsState();
}

class _AnalyticsState extends ConsumerState<AnalyticsScreen> {
  int _p = 0;
  static const periods = [
    ('30days', '30 days'),
    ('6months', '6 months'),
    ('1year', '1 year'),
  ];
  static const tabs = [
    ('products', 'Products'),
    ('categories', 'Categories'),
    ('customers', 'Customers'),
    ('invoices', 'Invoices'),
    ('expenses', 'Expenses'),
  ];

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: tabs.length,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: C.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Insights',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabAlignment: TabAlignment.start,
          tabs: [for (final t in tabs) Tab(child: Text(t.$2))],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilterChips(
              labels: [for (final p in periods) p.$2],
              selected: _p,
              onSelect: (i) => setState(() => _p = i),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final t in tabs) _Tab(kind: t.$1, period: periods[_p].$1),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Tab extends ConsumerWidget {
  const _Tab({required this.kind, required this.period});
  final String kind, period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (kind: kind, period: period);
    final async = ref.watch(_analyticsProvider(key));
    return AsyncBody<Map<String, dynamic>>(
      value: async,
      onRetry: () => ref.invalidate(_analyticsProvider(key)),
      builder: (d) => RefreshIndicator(
        onRefresh: () async => ref.refresh(_analyticsProvider(key).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: switch (kind) {
            'products' => _products(d),
            'categories' => _categories(d),
            'customers' => _customers(d),
            'invoices' => _invoices(d),
            _ => _expenses(d),
          },
        ),
      ),
    );
  }

  Widget _empty(String t) => Padding(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: Text(t, style: TextStyle(color: C.muted)),
    ),
  );

  Widget _bars(
    List<({String label, double value, String trailing})> rows, {
    Color? color,
  }) {
    if (rows.isEmpty) return _empty('No data for this period');
    final maxV = rows.map((r) => r.value).fold(0.0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      r.trailing,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maxV <= 0 ? 0 : r.value / maxV,
                    minHeight: 8,
                    backgroundColor: C.border,
                    color: color ?? C.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _card(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );

  List<Widget> _products(Map<String, dynamic> d) {
    final best = jlist(d['bestSellers'], (m) => m),
        slow = jlist(d['slowMovers'], (m) => m);
    return [
      Row(
        children: [
          Expanded(
            child: StatTile(
              label: 'Stock value',
              value: money(jd(d['totalStockValue'])),
              icon: Icons.inventory_2_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              label: 'Stock turnover',
              value: jd(d['stockTurnoverRate']).toStringAsFixed(2),
              color: C.success,
              icon: Icons.sync,
            ),
          ),
        ],
      ),
      _card(
        'Best sellers',
        _bars([
          for (final b in best)
            (
              label: js(b['productName']),
              value: jd(b['totalRevenue']),
              trailing: money(jd(b['totalRevenue'])),
            ),
        ]),
      ),
      _card(
        'Slow movers',
        slow.isEmpty
            ? _empty('No slow movers 🎉')
            : Column(
                children: [
                  for (final s in slow)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        js(s['productName']),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Sold ${ji(s['quantitySold'])} • SKU ${js(s['sku'], '—')}',
                      ),
                      trailing: StatusChip(
                        'Stock ${ji(s['currentStock'])}',
                        color: C.warning,
                      ),
                    ),
                ],
              ),
      ),
    ];
  }

  List<Widget> _categories(Map<String, dynamic> d) {
    final rev = jlist(d['revenueByCategory'], (m) => m),
        mom = jlist(d['momGrowth'], (m) => m);
    return [
      _card(
        'Revenue by category',
        _bars([
          for (final c in rev)
            (
              label: js(c['categoryName']),
              value: jd(c['totalRevenue']),
              trailing:
                  '${money(jd(c['totalRevenue']))}  (${jd(c['percentage']).toStringAsFixed(0)}%)',
            ),
        ]),
      ),
      _card(
        'Month-on-month growth',
        mom.isEmpty
            ? _empty('Not enough data')
            : Column(
                children: [
                  for (final m in mom)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        js(m['categoryName']),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${money(jd(m['previousMonthRevenue']))} → ${money(jd(m['currentMonthRevenue']))}',
                      ),
                      trailing: StatusChip(
                        '${jd(m['growthPercentage']) >= 0 ? '+' : ''}${jd(m['growthPercentage']).toStringAsFixed(1)}%',
                        color: jd(m['growthPercentage']) >= 0
                            ? C.success
                            : C.danger,
                      ),
                    ),
                ],
              ),
      ),
    ];
  }

  List<Widget> _customers(Map<String, dynamic> d) {
    final top = jlist(d['topBuyers'], (m) => m);
    Widget t(String l, String v, Color c, IconData i) =>
        StatTile(label: l, value: v, color: c, icon: i);
    return [
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.9,
        children: [
          t(
            'Total customers',
            '${ji(d['totalCustomers'])}',
            C.primary,
            Icons.groups_outlined,
          ),
          t(
            'Active',
            '${ji(d['activeCustomers'])}',
            C.success,
            Icons.verified_outlined,
          ),
          t(
            'New',
            '${ji(d['newCustomers'])}',
            C.primary,
            Icons.person_add_alt_1_outlined,
          ),
          t(
            'Returning',
            '${ji(d['returningCustomers'])}',
            C.warning,
            Icons.repeat,
          ),
          t(
            'Avg. order value',
            money(jd(d['averageOrderValue'])),
            C.primary,
            Icons.shopping_basket_outlined,
          ),
          t(
            'Retention',
            '${jd(d['retentionRate']).toStringAsFixed(1)}%',
            C.success,
            Icons.favorite_border,
          ),
        ],
      ),
      _card(
        'Top buyers',
        top.isEmpty
            ? _empty('No data')
            : Column(
                children: [
                  for (final b in top.asMap().entries)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: C.primarySoft,
                        child: Text(
                          '${b.key + 1}',
                          style: TextStyle(
                            color: C.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        js(b.value['name']),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${ji(b.value['invoiceCount'])} invoices • last ${js(b.value['lastPurchaseDate'], '—')}',
                      ),
                      trailing: Text(
                        money(jd(b.value['totalPurchase'])),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
      ),
    ];
  }

  List<Widget> _invoices(Map<String, dynamic> d) {
    final modes = jlist(d['paymentModeBreakdown'], (m) => m),
        daily = jlist(d['dailyCountChart'], (m) => m);
    return [
      StatTile(
        label: 'Cancellation rate',
        value: '${jd(d['cancellationRate']).toStringAsFixed(1)}%',
        color: C.danger,
        icon: Icons.cancel_outlined,
      ),
      _card(
        'Payment methods',
        _bars([
          for (final m in modes)
            (
              label: js(m['paymentMode']),
              value: jd(m['totalAmount']),
              trailing: '${ji(m['count'])} • ${money(jd(m['totalAmount']))}',
            ),
        ]),
      ),
      _card(
        'Invoices per day',
        SalesBarChart(
          labels: [
            for (final x in daily)
              js(x['date']).length >= 10
                  ? js(x['date']).substring(8, 10)
                  : js(x['date']),
          ],
          values: [for (final x in daily) jd(x['count'])],
          highlightLast: false,
        ),
      ),
    ];
  }

  List<Widget> _expenses(Map<String, dynamic> d) {
    final cats = jlist(d['categoryWiseSpend'], (m) => m),
        months = jlist(d['monthlyComparison'], (m) => m);
    return [
      _card(
        'Spend by category',
        _bars([
          for (final c in cats)
            (
              label: js(c['category']),
              value: jd(c['totalAmount']),
              trailing:
                  '${money(jd(c['totalAmount']))}  (${jd(c['percentage']).toStringAsFixed(0)}%)',
            ),
        ], color: C.danger),
      ),
      _card(
        'Monthly comparison',
        SalesBarChart(
          labels: [
            for (final m in months)
              js(m['month']).length > 3
                  ? js(m['month']).substring(0, 3)
                  : js(m['month']),
          ],
          values: [for (final m in months) jd(m['totalAmount'])],
        ),
      ),
    ];
  }
}
