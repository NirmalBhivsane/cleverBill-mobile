import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';

/// ESC/POS receipt printing to a paired Bluetooth thermal printer (58 mm / 80 mm).
class ThermalPrinter {
  static String _ascii(String s, int max) {
    final t = s.replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
    return t.length > max ? t.substring(0, max) : t;
  }

  static Future<List<int>> receipt(
    Invoice inv, {
    required String shop,
    required bool mm80,
  }) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(mm80 ? PaperSize.mm80 : PaperSize.mm58, profile);
    final w = mm80 ? 24 : 16;
    final r = const PosStyles(align: PosAlign.right);
    List<int> b = [];
    b += g.reset();
    b += g.text(
      _ascii(shop, 32),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    b += g.text(
      'Invoice: ${_ascii(inv.number, 24)}',
      styles: const PosStyles(align: PosAlign.center),
    );
    b += g.text(
      dateTime12(inv.createdAt),
      styles: const PosStyles(align: PosAlign.center),
    );
    b += g.text('Customer: ${_ascii(inv.customerName, 22)}');
    b += g.hr();
    b += g.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: 'Qty',
        width: 2,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
      PosColumn(
        text: 'Amount',
        width: 4,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);
    for (final it in inv.items) {
      b += g.row([
        PosColumn(text: _ascii(it.name, w), width: 6),
        PosColumn(text: '${it.qty}', width: 2, styles: r),
        PosColumn(text: it.lineTotal.toStringAsFixed(2), width: 4, styles: r),
      ]);
    }
    b += g.hr();
    void kv(String k, String v, {bool bold = false}) {
      b += g.row([
        PosColumn(
          text: k,
          width: 7,
          styles: PosStyles(bold: bold),
        ),
        PosColumn(
          text: v,
          width: 5,
          styles: PosStyles(align: PosAlign.right, bold: bold),
        ),
      ]);
    }

    kv('Subtotal', inv.subtotal.toStringAsFixed(2));
    if (inv.tax > 0) kv('Tax', inv.tax.toStringAsFixed(2));
    if (inv.discount > 0) kv('Discount', '-${inv.discount.toStringAsFixed(2)}');
    kv('TOTAL', 'Rs.${inv.total.toStringAsFixed(2)}', bold: true);
    kv('Paid (${_ascii(inv.paymentMode, 6)})', inv.paid.toStringAsFixed(2));
    if (inv.due > 0) kv('Balance due', inv.due.toStringAsFixed(2), bold: true);
    b += g.hr();
    b += g.text(
      'Thank you! Visit again.',
      styles: const PosStyles(align: PosAlign.center),
    );
    b += g.feed(3);
    b += g.cut();
    return b;
  }

  static Future<String?> printInvoice(WidgetRef ref, Invoice inv) async {
    final prefs = ref.read(prefsProvider);
    final mac = prefs.getString('bt_mac');
    if (mac == null) return 'NO_PRINTER';
    try {
      if (!await PrintBluetoothThermal.bluetoothEnabled)
        return 'Bluetooth is off. Turn it on and try again.';
      if (!await PrintBluetoothThermal.connectionStatus) {
        final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
        if (!ok)
          return 'Could not connect to ${prefs.getString('bt_name') ?? 'the printer'}. Is it switched on and in range?';
      }
      final bytes = await receipt(
        inv,
        shop: ref.read(authProvider).session?.businessName ?? 'Clever Bill',
        mm80: prefs.getString('bt_paper') == '80',
      );
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      return ok ? null : 'Printer did not accept the data.';
    } catch (e) {
      return '$e';
    }
  }
}

Future<void> printThermal(
  BuildContext context,
  WidgetRef ref,
  Invoice inv,
) async {
  final err = await ThermalPrinter.printInvoice(ref, inv);
  if (!context.mounted) return;
  if (err == 'NO_PRINTER') {
    toast(context, 'Choose a Bluetooth printer first');
    context.push('/settings/printer');
  } else if (err != null) {
    toast(context, err, error: true);
  }
}

