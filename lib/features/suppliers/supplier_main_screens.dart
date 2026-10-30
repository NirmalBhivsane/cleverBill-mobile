import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../customers/customer_screens.dart' show callNumber, whatsapp;
import '../inventory/inventory_screens.dart'
    show suppliersProvider, purchasesProvider;
import 'supplier_analytics_sheet.dart';
import 'supplier_export.dart';

// ───────────────────────── Providers ─────────────────────────

final supplierPurchasesProvider = FutureProvider.autoDispose
    .family<List<Purchase>, String>(
      (ref, id) async =>
          (await ref.watch(apiProvider).purchases(supplierId: id)).items,
    );

final localSupplierProductsProvider =
    StateProvider.family<List<SupplierProductMapping>, String>((ref, id) => []);

final supplierProductsProvider = FutureProvider.autoDispose
    .family<List<SupplierProductMapping>, String>(
      (ref, supplierId) async {
        List<SupplierProductMapping> list = [];
        try {
          list = await ref.watch(apiProvider).supplierProducts(supplierId);
        } catch (_) {}
        final local = ref.watch(localSupplierProductsProvider(supplierId));
        final seen = <String>{};
        final combined = <SupplierProductMapping>[];
        for (final item in [...list, ...local]) {
          final id =
              item.productId.isNotEmpty ? item.productId : item.productName;
          if (seen.add(id)) combined.add(item);
        }
        return combined;
      },
    );

final supplierBillsProvider = FutureProvider.autoDispose
    .family<List<SupplierBill>, String>(
      (ref, supplierId) async =>
          ref.watch(apiProvider).supplierBills(supplierId),
    );

final localPurchaseReturnsProvider =
    StateProvider<List<PurchaseReturn>>((ref) => []);

final supplierReturnsProvider = FutureProvider.autoDispose
    .family<List<PurchaseReturn>, String>(
      (ref, supplierId) async {
        final apiReturns = await ref
            .watch(apiProvider)
            .purchaseReturns(supplierId: supplierId);
        final local = ref
            .watch(localPurchaseReturnsProvider)
            .where((r) => r.supplierId == supplierId)
            .toList();
        final seen = <String>{};
        final combined = <PurchaseReturn>[];
        for (final r in [...local, ...apiReturns]) {
          final key = r.returnNumber.isNotEmpty ? r.returnNumber : r.id;
          if (key.isNotEmpty && seen.add(key)) {
            combined.add(r);
          } else if (key.isEmpty) {
            combined.add(r);
          }
        }
        return combined;
      },
    );

final supplierLedgerProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String supplierId, DateTime? from, DateTime? to})>(
      (ref, arg) async => ref
          .watch(apiProvider)
          .supplierLedger(arg.supplierId, from: arg.from, to: arg.to),
    );

// ═════════════════════════ Suppliers List & Dashboard ═════════════════════════
class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});
  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersState();
}

class _SuppliersState extends ConsumerState<SuppliersScreen> {
  String _q = '';
  String _stateFilter = 'All';
  String _statusFilter = 'All';
  String _gstinFilter = 'All';
  String _branchFilter = 'All';
  String _outstandingFilter = 'All';

  bool get _hasActiveFilters =>
      _stateFilter != 'All' ||
      _statusFilter != 'All' ||
      _gstinFilter != 'All' ||
      _branchFilter != 'All' ||
      _outstandingFilter != 'All';

  void _resetFilters() {
    setState(() {
      _stateFilter = 'All';
      _statusFilter = 'All';
      _gstinFilter = 'All';
      _branchFilter = 'All';
      _outstandingFilter = 'All';
    });
  }

