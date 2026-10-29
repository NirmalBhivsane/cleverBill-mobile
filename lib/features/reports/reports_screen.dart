import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_download.dart';
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
    3 => (from: DateTime(_today.year, _today.month - 5, 1), to: _today),
    4 => (from: DateTime(_today.year, 1, 1), to: _today),
    5 => (from: _custom?.start ?? _today, to: _custom?.end ?? _today),
    _ => (from: _today, to: _today),
  };

  String _generateSalesCsv(ReportData d, ReportRange r) {
    final buf = StringBuffer();
    buf.writeln('Clever Bill - Sales Report');
    buf.writeln('Period,${iso(r.from)} to ${iso(r.to)}');
    buf.writeln('');
    buf.writeln('Date,Invoices,Taxable Sales (INR),Tax Collected (INR),Discounts (INR),Total Revenue (INR)');
    for (final day in d.days) {
      final date = js(day['date']);
      final invoices = ji(day['invoiceCount']);
      final rev = jd(day['totalRevenue']);
      final tax = jd(day['totalTax']);
      final disc = jd(day['totalDiscount']);
      final taxable = (rev - tax) < 0 ? 0.0 : (rev - tax);
      buf.writeln(
        '$date,$invoices,${taxable.toStringAsFixed(2)},${tax.toStringAsFixed(2)},${disc.toStringAsFixed(2)},${rev.toStringAsFixed(2)}',
      );
    }
    buf.writeln('');
    buf.writeln('SUMMARY');
    buf.writeln('Total Invoices,${d.bills}');
    buf.writeln('Total Sales (incl. Tax),${d.sales.toStringAsFixed(2)}');
    buf.writeln('Total Tax Collected,${d.tax.toStringAsFixed(2)}');
    buf.writeln('Total Discounts,${d.discount.toStringAsFixed(2)}');
    buf.writeln('Total Expenses,${d.expenses.toStringAsFixed(2)}');
    buf.writeln('Net (Sales - Expenses),${(d.sales - d.expenses).toStringAsFixed(2)}');

    if (d.top.isNotEmpty) {
      buf.writeln('');
      buf.writeln('TOP PRODUCTS');
      buf.writeln('Product,Quantity,Revenue (INR)');
      for (final p in d.top) {
        final name = js(p['productName'] ?? p['name']).replaceAll(',', ' ');
        final qty = ji(p['totalQuantity'] ?? p['quantity'] ?? p['qty']);
        final rev = jd(p['totalRevenue'] ?? p['revenue'] ?? p['totalAmount']);
        buf.writeln('$name,$qty,${rev.toStringAsFixed(2)}');
      }
    }
    return buf.toString();
  }

  String _generateGstCsv(ReportData d, ReportRange r) {
    final buf = StringBuffer();
    buf.writeln('Clever Bill - GST Summary Report');
    buf.writeln('Period,${iso(r.from)} to ${iso(r.to)}');
    buf.writeln('');
    buf.writeln('Date,Invoices,Taxable Value (INR),CGST (INR),SGST (INR),Total Tax Collected (INR),Gross Revenue (INR)');
    for (final day in d.days) {
      final date = js(day['date']);
      final invoices = ji(day['invoiceCount']);
      final rev = jd(day['totalRevenue']);
      final tax = jd(day['totalTax']);
      final taxable = (rev - tax) < 0 ? 0.0 : (rev - tax);
      final halfTax = tax / 2;
      buf.writeln(
        '$date,$invoices,${taxable.toStringAsFixed(2)},${halfTax.toStringAsFixed(2)},${halfTax.toStringAsFixed(2)},${tax.toStringAsFixed(2)},${rev.toStringAsFixed(2)}',
      );
    }
    buf.writeln('');
    buf.writeln('GST SUMMARY');
    final taxableTotal = (d.sales - d.tax) < 0 ? 0.0 : (d.sales - d.tax);
    final cgst = d.tax / 2;
    final sgst = d.tax / 2;
    buf.writeln('Gross Sales (incl. Tax),${d.sales.toStringAsFixed(2)}');
    buf.writeln('Taxable Value (excl. Tax),${taxableTotal.toStringAsFixed(2)}');
    buf.writeln('Central GST (CGST 50%),${cgst.toStringAsFixed(2)}');
    buf.writeln('State GST (SGST 50%),${sgst.toStringAsFixed(2)}');
    buf.writeln('Total GST Collected,${d.tax.toStringAsFixed(2)}');
    buf.writeln('Total Invoices,${d.bills}');
    return buf.toString();
  }

  Future<void> _exportSales(bool excel) async {
    try {
      final r = _range;
      List<int> bytes = [];
      String ext = excel ? 'xlsx' : 'csv';
      String mime = excel
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'text/csv';

      try {
        bytes = await ref
            .read(apiProvider)
            .exportSales(r.from, r.to, excel: excel);
      } catch (_) {}

      if (bytes.isEmpty) {
        final d = ref.read(reportProvider(r)).valueOrNull ??
            ReportData([], 0, []);
        final csv = _generateSalesCsv(d, r);
        bytes = utf8.encode(csv);
        ext = 'csv';
        mime = 'text/csv';
      }

      final filename = 'sales-${iso(r.from)}-${iso(r.to)}.$ext';
      await FileDownloader.download(
        bytes: bytes,
        filename: filename,
        mimeType: mime,
        shareText: 'Sales Report (${dateShort(r.from)} - ${dateShort(r.to)})',
      );
      if (mounted) toast(context, 'Downloaded $filename');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  Future<void> _exportGstCsv() async {
    try {
      final r = _range;
      final d = ref.read(reportProvider(r)).valueOrNull ??
          ReportData([], 0, []);
      final csv = _generateGstCsv(d, r);
      final bytes = utf8.encode(csv);
      final filename = 'gst-summary-${iso(r.from)}-${iso(r.to)}.csv';
      await FileDownloader.download(
        bytes: bytes,
        filename: filename,
        mimeType: 'text/csv',
        shareText: 'GST Summary (${dateShort(r.from)} - ${dateShort(r.to)})',
      );
      if (mounted) toast(context, 'Downloaded $filename');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  Widget _gstRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
    bool isSub = false,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          color: isSub ? C.muted : C.text,
          fontSize: isSub ? 12 : 13.5,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: color ?? C.text,
          fontSize: isSub ? 12 : 13.5,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    ],
  );

  void _showGstSummary(ReportData? d, ReportRange r) {
    if (d == null) {
      toast(context, 'Report data is loading...');
      return;
    }
    final taxable = (d.sales - d.tax) < 0 ? 0.0 : (d.sales - d.tax);
    final cgst = d.tax / 2;
    final sgst = d.tax / 2;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_outlined, color: C.primary),
            const SizedBox(width: 8),
            const Text('GST Summary'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Period: ${dateShort(r.from)} – ${dateShort(r.to)}',
                style: TextStyle(
                  color: C.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Divider(height: 20),
              _gstRow('Gross sales (incl. tax)', money(d.sales), isBold: true),
              const SizedBox(height: 6),
              _gstRow('Taxable turnover', money(taxable)),
              const SizedBox(height: 6),
              _gstRow(
                'Total GST collected',
                money(d.tax),
                color: C.success,
                isBold: true,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                child: Column(
                  children: [
                    _gstRow('• Central GST (CGST 50%)', money(cgst), isSub: true),
                    const SizedBox(height: 2),
                    _gstRow('• State GST (SGST 50%)', money(sgst), isSub: true),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _gstRow('Discounts given', money(d.discount)),
              const SizedBox(height: 6),
              _gstRow('Total invoices / bills', '${d.bills}'),
              const Divider(height: 20),
              Text(
                'Download invoice-wise GST collection details and tax slabs as CSV for accounting.',
                style: TextStyle(color: C.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _exportGstCsv();
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export GST (CSV)'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
    const labels = ['Today', 'Week', 'Month', '6 Months', 'Year', 'Custom'];
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
              if (i == 5) {
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
                () => _showGstSummary(async.valueOrNull, r),
              ),
              _RepTile(
                Icons.receipt_long_outlined,
                'GST report (CSV)',
                'Download GST data',
                () => _exportGstCsv(),
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
                'Download sales CSV',
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
