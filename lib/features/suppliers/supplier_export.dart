import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/widgets/widgets.dart';
import '../../data/models.dart';

class SupplierExportHelper {
  static Future<void> exportSuppliers(
    BuildContext context,
    List<Supplier> suppliers, {
    required bool excel,
  }) async {
    try {
      final buffer = StringBuffer();
      final delimiter = excel ? '\t' : ',';
      final ext = excel ? 'xls' : 'csv';

      // Header row
      final headers = [
        '#',
        'Supplier Name',
        'Contact Person',
        'Phone',
        'Email',
        'GSTIN',
        'State',
        'Address',
        'Status',
        'Total Purchases (INR)',
        'Total Paid (INR)',
        'Outstanding Payable (INR)',
      ];

      buffer.writeln(
        headers
            .map((h) => excel ? h : '"${h.replaceAll('"', '""')}"')
            .join(delimiter),
      );

      for (var i = 0; i < suppliers.length; i++) {
        final s = suppliers[i];
        final row = [
          '${i + 1}',
          s.name,
          s.contact.isNotEmpty ? s.contact : '—',
          s.phone.isNotEmpty ? s.phone : '—',
          s.email.isNotEmpty ? s.email : '—',
          s.gstin.isNotEmpty ? s.gstin : '—',
          s.state.isNotEmpty ? s.state : '—',
          s.address.isNotEmpty ? s.address : '—',
          s.status,
          s.totalPurchases.toStringAsFixed(2),
          s.totalPaid.toStringAsFixed(2),
          s.outstanding.toStringAsFixed(2),
        ];

        buffer.writeln(
          row
              .map((cell) => excel ? cell : '"${cell.replaceAll('"', '""')}"')
              .join(delimiter),
        );
      }

      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final file = File('${dir.path}/CleverBill_Suppliers_$stamp.$ext');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Clever Bill Suppliers Export ($stamp)');
      if (context.mounted) {
        toast(context, 'Export generated successfully');
      }
    } catch (e) {
      if (context.mounted) {
        toast(context, 'Export failed: $e', error: true);
      }
    }
  }
}

