import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../inventory/inventory_screens.dart'
    show suppliersProvider, purchasesProvider;

class SupplierAnalyticsSheet extends ConsumerWidget {
  const SupplierAnalyticsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supList = ref.watch(suppliersProvider).valueOrNull ?? [];
    final purchaseList = ref.watch(purchasesProvider).valueOrNull ?? [];

    // Aggregate purchase amounts per supplier
    final Map<String, double> supplierPurchases = {};
    for (final s in supList) {
      supplierPurchases[s.name] = s.totalPurchases;
    }
    // Also include from purchasesProvider if supplier models had zero
    for (final p in purchaseList) {
      if (!p.cancelled && p.supplierName.isNotEmpty) {
        supplierPurchases[p.supplierName] =
            (supplierPurchases[p.supplierName] ?? 0.0) + p.total;
      }
    }

    final totalSuppliers = supList.length;
    final totalPurchases = supList.fold(
      0.0,
      (a, s) => a + (s.totalPurchases > 0 ? s.totalPurchases : 0.0),
    );
    final totalPurchasesAgg = totalPurchases > 0
        ? totalPurchases
        : purchaseList
            .where((p) => !p.cancelled)
            .fold(0.0, (a, p) => a + p.total);

    final totalPaid = supList.fold(
      0.0,
      (a, s) => a + (s.totalPaid > 0 ? s.totalPaid : 0.0),
    );
    final totalOutstanding = supList.fold(
      0.0,
      (a, s) => a + (s.outstanding > 0 ? s.outstanding : 0.0),
    );

    // Sort suppliers by purchase amount descending
    final sortedSuppliers = supplierPurchases.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSuppliers = sortedSuppliers.take(5).toList();

    final palette = [
      const Color(0xFF2A4FE0),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFF6B7280),
    ];

    return Scaffold(
      appBar: blueAppBar(
        context,
        'Supplier Analytics',
        subtitle: 'Insights & Purchase Breakdown',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 4 Summary Metrics
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Total Suppliers',
                  value: '$totalSuppliers',
                  icon: Icons.groups_outlined,
                  color: C.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Total Purchases',
                  value: money(totalPurchasesAgg),
                  icon: Icons.shopping_bag_outlined,
                  color: C.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Total Paid',
                  value: money(totalPaid),
                  icon: Icons.check_circle_outline,
                  color: C.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Outstanding',
                  value: money(totalOutstanding),
                  icon: Icons.account_balance_wallet_outlined,
                  color: C.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Top Suppliers by Purchase Amount
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Top Suppliers by Purchase Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Icon(Icons.bar_chart_rounded, color: C.primary),
                  ],
                ),
                const SizedBox(height: 16),
                if (topSuppliers.isEmpty ||
                    topSuppliers.every((e) => e.value <= 0))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No purchase data to display yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (var i = 0; i < topSuppliers.length; i++) ...[
                        Row(
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text(
                                topSuppliers[i].key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: topSuppliers.first.value > 0
                                      ? (topSuppliers[i].value /
                                              topSuppliers.first.value)
                                          .clamp(0.05, 1.0)
                                      : 0,
                                  minHeight: 12,
                                  backgroundColor: C.primarySoft,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    palette[i % palette.length],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: Text(
                                money(topSuppliers[i].value),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (i < topSuppliers.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Supplier-wise Purchase Share
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Supplier-wise Purchase Share',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Icon(Icons.pie_chart_outline_rounded, color: C.primary),
                  ],
                ),
                const SizedBox(height: 16),
                if (topSuppliers.isEmpty ||
                    topSuppliers.every((e) => e.value <= 0))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No purchase share data available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      // Donut Chart
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 36,
                            sections: [
                              for (var i = 0; i < topSuppliers.length; i++)
                                PieChartSectionData(
                                  color: palette[i % palette.length],
                                  value: topSuppliers[i].value > 0
                                      ? topSuppliers[i].value
                                      : 1,
                                  title: '',
                                  radius: 28,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Legend
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < topSuppliers.length; i++) ...[
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: palette[i % palette.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      topSuppliers[i].key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Text(
                                    totalPurchasesAgg > 0
                                        ? '${((topSuppliers[i].value / totalPurchasesAgg) * 100).toStringAsFixed(0)}%'
                                        : '0%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              if (i < topSuppliers.length - 1)
                                const SizedBox(height: 6),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

