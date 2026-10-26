import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/widgets.dart';
import '../../providers.dart';

Color? _hex(String h) {
  try {
    final c = h.replaceAll('#', '').trim();
    if (c.length != 6) return null;
    return Color(int.parse('FF$c', radix: 16));
  } catch (_) {
    return null;
  }
}

/// Invoice PDF customisation (same settings as the web "Invoice Customization" page).
class InvoiceDesignScreen extends ConsumerStatefulWidget {
  const InvoiceDesignScreen({super.key});
  @override
  ConsumerState<InvoiceDesignScreen> createState() => _InvoiceDesignState();
}

class _InvoiceDesignState extends ConsumerState<InvoiceDesignScreen> {
  Map<String, dynamic> _d = {};
  final _c = <String, TextEditingController>{};
  bool _loading = true, _busy = false;
  static const _textKeys = [
    'pdfColorPrimary',
    'pdfColorSecondary',
    'pdfColorTableHeader',
    'pdfColorText',
    'pdfHeaderText',
    'pdfFooterText',
    'defaultInvoiceNotes',
  ];
  static const _presets = [
    ('Indigo Classic', '#4f46e5', '#818cf8', '#f3f4f6', '#1f2937'),
    ('Emerald Sleek', '#059669', '#34d399', '#ecfdf5', '#064e3b'),
    ('Crimson Bold', '#e11d48', '#fda4af', '#fff1f2', '#4c0519'),
    ('Dark Slate', '#0f172a', '#64748b', '#f8fafc', '#0f172a'),
  ];

  @override
  void initState() {
    super.initState();
    ref
        .read(apiProvider)
        .invoicePdfSettings()
        .then((d) {
          if (!mounted) return;
          _d = d;
          for (final k in _textKeys) {
            _c[k] = TextEditingController(text: js(d[k]));
          }
          setState(() => _loading = false);
        })
        .catchError((e) {
          if (mounted) {
            for (final k in _textKeys) {
              _c[k] = TextEditingController();
            }
            setState(() => _loading = false);
            toast(context, '$e', error: true);
          }
        });
  }

  Future<void> _uploadSignature() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 90,
    );
    if (x == null) return;
    setState(() => _busy = true);
    try {
      final url = await ref.read(apiProvider).uploadProductImage(x.path);
      if (url != null)
        setState(() {
          _d['signatureUrl'] = url;
          _d['showSignature'] = true;
        });
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    for (final k in _textKeys) {
      _d[k] = _c[k]!.text.trim();
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).updateInvoicePdfSettings(_d);
      if (mounted) {
        toast(context, 'Saved');
        context.pop();
      }
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _toggle(String key, String label) => SwitchListTile(
    value: jb(_d[key]),
    title: Text(label),
    onChanged: (v) => setState(() => _d[key] = v),
  );

  Widget _colorField(String key, String label) {
    final col = _hex(_c[key]!.text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: col ?? C.border,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: C.border),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _c[key],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tr(label),
                isDense: true,
                hintText: '#4f46e5',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tpl = js(_d['pdfTemplate'], 'CLASSIC');
    return Scaffold(
      appBar: blueAppBar(context, 'Invoice & receipt design'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Template',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final t in const [
                      ('CLASSIC', 'Classic'),
                      ('MODERN', 'Modern'),
                      ('GST', 'GST Tax'),
                    ])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _d['pdfTemplate'] = t.$1),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: tpl == t.$1 ? C.primarySoft : C.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: tpl == t.$1 ? C.primary : C.border,
                                width: tpl == t.$1 ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  t.$1 == 'GST'
                                      ? Icons.account_balance_outlined
                                      : t.$1 == 'MODERN'
                                      ? Icons.view_agenda_outlined
                                      : Icons.description_outlined,
                                  color: C.primary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  t.$2,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SectionTitle('Colours'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in _presets)
                      ActionChip(
                        avatar: CircleAvatar(
                          radius: 8,
                          backgroundColor: _hex(p.$2),
                        ),
                        label: Text(p.$1),
                        onPressed: () => setState(() {
                          _c['pdfColorPrimary']!.text = p.$2;
                          _c['pdfColorSecondary']!.text = p.$3;
                          _c['pdfColorTableHeader']!.text = p.$4;
                          _c['pdfColorText']!.text = p.$5;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _colorField('pdfColorPrimary', 'Primary colour'),
                _colorField('pdfColorSecondary', 'Secondary colour'),
                _colorField('pdfColorTableHeader', 'Table header colour'),
                _colorField('pdfColorText', 'Text colour'),
                const SectionTitle('Show on invoice'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _toggle('pdfShowLogo', 'Show logo'),
                      _toggle('pdfShowBanking', 'Show bank details'),
                      _toggle('pdfShowUpi', 'Show UPI QR'),
                      _toggle('pdfShowTerms', 'Show terms & conditions'),
                      _toggle('pdfShowSignature', 'Show signature'),
                      _toggle('showHsnColumn', 'Show HSN column'),
                      _toggle('showTaxColumn', 'Show tax column'),
                      _toggle('showDiscountColumn', 'Show discount column'),
                      _toggle('showProductImage', 'Show product image'),
                      _toggle('showPoweredBy', 'Show “Powered by Clever Bill”'),
                    ],
                  ),
                ),
                const SectionTitle('Text'),
                LabeledField(
                  label: 'Header text',
                  controller: _c['pdfHeaderText']!,
                ),
                LabeledField(
                  label: 'Footer text',
                  controller: _c['pdfFooterText']!,
                ),
                LabeledField(
                  label: 'Default notes / terms',
                  controller: _c['defaultInvoiceNotes']!,
                  maxLines: 3,
                ),
                const SectionTitle('Font'),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value:
                            const [
                              'Helvetica',
                              'Times New Roman',
                            ].contains(_d['invoiceFontFamily'])
                            ? '${_d['invoiceFontFamily']}'
                            : 'Helvetica',
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'Helvetica',
                            child: Text('Helvetica (Sans-serif)'),
                          ),
                          DropdownMenuItem(
                            value: 'Times New Roman',
                            child: Text('Times New Roman (Serif)'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _d['invoiceFontFamily'] = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value:
                            const [
                              'SMALL',
                              'MEDIUM',
                              'LARGE',
                            ].contains(_d['invoiceFontSize'])
                            ? '${_d['invoiceFontSize']}'
                            : 'MEDIUM',
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'SMALL',
                            child: Text('Small'),
                          ),
                          DropdownMenuItem(
                            value: 'MEDIUM',
                            child: Text('Medium'),
                          ),
                          DropdownMenuItem(
                            value: 'LARGE',
                            child: Text('Large'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _d['invoiceFontSize'] = v),
                      ),
                    ),
                  ],
                ),
                const SectionTitle('Signature'),
                AppCard(
                  child: Row(
                    children: [
                      if (js(_d['signatureUrl']).isNotEmpty)
                        AppThumb(
                          url: js(_d['signatureUrl']),
                          size: 56,
                          icon: Icons.draw_outlined,
                        )
                      else
                        Icon(Icons.draw_outlined, color: C.muted, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          js(_d['signatureUrl']).isEmpty
                              ? 'No signature uploaded'
                              : 'Signature uploaded',
                          style: TextStyle(color: C.muted),
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(90, 40),
                        ),
                        onPressed: _busy ? null : _uploadSignature,
                        child: const Text('Upload'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryButton('Save changes', loading: _busy, onPressed: _save),
              ],
            ),
    );
  }
}