  void _showAdvancedFilters(List<Supplier> allSuppliers) {
    final availableStates = <String>{
      for (final s in allSuppliers)
        if (s.state.isNotEmpty) s.state,
    }.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Advanced Filters & Export',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // State Filter
                const Text(
                  'State',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _stateFilter,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'All',
                      child: Text('All States'),
                    ),
                    for (final st in availableStates)
                      DropdownMenuItem(value: st, child: Text(st)),
                  ],
                  onChanged: (v) =>
                      setModalState(() => _stateFilter = v ?? 'All'),
                ),
                const SizedBox(height: 12),

                // Status Filter
                const Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Status')),
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'Inactive',
                      child: Text('Inactive'),
                    ),
                  ],
                  onChanged: (v) =>
                      setModalState(() => _statusFilter = v ?? 'All'),
                ),
                const SizedBox(height: 12),

                // GSTIN Filter
                const Text(
                  'GSTIN',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _gstinFilter,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All (GSTIN)')),
                    DropdownMenuItem(
                      value: 'With GSTIN',
                      child: Text('With GSTIN'),
                    ),
                    DropdownMenuItem(
                      value: 'Without GSTIN',
                      child: Text('Without GSTIN'),
                    ),
                  ],
                  onChanged: (v) =>
                      setModalState(() => _gstinFilter = v ?? 'All'),
                ),
                const SizedBox(height: 12),

                // Outstanding Range Filter
                const Text(
                  'Outstanding Payable',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _outstandingFilter,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'All',
                      child: Text('All (Any Balance)'),
                    ),
                    DropdownMenuItem(
                      value: 'Has Outstanding',
                      child: Text('Has Outstanding Payable (> 0)'),
                    ),
                    DropdownMenuItem(
                      value: 'Nil Balance',
                      child: Text('Nil Balance (₹0)'),
                    ),
                  ],
                  onChanged: (v) =>
                      setModalState(() => _outstandingFilter = v ?? 'All'),
                ),
                const SizedBox(height: 20),

                // Actions: Apply & Reset
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setModalState(() {
                            _resetFilters();
                          });
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),

                // Quick Export buttons from Advanced Filters
                const Text(
                  'Export Data',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          SupplierExportHelper.exportSuppliers(
                            context,
                            _filterSuppliers(allSuppliers),
                            excel: true,
                          );
                        },
                        icon: const Icon(
                          Icons.table_chart_outlined,
                          size: 16,
                          color: Color(0xFF107C41),
                        ),
                        label: const Text('Export to Excel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          SupplierExportHelper.exportSuppliers(
                            context,
                            _filterSuppliers(allSuppliers),
                            excel: false,
                          );
                        },
                        icon: const Icon(Icons.file_download_outlined, size: 16),
                        label: const Text('Export to CSV'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Supplier> _filterSuppliers(List<Supplier> all) {
    return all.where((s) {
      // Search text: name, contact, phone, gstin, state, address
      if (_q.isNotEmpty) {
        final matchesName = s.name.toLowerCase().contains(_q);
        final matchesContact = s.contact.toLowerCase().contains(_q);
        final matchesPhone = s.phone.contains(_q);
        final matchesGstin = s.gstin.toLowerCase().contains(_q);
        final matchesAddress = s.address.toLowerCase().contains(_q);
        final matchesState = s.state.toLowerCase().contains(_q);
        if (!matchesName &&
            !matchesContact &&
            !matchesPhone &&
            !matchesGstin &&
            !matchesAddress &&
            !matchesState) {
          return false;
        }
      }

      // State Filter
      if (_stateFilter != 'All' &&
          s.state.toLowerCase() != _stateFilter.toLowerCase()) {
        return false;
      }

      // Status Filter
      if (_statusFilter == 'Active' && !s.active) return false;
      if (_statusFilter == 'Inactive' && s.active) return false;

      // GSTIN Filter
      if (_gstinFilter == 'With GSTIN' && s.gstin.isEmpty) return false;
      if (_gstinFilter == 'Without GSTIN' && s.gstin.isNotEmpty) return false;

      // Outstanding Range Filter
      if (_outstandingFilter == 'Has Outstanding' && s.outstanding <= 0) {
        return false;
      }
      if (_outstandingFilter == 'Nil Balance' && s.outstanding > 0) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> _toggleActive(Supplier s, bool targetActive) async {
    final action = targetActive ? 'activate' : 'deactivate';
    final confirmed = await confirm(
      context,
      '$action supplier?',
      'Are you sure you want to $action "${s.name}"? ${targetActive ? 'The supplier will appear in new purchase orders.' : 'The supplier will be hidden from new purchase orders.'}',
      ok: targetActive ? 'Activate' : 'Deactivate',
      danger: !targetActive,
    );
    if (!confirmed) return;

    try {
      await ref.read(apiProvider).deactivateSupplier(s.id, targetActive);
      ref.invalidate(suppliersProvider);
      if (mounted) {
        toast(
          context,
          targetActive ? 'Supplier activated' : 'Supplier deactivated',
        );
      }
    } catch (_) {
      try {
        await ref.read(apiProvider).saveSupplier({
          'name': s.name,
          'active': targetActive,
          'status': targetActive ? 'ACTIVE' : 'INACTIVE',
        }, id: s.id);
        ref.invalidate(suppliersProvider);
        if (mounted) {
          toast(
            context,
            targetActive ? 'Supplier activated' : 'Supplier deactivated',
          );
        }
      } catch (e) {
        if (mounted) toast(context, '$e', error: true);
      }
    }
  }

  Future<void> _deleteSupplier(Supplier s) async {
    final purchases =
        ref.read(supplierPurchasesProvider(s.id)).valueOrNull ?? [];
    final hasLinkedRecords =
        purchases.isNotEmpty || s.totalPurchases > 0 || s.outstanding > 0;

    if (hasLinkedRecords) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.shield_outlined, color: C.danger),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Deletion Restricted',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            'Supplier "${s.name}" has linked purchase transactions and financial records. '
            'To preserve audit history and ledger integrity, deletion is restricted.\n\n'
            'You can deactivate this supplier instead so they no longer appear in new orders.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: C.warning,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _toggleActive(s, false);
              },
              icon: const Icon(Icons.block_outlined, size: 16),
              label: const Text('Deactivate Supplier'),
            ),
          ],
        ),
      );
      return;
    }

    if (await confirm(
      context,
      'Delete supplier?',
      'Are you sure you want to permanently delete "${s.name}"? This action cannot be undone.',
      ok: 'Delete',
      danger: true,
    )) {
      try {
        await ref.read(apiProvider).deleteSupplier(s.id);
        ref.invalidate(suppliersProvider);
        if (mounted) toast(context, 'Supplier deleted');
      } catch (e) {
        if (mounted) toast(context, '$e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(suppliersProvider);
    final purchasesAsync = ref.watch(purchasesProvider);
    final allPurchases = purchasesAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: blueAppBar(
        context,
        'Suppliers',
        subtitle: 'Manage your suppliers',
        actions: [
          IconButton(
            tooltip: 'Supplier Analytics',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupplierAnalyticsSheet()),
            ),
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: 'RFQs',
            onPressed: () => context.push('/rfqs'),
            icon: const Icon(Icons.request_quote_outlined),
          ),
          IconButton(
            tooltip: 'Add Supplier',
            onPressed: () => context
                .push('/supplier-form')
                .then((_) => ref.invalidate(suppliersProvider)),
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ],
      ),
      body: AsyncBody<List<Supplier>>(
        value: async,
        onRetry: () => ref.invalidate(suppliersProvider),
        builder: (all) {
          final filtered = _filterSuppliers(all);

          // Summary Metrics calculation (Showcase Screen 1)
          final totalSuppliers = all.length;
          final totalPurchasesFromSuppliers = all.fold(
            0.0,
            (a, s) => a + (s.totalPurchases > 0 ? s.totalPurchases : 0.0),
          );
          final totalPurchasesAgg = totalPurchasesFromSuppliers > 0
              ? totalPurchasesFromSuppliers
              : allPurchases
                  .where((p) => !p.cancelled)
                  .fold(0.0, (a, p) => a + p.total);

          final totalPaidFromSuppliers = all.fold(
            0.0,
            (a, s) => a + (s.totalPaid > 0 ? s.totalPaid : 0.0),
          );
          final totalOutstandingFromSuppliers = all.fold(
            0.0,
            (a, s) => a + (s.outstanding > 0 ? s.outstanding : 0.0),
          );

          final distinctStates = <String>{
            for (final s in all)
              if (s.state.isNotEmpty) s.state,
          }.toList()..sort();

          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.refresh(suppliersProvider.future),
                ref.refresh(purchasesProvider.future),
              ]);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                // 4 Summary Metric Cards (Showcase Screen 1)
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
                    const SizedBox(width: 8),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Total Paid',
                        value: money(totalPaidFromSuppliers),
                        icon: Icons.check_circle_outline,
                        color: C.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        label: 'Total Payable',
                        value: money(totalOutstandingFromSuppliers),
                        icon: Icons.account_balance_wallet_outlined,
                        color: C.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Search field
                AppSearchField(
                  hint: 'Search by name, contact or phone...',
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 10),

                // Quick Filters & Export Toolbar
                Row(
                  children: [
                    // States Dropdown
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: C.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: C.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _stateFilter,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: C.text,
                              fontWeight: FontWeight.w600,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'All',
                                child: Text('All States'),
                              ),
                              for (final st in distinctStates)
                                DropdownMenuItem(value: st, child: Text(st)),
                            ],
                            onChanged: (v) =>
                                setState(() => _stateFilter = v ?? 'All'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Status Dropdown
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: C.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: C.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _statusFilter,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: C.text,
                              fontWeight: FontWeight.w600,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'All',
                                child: Text('All Status'),
                              ),
                              DropdownMenuItem(
                                value: 'Active',
                                child: Text('Active'),
                              ),
                              DropdownMenuItem(
                                value: 'Inactive',
                                child: Text('Inactive'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _statusFilter = v ?? 'All'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Advanced Filter Button
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showAdvancedFilters(all),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _hasActiveFilters
                              ? C.primarySoft
                              : C.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _hasActiveFilters ? C.primary : C.border,
                          ),
                        ),
                        child: Icon(
                          Icons.filter_list_rounded,
                          size: 20,
                          color: _hasActiveFilters ? C.primary : C.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Export Menu Button
                    PopupMenuButton<String>(
                      tooltip: 'Export',
                      onSelected: (v) {
                        SupplierExportHelper.exportSuppliers(
                          context,
                          filtered,
                          excel: v == 'excel',
                        );
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'excel',
                          child: Row(
                            children: [
                              Icon(
                                Icons.table_chart_outlined,
                                size: 18,
                                color: Color(0xFF107C41),
                              ),
                              SizedBox(width: 8),
                              Text('Export to Excel'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'csv',
                          child: Row(
                            children: [
                              Icon(Icons.file_download_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Export to CSV'),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: C.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: C.border),
                        ),
                        child: Icon(Icons.share_outlined, size: 20, color: C.text),
                      ),
                    ),
                  ],
                ),

                // Active filter indicator chip
                if (_hasActiveFilters) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: C.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Filtered (${filtered.length} of ${all.length})',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: C.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: _resetFilters,
                              child: Icon(Icons.close, size: 14, color: C.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // Supplier List
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: 'No suppliers found',
                      message: _hasActiveFilters || _q.isNotEmpty
                          ? 'Try adjusting your search or active filters.'
                          : 'Get started by adding your first supplier.',
                      action: _hasActiveFilters || _q.isNotEmpty
                          ? OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _q = '';
                                  _resetFilters();
                                });
                              },
                              child: const Text('Clear Filters'),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => context
                                  .push('/supplier-form')
                                  .then((_) => ref.invalidate(suppliersProvider)),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Supplier'),
                            ),
                    ),
                  ),

                for (var i = 0; i < filtered.length; i++) ...[
                  _SupplierCard(
                    supplier: filtered[i],
                    index: i + 1,
                    onTap: () => context
                        .push('/supplier/${filtered[i].id}', extra: filtered[i])
                        .then((_) => ref.invalidate(suppliersProvider)),
                    onEdit: () => context
                        .push('/supplier-form', extra: filtered[i])
                        .then((_) => ref.invalidate(suppliersProvider)),
                    onToggleActive: () => _toggleActive(
                      filtered[i],
                      !filtered[i].active,
                    ),
                    onDelete: () => _deleteSupplier(filtered[i]),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context
            .push('/supplier-form')
            .then((_) => ref.invalidate(suppliersProvider)),
        icon: const Icon(Icons.add),
        label: const Text('Add Supplier'),
        backgroundColor: C.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ───────────────────────── Supplier List Card ─────────────────────────
class _SupplierCard extends StatelessWidget {
  const _SupplierCard({
    required this.supplier,
    required this.index,
    required this.onTap,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final Supplier supplier;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Avatar(initials(s.name), size: 46),
              const SizedBox(width: 12),

              // Name, contact, location
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        // Status Chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: s.active
                                ? C.success.withOpacity(.12)
                                : Colors.grey.withOpacity(.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            s.status,
                            style: TextStyle(
                              color: s.active ? C.success : C.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (s.contact.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Contact: ${s.contact}',
                          style: TextStyle(color: C.muted, fontSize: 12.5),
                        ),
                      ),
                    if (s.state.isNotEmpty || s.address.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: C.muted,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                s.state.isNotEmpty ? s.state : s.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: C.muted, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // GSTIN & Outstanding row
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (s.gstin.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: C.primarySoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'GSTIN: ${s.gstin}',
                    style: TextStyle(
                      color: C.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Text(
                  'No GSTIN',
                  style: TextStyle(color: C.muted, fontSize: 11.5),
                ),
              if (s.outstanding > 0)
                Text(
                  'Payable: ${money(s.outstanding)}',
                  style: TextStyle(
                    color: C.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                )
              else if (s.totalPurchases > 0)
                Text(
                  'Purchases: ${money(s.totalPurchases)}',
                  style: TextStyle(
                    color: C.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),

          const Divider(height: 20),

          // Bottom Action Row: Call, WhatsApp, Edit, Deactivate/Delete
          Row(
            children: [
              if (s.phone.isNotEmpty) ...[
                InkWell(
                  onTap: () => callNumber(s.phone),
                  child: Row(
                    children: [
                      Icon(Icons.call_outlined, size: 16, color: C.primary),
                      const SizedBox(width: 4),
                      Text(
                        s.phone,
                        style: TextStyle(
                          color: C.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                InkWell(
                  onTap: () => whatsapp(s.phone, 'Hello ${s.name},'),
                  child: const Row(
                    children: [
                      Icon(Icons.chat, size: 16, color: Color(0xFF25D366)),
                      SizedBox(width: 4),
                      Text(
                        'WhatsApp',
                        style: TextStyle(
                          color: Color(0xFF25D366),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit',
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
              ),
              // More Actions menu (Deactivate/Activate, Delete)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (action) {
                  if (action == 'toggle') onToggleActive();
                  if (action == 'delete') onDelete();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          s.active
                              ? Icons.block_outlined
                              : Icons.check_circle_outline,
                          size: 18,
                          color: s.active ? C.warning : C.success,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.active
                              ? 'Deactivate Supplier'
                              : 'Activate Supplier',
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: C.danger),
                        const SizedBox(width: 8),
                        Text(
                          'Delete Supplier',
                          style: TextStyle(color: C.danger),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

