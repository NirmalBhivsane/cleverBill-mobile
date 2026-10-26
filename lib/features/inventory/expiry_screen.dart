import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';

final _expiryProvider = FutureProvider.autoDispose
    .family<List<Product>, String>(
      (ref, kind) => ref.watch(apiProvider).expiryList(kind),
    );

class ExpiryScreen extends ConsumerWidget {
  const ExpiryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: C.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Expiry tracking',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        bottom: const TabBar(
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(child: Text('Expiring soon')),
            Tab(child: Text('Expired')),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _List(kind: 'expiring'),
          _List(kind: 'expired'),
        ],
      ),
    ),
  );
}

class _List extends ConsumerWidget {
  const _List({required this.kind});
  final String kind;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncBody<List<Product>>(
    value: ref.watch(_expiryProvider(kind)),
    onRetry: () => ref.invalidate(_expiryProvider(kind)),
    builder: (l) => l.isEmpty
        ? EmptyState(
            icon: Icons.event_available_outlined,
            title: kind == 'expired'
                ? 'Nothing has expired'
                : 'Nothing expiring soon',
            message: 'Add an expiry date on a product to track it here.',
          )
        : RefreshIndicator(
            onRefresh: () async => ref.refresh(_expiryProvider(kind).future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final p in l)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => context.push('/product/${p.id}'),
                      child: Row(
                        children: [
                          AppThumb(url: p.imageUrl, size: 50),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Stock: ${p.stock} ${p.unitLabel}',
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
                              StatusChip(
                                dateShort(p.expiryDate),
                                color: kind == 'expired' ? C.danger : C.warning,
                              ),
                              if (p.expiryDate != null)
                                Text(
                                  _rel(p.expiryDate!),
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 11.5,
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
          ),
  );

  String _rel(DateTime d) {
    final n = d.difference(DateTime.now()).inDays;
    return n < 0 ? '${-n} days ago' : '$n days left';
  }
}
