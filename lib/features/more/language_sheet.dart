import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../providers.dart';

void showLanguageSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) {
      final cur = ref.read(languageProvider);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'App language',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            for (final e in I18n.names.entries)
              ListTile(
                leading: Icon(Icons.language, color: C.primary),
                title: Text(
                  e.value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: cur == e.key
                    ? Icon(Icons.check_circle, color: C.primary)
                    : null,
                onTap: () {
                  ref.read(languageProvider.notifier).set(e.key);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