class BluetoothPrinterScreen extends ConsumerStatefulWidget {
  const BluetoothPrinterScreen({super.key});
  @override
  ConsumerState<BluetoothPrinterScreen> createState() => _BtPrinterState();
}

class _BtPrinterState extends ConsumerState<BluetoothPrinterScreen> {
  List<BluetoothInfo> _devices = [];
  bool _loading = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
        _error = 'Allow “Nearby devices / Bluetooth” permission for Clever Bill in your phone settings.';
      } else if (!await PrintBluetoothThermal.bluetoothEnabled) {
        _error = 'Bluetooth is off.';
      } else {
        _devices = await PrintBluetoothThermal.pairedBluetooths;
      }
    } catch (e) {
      _error = 'Bluetooth printing is available on the Android app only.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _select(BluetoothInfo d) async {
    setState(() => _busy = true);
    final prefs = ref.read(prefsProvider);
    try {
      final ok = await PrintBluetoothThermal.connect(
        macPrinterAddress: d.macAdress,
      );
      if (ok) {
        await prefs.setString('bt_mac', d.macAdress);
        await prefs.setString('bt_name', d.name);
        if (mounted) toast(context, 'Connected to ${d.name}');
      } else if (mounted) {
        toast(
          context,
          'Could not connect. Make sure the printer is on.',
          error: true,
        );
      }
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      final profile = await CapabilityProfile.load();
      final mm80 = ref.read(prefsProvider).getString('bt_paper') == '80';
      final g = Generator(mm80 ? PaperSize.mm80 : PaperSize.mm58, profile);
      List<int> b = g.reset();
      b += g.text(
        'Clever Bill',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      b += g.text(
        'Printer test OK',
        styles: const PosStyles(align: PosAlign.center),
      );
      b += g.feed(3);
      b += g.cut();
      final ok = await PrintBluetoothThermal.writeBytes(b);
      if (mounted)
        toast(
          context,
          ok ? 'Test receipt sent' : 'Printer did not respond',
          error: !ok,
        );
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);
    final mac = prefs.getString('bt_mac');
    final paper = prefs.getString('bt_paper') ?? '58';
    return Scaffold(
      appBar: blueAppBar(
        context,
        'Bluetooth printer',
        subtitle: 'ESC/POS thermal receipt printers',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                Icon(Icons.print_outlined, color: C.primary, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    mac == null
                        ? 'No printer selected'
                        : 'Selected: ${prefs.getString('bt_name') ?? mac}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (mac != null)
                  TextButton(
                    onPressed: _busy ? null : _test,
                    child: const Text('Test print'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Paper width',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '58', label: Text('58 mm')),
              ButtonSegment(value: '80', label: Text('80 mm')),
            ],
            selected: {paper},
            onSelectionChanged: (v) async {
              await prefs.setString('bt_paper', v.first);
              setState(() {});
            },
          ),
          SectionTitle('Paired printers', action: 'Refresh', onAction: _scan),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            EmptyState(
              icon: Icons.bluetooth_disabled,
              title: 'Bluetooth unavailable',
              message: _error,
            )
          else if (_devices.isEmpty)
            const EmptyState(
              icon: Icons.bluetooth_searching,
              title: 'No paired printers found',
              message: 'Pair your printer in the phone’s Bluetooth settings first, then tap Refresh.',
            )
          else
            for (final d in _devices)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: _busy ? null : () => _select(d),
                  child: Row(
                    children: [
                      Icon(Icons.bluetooth, color: C.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              d.macAdress,
                              style: TextStyle(color: C.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (mac == d.macAdress)
                        Icon(Icons.check_circle, color: C.success),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 10),
          Text(
            'Receipts print in English characters only (ESC/POS limitation).',
            style: TextStyle(color: C.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
