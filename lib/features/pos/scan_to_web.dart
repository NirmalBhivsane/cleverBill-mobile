import 'dart:convert';

import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../providers.dart';

/// Use the phone as a barcode scanner for the web POS ("Scan with phone" on desktop).
/// 1) scan the QR shown on the web POS  2) join the session  3) every barcode scanned is pushed live to the desktop.
class ScanToWebScreen extends ConsumerStatefulWidget {
  const ScanToWebScreen({super.key});
  @override
  ConsumerState<ScanToWebScreen> createState() => _ScanToWebState();
}

class _ScanToWebState extends ConsumerState<ScanToWebScreen> {
  final _ctl = MobileScannerController(detectionSpeed: DetectionSpeed.normal);
  StompClient? _client;
  String? _session;
  bool _connecting = false, _connected = false, _torch = false;
  String? _error, _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<String> _sent = [];

  @override
  void dispose() {
    _client?.deactivate();
    _ctl.dispose();
    super.dispose();
  }

  String? _parse(String raw) {
    final u = Uri.tryParse(raw.trim());
    final q = u?.queryParameters['session'];
    if (q != null && q.isNotEmpty) return q;
    if (RegExp(r'^[A-Za-z0-9\-_]{8,}$').hasMatch(raw.trim())) return raw.trim();
    return null;
  }

  String get _wsUrl =>
      '${Env.apiBase.replaceAll(RegExp(r'/$'), '').replaceFirst(RegExp(r'^http'), 'ws')}/ws/scan/websocket';

  Future<void> _join(String id) async {
    if (_connecting || _connected) return;
    setState(() {
      _connecting = true;
      _error = null;
      _session = id;
    });
    try {
      final ok = await ref.read(apiProvider).validateScanSession(id);
      if (!ok) throw 'This scan session has expired. Generate a new QR on the web POS.';
      _client = StompClient(
        config: StompConfig(
          url: _wsUrl,
          reconnectDelay: const Duration(seconds: 5),
          onConnect: (frame) {
            _client!.send(
              destination: '/app/scan/$id',
              body: jsonEncode({'join': true}),
            );
            if (mounted)
              setState(() {
                _connected = true;
                _connecting = false;
              });
          },
          onWebSocketError: (e) {
            if (mounted)
              setState(() {
                _connected = false;
                _error = 'Connection error';
              });
          },
          onStompError: (f) {
            if (mounted)
              setState(() {
                _connected = false;
                _error = f.body ?? 'Connection error';
              });
          },
          onDisconnect: (f) {
            if (mounted) setState(() => _connected = false);
          },
        ),
      );
      _client!.activate();
    } catch (e) {
      if (mounted)
        setState(() {
          _connecting = false;
          _session = null;
          _error = '$e';
        });
    }
  }

  void _onDetect(BarcodeCapture cap) {
    final code = cap.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    if (_session == null) {
      final id = _parse(code);
      if (id != null) {
        HapticFeedback.mediumImpact();
        _join(id);
      }
      return;
    }
    if (!_connected) return;
    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt).inMilliseconds < 2000)
      return;
    _lastCode = code;
    _lastAt = now;
    HapticFeedback.mediumImpact();
    _client!.send(
      destination: '/app/scan/$_session',
      body: jsonEncode({'barcode': code}),
    );
    setState(() => _sent.insert(0, code));
  }

  Future<void> _manual() async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter session code or link'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(
            hintText: tr('Paste the link from the web POS'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    if (v == null) return;
    final id = _parse(v);
    if (id == null)
      return toast(
        context,
        'That does not look like a scan session link',
        error: true,
      );
    _join(id);
  }

  void _disconnect() {
    _client?.deactivate();
    setState(() {
      _client = null;
      _session = null;
      _connected = false;
      _sent.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final paired = _session != null && _connected;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _ctl, onDetect: _onDetect),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan for web POS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      _ctl.toggleTorch();
                      setState(() => _torch = !_torch);
                    },
                    icon: Icon(
                      _torch ? Icons.flash_on : Icons.flash_off,
                      size: 18,
                    ),
                    label: const Text('Torch'),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: paired ? 150 : 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: paired ? Colors.greenAccent : Colors.lightBlueAccent,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              decoration: BoxDecoration(
                color: C.card,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: C.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (!paired && !_connecting) ...[
                      const Text(
                        '1. Open the web POS → “Scan with phone”\n2. Point this camera at the QR code',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextButton(
                        onPressed: _manual,
                        child: const Text('Or paste the session link'),
                      ),
                    ],
                    if (_connecting)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Connecting to desktop…'),
                          ],
                        ),
                      ),
                    if (paired) ...[
                      Row(
                        children: [
                          CircleAvatar(radius: 6, backgroundColor: C.success),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Connected to web POS — scan products now',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          TextButton(
                            onPressed: _disconnect,
                            child: Text(
                              'Disconnect',
                              style: TextStyle(color: C.danger),
                            ),
                          ),
                        ],
                      ),
                      if (_sent.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Each barcode you scan appears on the desktop instantly.',
                            style: TextStyle(color: C.muted),
                          ),
                        )
                      else
                        SizedBox(
                          height: 110,
                          child: ListView(
                            children: [
                              for (final s in _sent.take(20))
                                ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  leading: Icon(
                                    Icons.check_circle,
                                    color: C.success,
                                    size: 18,
                                  ),
                                  title: Text(s),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
