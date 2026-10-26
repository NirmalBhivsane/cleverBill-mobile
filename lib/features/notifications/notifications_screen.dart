import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsState();
}

class _NotificationsState extends ConsumerState<NotificationsScreen> {
  int _tab = 0;

  (IconData, Color) _style(String type) => switch (type) {
    'INVOICE_OVERDUE' => (Icons.description_outlined, C.danger),
    'LOW_STOCK' || 'OUT_OF_STOCK' => (Icons.inventory_2_outlined, C.warning),
    'PARTIAL_PAYMENT' => (Icons.currency_rupee, C.success),
    'PRODUCT_EXPIRY' => (Icons.schedule, C.danger),
    'NEW_ORDER' => (Icons.shopping_bag_outlined, C.primary),
    _ => (Icons.notifications_none, C.primary),
  };

  Future<void> _open(Notif n) async {
    if (!n.read) {
      try {
        await ref.read(apiProvider).markRead(n.id);
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadCountProvider);
      } catch (_) {}
    }
    if (!mounted) return;
    switch (n.type) {
      case 'LOW_STOCK':
      case 'OUT_OF_STOCK':
      case 'PRODUCT_EXPIRY':
        if (n.refId.isNotEmpty) context.push('/product/${n.refId}');
      case 'INVOICE_OVERDUE':
      case 'PARTIAL_PAYMENT':
      case 'NEW_ORDER':
        if (n.refId.isNotEmpty) context.push('/invoice/${n.refId}');
      case 'EXPENSE_ADDED':
      case 'EXPENSE_PENDING_APPROVAL':
        context.push('/expenses');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref.read(apiProvider).markAllRead();
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadCountProvider);
              } catch (e) {
                if (context.mounted) toast(context, '$e', error: true);
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: AsyncBody<List<Notif>>(
        value: async,
        onRetry: () => ref.invalidate(notificationsProvider),
        builder: (all) {
          final unread = all.where((n) => !n.read).toList();
          final l = _tab == 0 ? all : unread;
          final now = DateTime.now();
          bool isToday(Notif n) =>
              n.createdAt != null &&
              n.createdAt!.toLocal().day == now.day &&
              n.createdAt!.toLocal().month == now.month &&
              n.createdAt!.toLocal().year == now.year;
          final today = l.where(isToday).toList();
          final earlier = l.where((n) => !isToday(n)).toList();
          Widget item(Notif n) {
            final s = _style(n.type);
            return InkWell(
              onTap: () => _open(n),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: s.$2.withOpacity(.13),
                      child: Icon(s.$1, color: s.$2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  n.title,
                                  style: TextStyle(
                                    fontWeight: n.read
                                        ? FontWeight.w600
                                        : FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                timeOnly(n.createdAt?.toLocal()),
                                style: TextStyle(
                                  color: C.muted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            n.message,
                            style: TextStyle(color: C.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (!n.read)
                      Padding(
                        padding: EdgeInsets.only(left: 8, top: 6),
                        child: CircleAvatar(
                          radius: 4,
                          backgroundColor: C.danger,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              TabBar(
                onTap: (i) => setState(() => _tab = i),
                controller: null,
                tabs: [
                  Tab(child: Text('All (${all.length})')),
                  Tab(child: Text('Unread (${unread.length})')),
                ],
                labelColor: C.primary,
                indicatorColor: C.primary,
                unselectedLabelColor: C.muted,
              ).wrapController(_tab),
              Expanded(
                child: l.isEmpty
                    ? const EmptyState(
                        icon: Icons.notifications_none,
                        title: 'You’re all caught up',
                        message: 'New alerts will show up here.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.refresh(notificationsProvider.future),
                        child: ListView(
                          children: [
                            if (today.isNotEmpty) ...[
                              _hdr('Today • ${dateShort(now)}'),
                              for (final n in today) item(n),
                            ],
                            if (earlier.isNotEmpty) ...[
                              _hdr('Earlier'),
                              for (final n in earlier) item(n),
                            ],
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

  Widget _hdr(String t) => Container(
    width: double.infinity,
    color: C.bg,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
    child: Text(
      t,
      style: TextStyle(fontWeight: FontWeight.w800, color: C.muted),
    ),
  );
}

extension on TabBar {
  /// Wraps a controller-less TabBar in a DefaultTabController with the right initial index.
  Widget wrapController(int index) => DefaultTabController(
    length: tabs.length,
    initialIndex: index,
    child: this,
  );
}
