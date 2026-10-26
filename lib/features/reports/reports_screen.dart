import 'dart:io';

import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/widgets.dart';
import '../../providers.dart';

class ReportData {
  ReportData(this.days, this.expenses, this.top);
  final List<Map<String, dynamic>> days;
  final double expenses;
  final List<Map<String, dynamic>> top;
  double get sales => days.fold(0.0, (a, d) => a + jd(d['totalRevenue']));
  double get tax => days.fold(0.0, (a, d) => a + jd(d['totalTax']));
  double get discount => days.fold(0.0, (a, d) => a + jd(d['totalDiscount']));
  int get bills => days.fold(0, (a, d) => a + ji(d['invoiceCount']));
}

typedef ReportRange = ({DateTime from, DateTime to});

final reportProvider = FutureProvider.autoDispose
    .family<ReportData, ReportRange>((ref, r) async {
      ref.watch(selectedBranchProvider);
      final api = ref.watch(apiProvider);
      final res = await Future.wait([
        api.salesReport(r.from, r.to),
        api
            .expenses(from: r.from, to: r.to)
            .then((p) => p.items.fold(0.0, (a, e) => a + e.amount))
            .catchError((_) => 0.0),
        api
            .topProducts(r.from, r.to)
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);
      return ReportData(
        res[0] as List<Map<String, dynamic>>,
        res[1] as double,
        res[2] as List<Map<String, dynamic>>,
      );
    });

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsState();
}

class _ReportsState extends ConsumerState<ReportsScreen> {
  int _p = 0;
  DateTimeRange? _custom;
  static final _today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  ReportRange get _range => switch (_p) {
    1 => (from: _today.subtract(const Duration(days: 6)), to: _today),
    2 => (from: DateTime(_today.year, _today.month, 1), to: _today),
    3 => (from: _custom?.start ?? _today, to: _custom?.end ?? _today),
    _ => (from: _today, to: _today),
  };

  Future<void> _exportSales(bool excel) async {
    try {
      final r = _range;
      final bytes = await ref
          .read(apiProvider)
          .exportSales(r.from, r.to, excel: excel);
      final dir = await getTemporaryDirectory();
      final f = File(
        '${dir.path}/sales-${iso(r.from)}-${iso(r.to)}.${excel ? 'xlsx' : 'csv'}',
      );
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)]);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _range;
    final chartRange = _p == 0
        ? (from: _today.subtract(const Duration(days: 6)), to: _today)
        : r;
    final async = ref.watch(reportProvider(r));
    final chart = _p == 0 ? ref.watch(reportProvider(chartRange)) : async;
    final dues = (ref.watch(customersProvider).valueOrNull ?? []).fold(
      0.0,
      (a, c) => a + c.outstanding,
    );
    const labels = ['Today', 'Week', 'Month', 'Custom'];
    return Scaffold(
      appBar: blueAppBar(
        context,
        'Reports',
        subtitle: ref.watch(authProvider).session?.businessName,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilterChips(
            labels: labels,
            selected: _p,
            onSelect: (i) async {
              if (i == 3) {
                final d = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d == null) return;
                _custom = d;
              }
              setState(() => _p = i);
            },
          ),
          const SizedBox(height: 6),
          Text(
            r.from == r.to
                ? dateShort(r.from)
                : '${dateShort(r.from)} – ${dateShort(r.to)}',
            style: TextStyle(color: C.muted),
          ),
          const SizedBox(height: 10),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load',
              message: '$e',
              action: OutlinedButton(
                onPressed: () => ref.invalidate(reportProvider(r)),
                child: const Text('Retry'),
              ),
            ),
            data: (d) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Total sales',
                        value: money(d.sales),
                        icon: Icons.shopping_cart_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: 'Bills',
                        value: '${d.bills}',
                        color: C.success,
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Customer dues',
                        value: money(dues),
                        color: C.warning,
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: 'Total expense',
                        value: money(d.expenses),
                        color: C.danger,
                        icon: Icons.receipt_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Tax collected',
                        value: money(d.tax),
                        icon: Icons.account_balance_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: 'Sales − expenses',
                        value: money(d.sales - d.expenses),
                        color: C.success,
                        icon: Icons.trending_up,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales trend${_p == 0 ? ' (last 7 days)' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                chart.maybeWhen(
                  data: (d) => SalesBarChart(
                    labels: [
                      for (final x in d.days)
                        js(x['date']).length >= 10
                            ? js(x['date']).substring(8, 10)
                            : js(x['date']),
                    ],
                    values: [for (final x in d.days) jd(x['totalRevenue'])],
                  ),
                  orElse: () => const SizedBox(
                    height: 170,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
            ),
          ),
          async.maybeWhen(
            data: (d) => d.top.isEmpty
                ? const SizedBox()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Top products'),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final p
                                in d.top.take(5).toList().asMap().entries)
                              ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: C.primarySoft,
                                  child: Text(
                                    '${p.key + 1}',
                                    style: TextStyle(
                                      color: C.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  js(p.value['productName'] ?? p.value['name']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                trailing: Text(
                                  money(
                                    jd(
                                      p.value['totalRevenue'] ??
                                          p.value['revenue'] ??
                                          p.value['totalAmount'],
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
            orElse: () => const SizedBox(),
          ),
          const SectionTitle('Reports'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.3,
            children: [
              _RepTile(
                Icons.bar_chart,
                'Sales report',
                'Export as Excel',
                () => _exportSales(true),
              ),
              _RepTile(
                Icons.inventory_2_outlined,
                'Stock report',
                'View stock levels',
                () => context.go('/inventory'),
              ),
              _RepTile(
                Icons.description_outlined,
                'GST summary',
                'Tax collection details',
                () {
                  final d = async.valueOrNull;
                  if (d == null) return;
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('GST summary'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sales (incl. tax): ${money(d.sales)}'),
                          Text('Tax collected: ${money(d.tax)}'),
                          Text('Discounts given: ${money(d.discount)}'),
                          const SizedBox(height: 8),
                          Text(
                            'Use the Excel export for the invoice-wise GST breakup.',
                            style: TextStyle(color: C.muted, fontSize: 12),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _RepTile(
                Icons.groups_outlined,
                'Customer dues',
                'Pending payments',
                () => context.push('/payments'),
              ),
              _RepTile(
                Icons.download_outlined,
                'Export (CSV)',
                'Download or share',
                () => _exportSales(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RepTile extends StatelessWidget {
  const _RepTile(this.i, this.t, this.s, this.f);
  final IconData i;
  final String t, s;
  final VoidCallback f;
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: f,
    padding: const EdgeInsets.all(10),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: C.primarySoft,
          child: Icon(i, color: C.primary, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Text(
                s,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: C.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
