import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../home/home_screen.dart';
import '../invoices/invoice_screens.dart' show showProductPicker;

PreferredSizeWidget _shopBar(
  BuildContext context,
  WidgetRef ref, {
  List<Widget>? extra,
}) {
  final s = ref.watch(authProvider).session;
  return AppBar(
    backgroundColor: C.primary,
    foregroundColor: Colors.white,
    toolbarHeight: 64,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Clever Bill',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        Text(
          '${s?.businessName ?? ''} • ${s?.branchName ?? 'Main Branch'}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
    actions: [
      ...?extra,
      const NotificationBell(color: Colors.white),
    ],
  );
}

// ═════════════════════════ Inventory root ═════════════════════════
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: C.primary,
        foregroundColor: Colors.white,
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inventory',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            Text(
              ref.watch(authProvider).session?.businessName ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Expiry',
            onPressed: () => context.push('/expiry'),
            icon: const Icon(Icons.event_busy_outlined),
          ),
          IconButton(
            tooltip: 'Categories',
            onPressed: () => context.push('/categories'),
            icon: const Icon(Icons.category_outlined),
          ),
          if (ref.watch(authProvider).session?.isOwner ?? false)
            IconButton(
              tooltip: 'Purchases',
              onPressed: () => context.push('/purchases'),
              icon: const Icon(Icons.local_shipping_outlined),
            ),
          const NotificationBell(color: Colors.white),
        ],
        bottom: const TabBar(
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(child: Text('Products')),
            Tab(child: Text('Stock')),
          ],
        ),
      ),
      body: const TabBarView(children: [_ProductsTab(), _StockTab()]),
    ),
  );
}

