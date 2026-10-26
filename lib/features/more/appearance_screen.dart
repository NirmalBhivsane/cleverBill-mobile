import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../providers.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(appearanceProvider);
    final ctl = ref.read(appearanceProvider.notifier);
    Widget modeCard(bool dark, IconData icon, String label) {
      final sel = ap.dark == dark;
      return Expanded(
        child: GestureDetector(
          onTap: () => ctl.update(dark: dark),
          child: Container(
            margin: EdgeInsets.only(right: dark ? 0 : 8, left: dark ? 8 : 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sel ? C.primarySoft : C.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel ? C.primary : C.border,
                width: sel ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF0D111D) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE3E8F3)),
                  ),
                  child: Icon(
                    icon,
                    color: dark ? const Color(0xFF818CF8) : Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: sel ? C.text : C.muted,
                      ),
                    ),
                    if (sel) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle, size: 18, color: C.primary),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: blueAppBar(
        context,
        'Appearance',
        subtitle: 'Customize colors, typography and display modes',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined, color: C.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Display mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    modeCard(false, Icons.wb_sunny_outlined, 'Light Mode'),
                    modeCard(true, Icons.nightlight_round, 'Dark Mode'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_outlined, color: C.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Primary brand color',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in kPalettes.entries)
                      ChoiceChip(
                        selected: ap.colorKey == e.key,
                        showCheckmark: false,
                        avatar: CircleAvatar(
                          radius: 8,
                          backgroundColor: e.value.primary,
                        ),
                        label: Text(
                          e.value.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: C.text,
                          ),
                        ),
                        backgroundColor: C.card,
                        selectedColor: C.primarySoft,
                        side: BorderSide(
                          color: ap.colorKey == e.key ? C.primary : C.border,
                        ),
                        onSelected: (_) => ctl.update(colorKey: e.key),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Preview — ${kPalettes[ap.colorKey]?.label ?? ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.text_fields, color: C.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Font sizing',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final f in const [
                      ('SMALL', 'Small', 14.0),
                      ('MEDIUM', 'Medium (Default)', 16.0),
                      ('LARGE', 'Large', 18.0),
                    ])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => ctl.update(fontKey: f.$1),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: ap.fontKey == f.$1
                                  ? C.primarySoft
                                  : C.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ap.fontKey == f.$1
                                    ? C.primary
                                    : C.border,
                                width: ap.fontKey == f.$1 ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Aa',
                                  style: TextStyle(
                                    fontSize: f.$3 + 4,
                                    fontWeight: FontWeight.w800,
                                    color: C.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  f.$2,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: C.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: ctl.reset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset to defaults'),
          ),
        ],
      ),
    );
  }
}
