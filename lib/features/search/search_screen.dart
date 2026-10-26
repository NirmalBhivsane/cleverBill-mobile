import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/widgets.dart';
import '../../providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchState();
}

class _SearchState extends ConsumerState<SearchScreen> {
  final _c = TextEditingController();
  Timer? _t;
  Map<String, dynamic>? _res;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _t?.cancel();
    if (v.trim().length < 2)
      return setState(() {
        _res = null;
        _err = null;
      });
    _t = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _busy = true);
      try {
        final r = await ref.read(apiProvider).globalSearch(v.trim());
        if (mounted)
          setState(() {
            _res = r;
            _err = null;
          });
      } catch (e) {
        if (mounted) setState(() => _err = '$e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _res;
    List<Map<String, dynamic>> l(String k) => jlist(r?[k], (m) => m);
    final products = l('products'),
        customers = l('customers'),
        invoices = l('invoices'),
        expenses = l('expenses'),
        cats = l('categories');
    final empty =
        r != null &&
        products.isEmpty &&
        customers.isEmpty &&
        invoices.isEmpty &&
        expenses.isEmpty &&
        cats.isEmpty;
    Widget group(
      String title,
      IconData icon,
      List<Map<String, dynamic>> items,
      String Function(Map<String, dynamic>) t,
      String Function(Map<String, dynamic>) sub,
      void Function(Map<String, dynamic>) tap,
    ) {
      if (items.isEmpty) return const SizedBox();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final m in items)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: C.primarySoft,
                      child: Icon(icon, color: C.primary, size: 20),
                    ),
                    title: Text(
                      t(m),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: sub(m).isEmpty ? null : Text(sub(m)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => tap(m),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _c,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: tr('Search products, customers, invoices…'),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: _busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (r == null && _err == null)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: EmptyState(
                icon: Icons.search,
                title: 'Search everything',
                message: 'Type at least 2 letters to find products, customers, invoices and expenses.',
              ),
            ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.error_outline,
                title: 'Search failed',
                message: _err,
              ),
            ),
          if (empty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: EmptyState(icon: Icons.search_off, title: 'No results'),
            ),
          group(
            'Products',
            Icons.inventory_2_outlined,
            products,
            (m) => js(m['name']),
            (m) => js(m['sku']),
            (m) => context.push('/product/${js(m['id'])}'),
          ),
          group(
            'Customers',
            Icons.person_outline,
            customers,
            (m) => js(m['name']),
            (m) => js(m['mobileNumber']),
            (m) => context.push('/customer/${js(m['id'])}'),
          ),
          group(
            'Invoices',
            Icons.receipt_long_outlined,
            invoices,
            (m) => js(m['invoiceNumber']),
            (m) => js(m['customerName']),
            (m) => context.push('/invoice/${js(m['id'])}'),
          ),
          group(
            'Expenses',
            Icons.receipt_outlined,
            expenses,
            (m) => js(m['description']),
            (m) => '',
            (m) => context.push('/expenses'),
          ),
          group(
            'Categories',
            Icons.category_outlined,
            cats,
            (m) => js(m['name']),
            (m) => '',
            (m) => context.push('/categories'),
          ),
        ],
      ),
    );
  }
}