class _ProductsTab extends ConsumerStatefulWidget {
  const _ProductsTab();
  @override
  ConsumerState<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<_ProductsTab> {
  String _q = '';
  int _f = 0;
  int _c = 0; // 0 = all categories, n = categories[n - 1]

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(productsProvider);
    final cats = ref.watch(categoriesProvider).valueOrNull ?? <Category>[];
    final catIdx = _c <= cats.length ? _c : 0;
    return Stack(
      children: [
        AsyncBody<List<Product>>(
          value: async,
          onRetry: () => ref.invalidate(productsProvider),
          builder: (all) {
            final low = all.where((p) => p.isLow || p.isOut).toList();
            final exp = all.where((p) => p.isExpiring).toList();
            var l = _f == 1
                ? low
                : _f == 2
                ? exp
                : all;
            if (catIdx > 0)
              l = l.where((p) => p.categoryId == cats[catIdx - 1].id).toList();
            if (_q.isNotEmpty)
              l = l
                  .where(
                    (p) =>
                        p.name.toLowerCase().contains(_q) ||
                        p.sku.toLowerCase().contains(_q) ||
                        p.barcode.contains(_q),
                  )
                  .toList();
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(productsProvider.future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  Text(
                    '${all.length} products  •  ${low.length} low stock',
                    style: TextStyle(
                      color: C.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppSearchField(
                    hint: 'Search products by name, SKU or barcode',
                    onChanged: (v) =>
                        setState(() => _q = v.trim().toLowerCase()),
                    trailing: InkWell(
                      onTap: () => context.push('/scan'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: C.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          color: C.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilterChips(
                    labels: [
                      'All (${all.length})',
                      'Low stock (${low.length})',
                      'Expiring (${exp.length})',
                    ],
                    selected: _f,
                    onSelect: (i) => setState(() => _f = i),
                  ),
                  if (cats.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    FilterChips(
                      labels: ['All categories', for (final c in cats) c.name],
                      selected: catIdx,
                      onSelect: (i) => setState(() => _c = i),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (l.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No products',
                        message: 'Tap “Add product” to create one.',
                      ),
                    ),
                  for (final p in l)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.all(10),
                        onTap: () => context.push('/product/${p.id}'),
                        child: Row(
                          children: [
                            AppThumb(url: p.imageUrl, size: 58),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15.5,
                                    ),
                                  ),
                                  Text(
                                    '${p.sku.isEmpty ? '—' : p.sku}  |  ${p.category}',
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Stock: ${p.stock} ${p.unitLabel}',
                                        style: const TextStyle(fontSize: 12.5),
                                      ),
                                      if (p.isOut) ...[
                                        const SizedBox(width: 6),
                                        StatusChip(
                                          'Out of stock',
                                          color: C.danger,
                                        ),
                                      ] else if (p.isLow) ...[
                                        const SizedBox(width: 6),
                                        StatusChip(
                                          'Low stock',
                                          color: C.warning,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money(p.price),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'per ${p.unitLabel}',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 11.5,
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
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/product-form'),
            icon: const Icon(Icons.add),
            label: const Text('Add product'),
          ),
        ),
      ],
    );
  }
}

class _StockTab extends ConsumerStatefulWidget {
  const _StockTab();
  @override
  ConsumerState<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends ConsumerState<_StockTab>
    with SingleTickerProviderStateMixin {
  late final TabController _t = TabController(length: 2, vsync: this);
  String _q = '';
  Product? _moveProduct;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(productsProvider);
    return AsyncBody<List<Product>>(
      value: async,
      onRetry: () => ref.invalidate(productsProvider),
      builder: (all) {
        final costValue = all.fold(
          0.0,
          (a, p) => a + p.purchasePrice * p.stock,
        );
        final low = all.where((p) => p.isLow).length;
        final out = all.where((p) => p.isOut).length;
        final exp = all.where((p) => p.isExpiring).length;
        var l = all.where((p) => !p.isService).toList();
        if (_q.isNotEmpty)
          l = l.where((p) => p.name.toLowerCase().contains(_q)).toList();
        l.sort(
          (a, b) =>
              (a.isOut
                      ? 0
                      : a.isLow
                      ? 1
                      : 2)
                  .compareTo(
                    b.isOut
                        ? 0
                        : b.isLow
                        ? 1
                        : 2,
                  ),
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stock cost value',
                                style: TextStyle(color: C.muted),
                              ),
                              Text(
                                money(costValue),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total items',
                              style: TextStyle(color: C.muted),
                            ),
                            Text(
                              '${all.length}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'Low stock',
                          value: '$low',
                          color: C.warning,
                          icon: Icons.error_outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatTile(
                          label: 'Out of stock',
                          value: '$out',
                          color: C.danger,
                          icon: Icons.cancel_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatTile(
                          label: 'Expiring',
                          value: '$exp',
                          color: C.primary,
                          icon: Icons.schedule,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _t,
              tabs: const [
                Tab(child: Text('Levels')),
                Tab(child: Text('Movements')),
              ],
              labelColor: C.primary,
              indicatorColor: C.primary,
              unselectedLabelColor: C.muted,
            ),
            Expanded(
              child: TabBarView(
                controller: _t,
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AppSearchField(
                        hint: 'Search items (e.g. milk, rice)',
                        onChanged: (v) =>
                            setState(() => _q = v.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 10),
                      for (final p in l)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () =>
                                context.push('/adjust-stock', extra: p),
                            child: Row(
                              children: [
                                AppThumb(url: p.imageUrl, size: 50),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '${p.stock} ${p.unitLabel}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              color: p.isOut
                                                  ? C.danger
                                                  : p.isLow
                                                  ? C.warning
                                                  : C.success,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (p.isOut)
                                            StatusChip(
                                              'Out of stock',
                                              color: C.danger,
                                            )
                                          else if (p.isLow)
                                            StatusChip(
                                              'Low stock',
                                              color: C.warning,
                                            )
                                          else
                                            StatusChip(
                                              'In stock',
                                              color: C.success,
                                            ),
                                        ],
                                      ),
                                      Text(
                                        'Min stock: ${p.lowStockThreshold} ${p.unitLabel}',
                                        style: TextStyle(
                                          color: C.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if ((p.isLow || p.isOut) &&
                                    (ref.watch(authProvider).session?.isOwner ??
                                        false))
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(80, 38),
                                    ),
                                    onPressed: () => context.push(
                                      '/purchase-form',
                                      extra: p,
                                    ),
                                    child: const Text('Reorder'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  _MovementsView(
                    product: _moveProduct,
                    onPick: (p) => setState(() => _moveProduct = p),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MovementsView extends ConsumerWidget {
  const _MovementsView({required this.product, required this.onPick});
  final Product? product;
  final ValueChanged<Product> onPick;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      OutlinedButton.icon(
        onPressed: () async {
          final p = await showProductPicker(context, ref);
          if (p != null) onPick(p);
        },
        icon: const Icon(Icons.search),
        label: Text(product?.name ?? 'Select a product to view movements'),
      ),
      const SizedBox(height: 10),
      if (product != null) MovementList(productId: product!.id),
    ],
  );
}

final movementsProvider = FutureProvider.autoDispose
    .family<List<StockMovement>, String>(
      (ref, id) async => (await ref.watch(apiProvider).movements(id)).items,
    );

class MovementList extends ConsumerWidget {
  const MovementList({super.key, required this.productId, this.limit});
  final String productId;
  final int? limit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(movementsProvider(productId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('$e'),
      data: (l) {
        if (l.isEmpty)
          return Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                'No stock movements yet',
                style: TextStyle(color: C.muted),
              ),
            ),
          );
        final list = limit == null ? l : l.take(limit!).toList();
        return Column(
          children: [
            for (final m in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: m.change >= 0
                            ? C.successSoft
                            : C.dangerSoft,
                        child: Icon(
                          m.change >= 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: m.change >= 0 ? C.success : C.danger,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.type[0] + m.type.substring(1).toLowerCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              dateTime12(m.at),
                              style: TextStyle(color: C.muted, fontSize: 12),
                            ),
                            if (m.note.isNotEmpty)
                              Text(
                                m.note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: C.muted, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${m.change > 0 ? '+' : ''}${m.change}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: m.change >= 0 ? C.success : C.danger,
                            ),
                          ),
                          Text(
                            '${m.before} → ${m.after}',
                            style: TextStyle(color: C.muted, fontSize: 11.5),
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
    );
  }
}

// ═════════════════════════ Product detail ═════════════════════════
final productDetailProvider = FutureProvider.autoDispose
    .family<Product, String>((ref, id) => ref.watch(apiProvider).product(id));

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productDetailProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                if (await confirm(
                  context,
                  'Delete product?',
                  'This will remove the product from your catalogue.',
                  ok: 'Delete',
                  danger: true,
                )) {
                  try {
                    await ref.read(apiProvider).deleteProduct(id);
                    ref.invalidate(productsProvider);
                    if (context.mounted) context.pop();
                  } catch (e) {
                    if (context.mounted) toast(context, '$e', error: true);
                  }
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete product',
                  style: TextStyle(color: C.danger),
                ),
              ),
            ],
          ),
        ],
      ),
      body: AsyncBody<Product>(
        value: async,
        onRetry: () => ref.invalidate(productDetailProvider(id)),
        builder: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      AppThumb(url: p.imageUrl, size: 72),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (p.category.isNotEmpty)
                              StatusChip(p.category, color: C.primary),
                            Text(
                              'SKU: ${p.sku.isEmpty ? '—' : p.sku}',
                              style: TextStyle(color: C.muted),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(84, 38),
                        ),
                        onPressed: () =>
                            context.push('/product-form', extra: p).then((_) {
                              ref.invalidate(productDetailProvider(id));
                            }),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                    ],
                  ),
                  const Divider(height: 26),
                  Row(
                    children: [
                      _Cell(
                        money(p.price),
                        'Selling price\nper ${p.unitLabel}',
                      ),
                      _Cell(
                        money(p.purchasePrice),
                        'Purchase cost\nper ${p.unitLabel}',
                      ),
                      _Cell(
                        '${p.stock} ${p.unitLabel}',
                        'In stock',
                        color: p.isOut ? C.danger : C.success,
                      ),
                      _Cell(
                        '${p.lowStockThreshold} ${p.unitLabel}',
                        'Low stock\nthreshold',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/adjust-stock', extra: p),
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Adjust stock'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SizedBox(
                        height: MediaQuery.of(context).size.height * .7,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                              'Stock history — ${p.name}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            MovementList(productId: p.id),
                          ],
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.history),
                    label: const Text('Stock history'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product information',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _Info('Category', p.category.isEmpty ? '—' : p.category),
                  _Info('Unit', p.unitLabel),
                  _InfoCopy('Barcode', p.barcode),
                  _Info('GST', '${p.taxPercent.toStringAsFixed(0)}%'),
                  _Info('Stock tracking', p.isService ? 'Disabled' : 'Enabled'),
                  if (p.expiryDate != null)
                    _Info('Expiry', dateShort(p.expiryDate)),
                ],
              ),
            ),
            const SectionTitle('Recent stock movements'),
            MovementList(productId: p.id, limit: 5),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.v, this.l, {this.color});
  final String v, l;
  final Color? color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        FittedBox(
          child: Text(
            v,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: color,
            ),
          ),
        ),
        Text(
          l,
          textAlign: TextAlign.center,
          style: TextStyle(color: C.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info(this.a, this.b);
  final String a, b;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(a, style: TextStyle(color: C.muted)),
        ),
        Expanded(
          child: Text(b, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

class _InfoCopy extends StatelessWidget {
  const _InfoCopy(this.a, this.b);
  final String a, b;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(a, style: TextStyle(color: C.muted)),
        ),
        Expanded(
          child: Text(
            b.isEmpty ? '—' : b,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (b.isNotEmpty)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: b));
              toast(context, 'Copied');
            },
            icon: const Icon(Icons.copy, size: 18),
          ),
      ],
    ),
  );
}

// ═════════════════════════ Product form ═════════════════════════
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});
  final Product? product;
  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductFormScreen> {
  late final _name = TextEditingController(text: widget.product?.name);
  late final _barcode = TextEditingController(text: widget.product?.barcode);
  late final _sku = TextEditingController(text: widget.product?.sku);
  late final _buy = TextEditingController(
    text: widget.product == null ? '' : '${widget.product!.purchasePrice}',
  );
  late final _sell = TextEditingController(
    text: widget.product == null ? '' : '${widget.product!.price}',
  );
  late final _stock = TextEditingController(
    text: widget.product == null ? '0' : '${widget.product!.stock}',
  );
  late final _low = TextEditingController(
    text: widget.product == null
        ? '10'
        : '${widget.product!.lowStockThreshold}',
  );
  String? _categoryId;
  late String _unit = widget.product?.unit ?? 'PCS';
  late String _gst = _slabOf(widget.product?.taxPercent ?? 0);
  late bool _track = !(widget.product?.isService ?? false);
  DateTime? _expiry;
  String? _imagePath;
  List<int>? _imageBytes;
  String? _imageName;
  bool _busy = false;
  static const units = [
    'PCS',
    'KG',
    'LTR',
    'MTR',
    'BOX',
    'DOZEN',
    'BUNDLE',
    'PAIR',
  ];
  static const slabs = {
    'ZERO': 0.0,
    'FIVE': 5.0,
    'TWELVE': 12.0,
    'EIGHTEEN': 18.0,
    'TWENTY_EIGHT': 28.0,
  };

  static String _slabOf(double t) => slabs.entries
      .firstWhere((e) => e.value == t, orElse: () => const MapEntry('ZERO', 0))
      .key;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.product?.categoryId;
    _expiry = widget.product?.expiryDate;
  }

  Future<void> _pick(ImageSource s) async {
    final x = await ImagePicker().pickImage(
      source: s,
      maxWidth: 1000,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (x != null) {
      final b = await x.readAsBytes();
      setState(() {
        _imagePath = x.path;
        _imageBytes = b;
        _imageName = x.name;
      });
    }
  }

  Future<void> _save() async {
    final sell = double.tryParse(_sell.text),
        buy = double.tryParse(_buy.text) ?? 0;
    if (_name.text.trim().isEmpty)
      return toast(context, 'Enter product name', error: true);
    if (sell == null) return toast(context, 'Enter selling price', error: true);
    if (sell < buy)
      return toast(
        context,
        'Selling price cannot be below purchase price',
        error: true,
      );
    setState(() => _busy = true);
    final api = ref.read(apiProvider);
    try {
      String? img = widget.product?.imageUrl;
      if (_imageBytes != null && _imageBytes!.isNotEmpty)
        img = await api.uploadProductImage(
          _imagePath,
          bytes: _imageBytes,
          filename: _imageName,
        ) ?? img;
      final isGst = ref.read(authProvider).isGst;
      await api.saveProduct({
        'name': _name.text.trim(),
        'barcode': _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        'sku': _sku.text.trim().isEmpty ? null : _sku.text.trim(),
        'price': sell,
        'purchasePrice': buy,
        'stock': int.tryParse(_stock.text) ?? 0,
        'lowStockThreshold': int.tryParse(_low.text) ?? 10,
        'unit': _unit,
        'categoryId': _categoryId,
        'isService': !_track,
        'active': true,
        'imageUrl': img,
        if (isGst) ...{'gstSlab': _gst, 'taxPercent': slabs[_gst]},
        if (_expiry != null) 'expiryDate': iso(_expiry!),
      }, id: widget.product?.id);
      ref.invalidate(productsProvider);
      ref.invalidate(categoriesProvider);
      if (mounted) {
        toast(context, 'Product saved');
        context.pop();
      }
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Create a category without leaving the product form and select it.
  Future<void> _quickAddCategory() async {
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: tr('e.g. Beverages')),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final api = ref.read(apiProvider);
      final existing = await api.categories();
      final dup = existing.where(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
      if (dup.isEmpty) {
        await api.saveCategory({
          'name': name,
          'defaultGstPercent': 0,
          'active': true,
        });
      }
      ref.invalidate(categoriesProvider);
      final fresh = await api.categories();
      final hit = fresh.where(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
      if (hit.isNotEmpty && mounted) {
        setState(() => _categoryId = hit.first.id);
        toast(context, 'Category added');
      }
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).valueOrNull ?? <Category>[];
    final catValue = cats.any((c) => c.id == _categoryId) ? _categoryId : null;
    final unitItems = [...units, if (!units.contains(_unit)) _unit];
    final isGst = ref.watch(authProvider).isGst;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add product' : 'Edit product'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: C.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _imageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            Uint8List.fromList(_imageBytes!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : AppThumb(
                          url: widget.product?.imageUrl,
                          size: 84,
                          icon: Icons.image_outlined,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add product photo',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Take a photo or choose from gallery',
                        style: TextStyle(color: C.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 38),
                              ),
                              onPressed: () => _pick(ImageSource.camera),
                              icon: const Icon(
                                Icons.photo_camera_outlined,
                                size: 18,
                              ),
                              label: const Text('Take'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 38),
                              ),
                              onPressed: () => _pick(ImageSource.gallery),
                              icon: const Icon(Icons.photo_outlined, size: 18),
                              label: const Text('Choose'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Product name',
            controller: _name,
            hint: 'e.g. Basmati Rice',
            required: true,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Barcode',
                  controller: _barcode,
                  hint: 'Scan or enter barcode',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 14),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(90, 50),
                  ),
                  onPressed: () async {
                    final code = await context.push<String>(
                      '/scan',
                      extra: 'form',
                    );
                    if (code != null) setState(() => _barcode.text = code);
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan'),
                ),
              ),
            ],
          ),
          LabeledField(
            label: 'SKU (optional)',
            controller: _sku,
            hint: 'e.g. RICE-001',
          ),
          Row(
            children: [
              Expanded(
                child: _drop<String?>('Category', catValue, [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Select category'),
                  ),
                  for (final c in cats)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ], (v) => setState(() => _categoryId = v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _drop<String>('Unit', _unit, [
                  for (final u in unitItems)
                    DropdownMenuItem(value: u, child: Text(u.toLowerCase())),
                ], (v) => setState(() => _unit = v ?? 'PCS')),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _quickAddCategory,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('New category'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Purchase price (₹)',
                  controller: _buy,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  hint: 'e.g. 55.00',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'Selling price (₹)',
                  controller: _sell,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  hint: 'e.g. 70.00',
                  required: true,
                ),
              ),
            ],
          ),
          if (isGst)
            _drop<String>('GST rate', _gst, [
              for (final e in slabs.entries)
                DropdownMenuItem(
                  value: e.key,
                  child: Text('${e.value.toStringAsFixed(0)}%'),
                ),
            ], (v) => setState(() => _gst = v ?? 'ZERO')),
          if (isGst) const SizedBox(height: 14),
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _track,
              onChanged: (v) => setState(() => _track = v),
              title: const Text(
                'Track stock for this product',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Keep track of quantity in stock'),
            ),
          ),
          const SizedBox(height: 14),
          if (_track)
            Row(
              children: [
                Expanded(
                  child: LabeledField(
                    label: widget.product == null ? 'Opening stock' : 'Stock',
                    controller: _stock,
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LabeledField(
                    label: 'Low stock alert at',
                    controller: _low,
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ),
          InkWell(
            onTap: () async {
              final d = await pickDate(
                context,
                initial: _expiry,
                first: DateTime.now(),
              );
              if (d != null) setState(() => _expiry = d);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: tr('Expiry date (optional)'),
                prefixIcon: const Icon(Icons.event_outlined),
                suffixIcon: _expiry == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _expiry = null),
                      ),
              ),
              child: Text(_expiry == null ? 'Not set' : dateShort(_expiry)),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton('Save product', loading: _busy, onPressed: _save),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drop<T>(
    String label,
    T value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
        ),
      ],
    ),
  );
}

// ═════════════════════════ Categories ═════════════════════════
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, Category? c) async {
    final name = TextEditingController(text: c?.name);
    var gst = c?.gst ?? 0;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c == null ? 'Add category' : 'Category details',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              LabeledField(label: 'Name', controller: name, required: true),
              const Text(
                'Default GST rate (optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<double>(
                value: const [0.0, 5.0, 12.0, 18.0, 28.0].contains(gst)
                    ? gst
                    : 0,
                items: [
                  for (final g in const [0.0, 5.0, 12.0, 18.0, 28.0])
                    DropdownMenuItem(
                      value: g,
                      child: Text('${g.toStringAsFixed(0)}%'),
                    ),
                ],
                onChanged: (v) => set(() => gst = v ?? 0),
              ),
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Applied to products in this category only when using GST mode.',
                  style: TextStyle(color: C.muted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                'Save category',
                onPressed: () async {
                  if (name.text.trim().isEmpty)
                    return toast(ctx, 'Enter category name', error: true);
                  try {
                    await ref.read(apiProvider).saveCategory({
                      'name': name.text.trim(),
                      'defaultGstPercent': gst,
                      'active': true,
                    }, id: c?.id);
                    ref.invalidate(categoriesProvider);
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
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    final products = ref.watch(productsProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: AsyncBody<List<Category>>(
        value: cats,
        onRetry: () => ref.invalidate(categoriesProvider),
        builder: (l) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (l.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: EmptyState(
                  icon: Icons.category_outlined,
                  title: 'No categories yet',
                ),
              ),
            for (final c in l)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: C.primarySoft,
                        child: Icon(Icons.category_outlined, color: C.primary),
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
                              '${products.where((p) => p.categoryId == c.id).length} products',
                              style: TextStyle(color: C.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _edit(context, ref, c),
                        icon: Icon(Icons.edit_outlined, color: C.primary),
                      ),
                      IconButton(
                        onPressed: () async {
                          if (await confirm(
                            context,
                            'Delete category?',
                            'Products in it will become uncategorised.',
                            ok: 'Delete',
                            danger: true,
                          )) {
                            try {
                              await ref.read(apiProvider).deleteCategory(c.id);
                              ref.invalidate(categoriesProvider);
                            } catch (e) {
                              if (context.mounted)
                                toast(context, '$e', error: true);
                            }
                          }
                        },
                        icon: Icon(Icons.delete_outline, color: C.danger),
                      ),
                    ],
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add category'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════ Adjust stock ═════════════════════════
class AdjustStockScreen extends ConsumerStatefulWidget {
  const AdjustStockScreen({super.key, required this.product});
  final Product product;
  @override
  ConsumerState<AdjustStockScreen> createState() => _AdjustState();
}

class _AdjustState extends ConsumerState<AdjustStockScreen> {
  bool _add = true;
  int _qty = 0;
  String _reason = 'Purchase correction';
  final _note = TextEditingController();
  final _custom = TextEditingController();
  bool _busy = false;
  static const reasons = {
    'Purchase correction': 'CORRECTION',
    'Manual count': 'MANUAL',
    'Damaged / expired': 'DAMAGE',
    'Other': 'MANUAL',
  };

  Future<void> _save() async {
    if (_qty <= 0) return toast(context, 'Enter a quantity', error: true);
    if (_note.text.trim().isEmpty)
      return toast(context, 'Please add a note', error: true);
    final p = widget.product;
    if (!_add && _qty > p.stock)
      return toast(
        context,
        'Cannot remove more than current stock',
        error: true,
      );
    setState(() => _busy = true);
    try {
      await ref
          .read(apiProvider)
          .adjustStock(
            p.id,
            _add ? _qty : -_qty,
            reasons[_reason]!,
            '$_reason: ${_note.text.trim()}',
          );
      ref.invalidate(productsProvider);
      ref.invalidate(movementsProvider(p.id));
      ref.invalidate(productDetailProvider(p.id));
      if (mounted) {
        toast(context, 'Stock updated');
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
    final p = widget.product;
    final result = _add ? p.stock + _qty : p.stock - _qty;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adjust Stock'),
            Text(
              ref.watch(authProvider).session?.businessName ?? '',
              style: TextStyle(
                fontSize: 12,
                color: C.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    AppThumb(url: p.imageUrl, size: 54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      money(p.price),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const Divider(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current stock',
                            style: TextStyle(color: C.muted),
                          ),
                          Text(
                            '${p.stock} ${p.unitLabel}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: p.isLow || p.isOut ? C.warning : C.success,
                            ),
                          ),
                          Text(
                            'Min stock: ${p.lowStockThreshold} ${p.unitLabel}',
                            style: TextStyle(color: C.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Adjustment type',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _toggle(true, Icons.add_circle_outline, 'Add to stock'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _toggle(
                  false,
                  Icons.remove_circle_outline,
                  'Remove from stock',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Quantity to ${_add ? 'add' : 'remove'}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final q in const [6, 12, 24, 50])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Center(child: Text('$q')),
                      selected: _qty == q && _custom.text.isEmpty,
                      onSelected: (_) => setState(() {
                        _qty = q;
                        _custom.clear();
                      }),
                      showCheckmark: false,
                    ),
                  ),
                ),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _custom,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: tr('Custom'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) =>
                        setState(() => _qty = int.tryParse(v) ?? 0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: result < 0 ? C.dangerSoft : C.successSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resulting stock',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$result ${p.unitLabel}',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: result < 0 ? C.danger : C.success,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '(${p.stock} ${_add ? '+' : '−'} $_qty)',
                  style: TextStyle(color: C.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Reason for adjustment',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _reason,
            items: [
              for (final r in reasons.keys)
                DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: (v) => setState(() => _reason = v ?? _reason),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Note (required)',
            controller: _note,
            maxLines: 3,
            maxLength: 200,
            hint: 'e.g. Stock received as per purchase invoice',
          ),
          PrimaryButton('Save adjustment', loading: _busy, onPressed: _save),
        ],
      ),
    );
  }

  Widget _toggle(bool add, IconData icon, String label) {
    final sel = _add == add;
    return InkWell(
      onTap: () => setState(() => _add = add),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? C.primarySoft : C.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? C.primary : C.border,
            width: sel ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: sel ? C.primary : C.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: sel ? C.primary : C.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════ Purchases ═════════════════════════
final purchasesProvider = FutureProvider.autoDispose<List<Purchase>>(
  (ref) async => (await ref.watch(apiProvider).purchases()).items,
);
final suppliersProvider = FutureProvider.autoDispose<List<Supplier>>(
  (ref) async => (await ref.watch(apiProvider).suppliers()).items,
);

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});
  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesState();
}

class _PurchasesState extends ConsumerState<PurchasesScreen> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(purchasesProvider);
    return Scaffold(
      appBar: blueAppBar(
        context,
        'Purchases',
        subtitle: 'Track your stock purchases',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context
            .push('/purchase-form')
            .then((_) => ref.invalidate(purchasesProvider)),
        icon: const Icon(Icons.add),
        label: const Text('New purchase'),
        backgroundColor: C.primary,
        foregroundColor: Colors.white,
      ),
      body: AsyncBody<List<Purchase>>(
        value: async,
        onRetry: () => ref.invalidate(purchasesProvider),
        builder: (all) {
          final l = all
              .where(
                (p) =>
                    p.supplierName.toLowerCase().contains(_q) ||
                    p.number.toLowerCase().contains(_q),
              )
              .toList();
          final total = all
              .where((p) => !p.cancelled)
              .fold(0.0, (a, p) => a + p.total);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              AppSearchField(
                hint: 'Search supplier or invoice number',
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
              StatTile(
                label: 'Total purchases',
                value: money(total),
                sub: '${all.length} purchases',
                icon: Icons.shopping_cart_outlined,
              ),
              const SizedBox(height: 12),
              if (l.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No purchases yet',
                  ),
                ),
              for (final p in l)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    onTap: () async {
                      final full = await ref.read(apiProvider).purchase(p.id);
                      if (!context.mounted) return;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: C.card,
                        builder: (ctx) => _PurchaseSheet(
                          p: full,
                          onCancel: () async {
                            if (await confirm(
                              ctx,
                              'Cancel purchase?',
                              'Stock added by this purchase will be reversed.',
                              ok: 'Cancel purchase',
                              danger: true,
                            )) {
                              try {
                                await ref
                                    .read(apiProvider)
                                    .cancelPurchase(p.id);
                                ref.invalidate(purchasesProvider);
                                ref.invalidate(productsProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (ctx.mounted) toast(ctx, '$e', error: true);
                              }
                            }
                          },
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: C.primarySoft,
                          child: Icon(
                            Icons.local_shipping_outlined,
                            color: C.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.supplierName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '#${p.number}  •  ${dateShort(p.date)}',
                                style: TextStyle(color: C.muted, fontSize: 12),
                              ),
                              Text(
                                '${p.items.length} items  •  ${money(p.total)}',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusChip.forStatus(
                              p.cancelled ? 'Cancelled' : 'Received',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.mode,
                              style: TextStyle(color: C.muted, fontSize: 11.5),
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

class _PurchaseSheet extends StatelessWidget {
  const _PurchaseSheet({required this.p, required this.onCancel});
  final Purchase p;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Purchase #${p.number}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            '${p.supplierName} • ${dateShort(p.date)}',
            style: TextStyle(color: C.muted),
          ),
          const Divider(height: 24),
          for (final i in p.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(i.name)),
                  Text(
                    '${i.qty} × ${money(i.rate)}  ',
                    style: TextStyle(color: C.muted),
                  ),
                  Text(
                    money(i.total),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                money(p.total),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          if (!p.cancelled) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: C.danger,
                side: BorderSide(color: C.danger),
              ),
              child: const Text('Cancel purchase'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _PLine {
  _PLine(this.p)
    : rate = TextEditingController(text: '${p.purchasePrice}'),
      qty = TextEditingController(text: '1');
  final Product p;
  final TextEditingController rate, qty;
  double get total =>
      (double.tryParse(rate.text) ?? 0) * (int.tryParse(qty.text) ?? 0);
}

class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key, this.preset});
  final Product? preset;
  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends ConsumerState<PurchaseFormScreen> {
  String? _supplierId;
  final _ref = TextEditingController();
  DateTime _date = DateTime.now();
  final List<_PLine> _lines = [];
  String _mode = 'CASH';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.preset != null) _lines.add(_PLine(widget.preset!));
  }

  double get _total => _lines.fold(0.0, (a, l) => a + l.total);

  Future<void> _save() async {
    if (_supplierId == null)
      return toast(context, 'Select a supplier', error: true);
    if (_lines.isEmpty)
      return toast(context, 'Add at least one item', error: true);
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).createPurchase({
        'supplierId': _supplierId,
        'paymentMode': _mode,
        'purchaseDate': iso(_date),
        'note': _ref.text.trim().isEmpty ? null : 'Ref: ${_ref.text.trim()}',
        'items': [
          for (final l in _lines)
            {
              'productId': l.p.id,
              'quantity': int.tryParse(l.qty.text) ?? 0,
              'purchasePrice': double.tryParse(l.rate.text) ?? 0,
              'totalAmount': l.total,
            },
        ],
      });
      ref.invalidate(productsProvider);
      ref.invalidate(purchasesProvider);
      if (mounted) {
        toast(context, 'Stock received');
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
    final sup = ref.watch(suppliersProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: blueAppBar(
        context,
        'New Purchase',
        subtitle: ref.watch(authProvider).session?.businessName,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Supplier *',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _supplierId,
            hint: const Text('Select supplier'),
            items: [
              for (final s in sup)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _supplierId = v),
          ),
          TextButton.icon(
            onPressed: () => context
                .push('/supplier-form')
                .then((_) => ref.invalidate(suppliersProvider)),
            icon: const Icon(Icons.add),
            label: const Text('Add new supplier'),
          ),
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Invoice reference',
                  controller: _ref,
                  hint: 'e.g. FD-2658',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Purchase date',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final d = await pickDate(context, initial: _date);
                          if (d != null) setState(() => _date = d);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            suffixIcon: Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                            ),
                          ),
                          child: Text(dateShort(_date)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Text(
            'Items',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          for (final l in _lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        AppThumb(url: l.p.imageUrl, size: 40),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.p.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _lines.remove(l)),
                          icon: Icon(Icons.delete_outline, color: C.danger),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: l.qty,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Quantity (${l.p.unitLabel})',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: l.rate,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: tr('Rate (₹)'),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: tr('Amount'),
                              isDense: true,
                            ),
                            child: Text(
                              money(l.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () async {
              final p = await showProductPicker(context, ref);
              if (p != null) setState(() => _lines.add(_PLine(p)));
            },
            icon: const Icon(Icons.add),
            label: const Text('Add another item'),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total amount',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  money(_total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Payment method',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _mode,
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
              DropdownMenuItem(value: 'UPI', child: Text('UPI')),
              DropdownMenuItem(value: 'CARD', child: Text('Card')),
              DropdownMenuItem(
                value: 'CREDIT',
                child: Text('Credit (pay later)'),
              ),
            ],
            onChanged: (v) => setState(() => _mode = v ?? 'CASH'),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            'Receive stock & save',
            loading: _busy,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
