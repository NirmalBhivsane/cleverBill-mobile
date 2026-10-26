import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

/// Print / share / download helpers shared by bill-success and invoice-detail.
class InvoiceActions {
  static Future<Uint8List> _pdf(Api api, Invoice inv) async =>
      Uint8List.fromList(await api.invoicePdf(inv.id));

  static Future<void> print(BuildContext context, Api api, Invoice inv) async {
    try {
      final bytes = await _pdf(api, inv);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: inv.number);
    } catch (e) {
      if (context.mounted) toast(context, '$e', error: true);
    }
  }

  static Future<void> share(
    BuildContext context,
    Api api,
    Invoice inv, {
    String shop = '',
  }) async {
    try {
      final bytes = await _pdf(api, inv);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/${inv.number}.pdf');
      await f.writeAsBytes(bytes);
      final text =
          'Invoice ${inv.number}${shop.isEmpty ? '' : ' from $shop'}\nTotal: ${money(inv.total)}'
          '${inv.due > 0 ? '\nBalance due: ${money(inv.due)}' : ''}\nThank you!';
      await Share.shareXFiles([
        XFile(f.path, mimeType: 'application/pdf'),
      ], text: text);
    } catch (e) {
      if (context.mounted) toast(context, '$e', error: true);
    }
  }

  static Future<void> download(
    BuildContext context,
    Api api,
    Invoice inv,
  ) async {
    try {
      final bytes = await _pdf(api, inv);
      await Printing.sharePdf(bytes: bytes, filename: '${inv.number}.pdf');
    } catch (e) {
      if (context.mounted) toast(context, '$e', error: true);
    }
  }
}
