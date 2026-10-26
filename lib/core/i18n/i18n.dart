import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' hide Text;

import 'translations.dart';

/// Tiny runtime translation layer (English / हिन्दी / मराठी).
/// Every `Text` in the app is this widget, so any string that has an entry in
/// translations.dart is shown in the selected language; everything else stays English.
class I18n {
  static String lang = 'en'; // en | hi | mr
  static const names = {'en': 'English', 'hi': 'हिन्दी', 'mr': 'मराठी'};
}

final List<String> _fragKeys = kFrag.keys.toList()
  ..sort((a, b) => b.length.compareTo(a.length));

String tr(String s) {
  if (I18n.lang == 'en' || s.isEmpty) return s;
  final i = I18n.lang == 'hi' ? 0 : 1;
  final hit = kTr[s];
  if (hit != null) return hit[i];
  final t = s.trim();
  if (t.isNotEmpty && t != s) {
    final h = kTr[t];
    if (h != null) return s.replaceFirst(t, h[i]);
  }
  // runtime-built strings such as "5 items • ₹450" or "Due ₹120": translate known fragments only
  if (!RegExp(r'[\d₹]').hasMatch(s)) return s;
  var out = s;
  for (final k in _fragKeys) {
    if (out.contains(k)) out = out.replaceAll(k, kFrag[k]![i]);
  }
  return out;
}

class Text extends StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    if (textSpan != null) {
      return m.Text.rich(
        textSpan!,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return m.Text(
      tr(data!),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
