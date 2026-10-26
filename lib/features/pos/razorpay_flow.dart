import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../home/home_screen.dart';
import 'pos_screens.dart' show ensureWalkIn, buildCheckoutBody;

String _hex(Color c) =>
    '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';

/// Online payment through Razorpay (same flow as web POS):
/// 1) create the invoice (unpaid)  2) create Razorpay order for it  3) open checkout  4) verify signature.
Future<void> razorpayCheckout(
  BuildContext context,
  WidgetRef ref, {
  required String mode,
  double? partial,
}) async {
  if (kIsWeb) {
    toast(
      context,
      'Razorpay checkout works in the Android/iOS app, not in the browser.',
      error: true,
    );
    return;
  }
  final cart = ref.read(cartProvider);
  final api = ref.read(apiProvider);
  if (cart.lines.isEmpty) return;
  final shop = ref.read(authProvider).session?.businessName ?? 'Clever Bill';

  Invoice inv;
  Customer customer;
  try {
    customer = cart.customer ?? await ensureWalkIn(ref);
    inv = await api.checkout(
      buildCheckoutBody(
        cart,
        customer,
        mode: mode,
        paid: 0,
        due: DateTime.now().add(Duration(days: partial != null ? 7 : 0)),
      ),
    );
  } catch (e) {
    if (context.mounted) toast(context, '$e', error: true);
    return;
  }

  Future<void> finish(Invoice shown) async {
    ref.read(cartProvider.notifier).clear();
    ref.invalidate(productsProvider);
    ref.invalidate(homeProvider);
    ref.invalidate(customersProvider);
    if (context.mounted) context.pushReplacement('/bill-success', extra: shown);
  }

  while (true) {
    try {
      final order = await api.razorpayCreateOrder({
        'invoiceId': inv.id,
        'currency': 'INR',
        'paymentIntent': partial != null ? 'PARTIAL' : 'FULL',
        'amount': ((partial ?? inv.total) * 100).round(),
      });
      final ready =
          order['actionable'] == true &&
          order['checkoutStatus'] == 'CHECKOUT_READY' &&
          order['paymentIntent'] != 'CANCELLED';
      if (!ready) {
        if (context.mounted)
          toast(
            context,
            'Checkout cannot be opened: invoice is ${js(order['checkoutStatus'], js(order['paymentIntent'], 'rejected')).toLowerCase()}.',
            error: true,
          );
        return finish(inv);
      }

      final done = Completer<Map<String, String>?>();
      final rz = Razorpay();
      rz.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
        if (!done.isCompleted)
          done.complete({
            'orderId': r.orderId ?? '',
            'paymentId': r.paymentId ?? '',
            'signature': r.signature ?? '',
          });
      });
      rz.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        if (!done.isCompleted) done.complete(null);
      });
      rz.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});
      rz.open({
        'key': order['keyId'],
        'amount': order['amountMinor'] ?? order['amount'],
        'currency': order['currency'] ?? 'INR',
        'name': shop,
        'description': 'Invoice ${inv.number}',
        'order_id': order['orderId'] ?? order['razorpayOrderId'],
        if (customer.mobile != '9999999999')
          'prefill': {'contact': customer.mobile, 'email': customer.email},
        'theme': {'color': _hex(C.primary)},
        if (mode == 'UPI')
          'method': {
            'upi': true,
            'card': false,
            'netbanking': false,
            'wallet': false,
          },
        if (mode == 'CARD')
          'method': {
            'upi': false,
            'card': true,
            'netbanking': false,
            'wallet': false,
          },
      });
      final res = await done.future;
      rz.clear();

      if (res != null) {
        final v = await api.razorpayVerify({
          'razorpayOrderId': res['orderId'],
          'razorpayPaymentId': res['paymentId'],
          'razorpaySignature': res['signature'],
          'invoiceId': inv.id,
        });
        if (v['success'] == true) {
          final fresh = await api.invoice(inv.id).catchError((_) => inv);
          return finish(fresh);
        }
        if (context.mounted)
          toast(
            context,
            js(v['message'], 'Payment could not be verified'),
            error: true,
          );
      }
    } catch (e) {
      if (context.mounted) toast(context, '$e', error: true);
    }

    if (!context.mounted) return;
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment not completed'),
        content: Text(
          'Bill ${inv.number} (${money(inv.total)}) is saved as unpaid. Try the online payment again or keep it unpaid and collect later from Payments & Dues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep unpaid'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retry payment'),
          ),
        ],
      ),
    );
    if (retry != true) return finish(inv);
  }
}
