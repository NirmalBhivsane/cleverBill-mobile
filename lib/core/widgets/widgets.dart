import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color,
    this.margin,
  });
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      color: color ?? C.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: C.border),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.text, {super.key, Color? color, this.bg})
    : _color = color;
  final String text;
  final Color? _color;
  Color get color => _color ?? C.primary;
  final Color? bg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg ?? color.withOpacity(.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );

  static Widget forStatus(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
      case 'received':
      case 'approved':
      case 'converted':
      case 'accepted':
        return StatusChip(s, color: C.success);
      case 'partial':
      case 'pending':
      case 'sent':
      case 'draft':
        return StatusChip(s, color: C.warning);
      case 'unpaid':
      case 'overdue':
      case 'rejected':
      case 'cancelled':
        return StatusChip(s, color: C.danger);
      default:
        return StatusChip(s, color: C.muted);
    }
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    Color? color,
    this.icon,
  }) : _color = color;
  final String label, value;
  final String? sub;
  final Color? _color;
  Color get color => _color ?? C.primary;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(.09),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: C.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color == C.primary ? C.text : color,
            ),
          ),
        ),
        if (sub != null)
          Text(sub!, style: TextStyle(fontSize: 11, color: C.muted)),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: C.text,
            ),
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: C.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: C.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: C.muted),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

/// Renders an AsyncValue with loading / error+retry / data states.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
  });
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => value.when(
    data: builder,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load',
      message: '$e',
      action: onRetry == null
          ? null
          : OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
    ),
  );
}

class AppThumb extends StatelessWidget {
  const AppThumb({
    super.key,
    this.url,
    this.size = 52,
    this.icon = Icons.inventory_2_outlined,
  });
  final String? url;
  final double size;
  final IconData icon;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: size,
      height: size,
      color: C.primarySoft,
      child: url == null
          ? Icon(icon, color: C.primary, size: size * .5)
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  Icon(icon, color: C.primary, size: size * .5),
            ),
    ),
  );
}

class Avatar extends StatelessWidget {
  const Avatar(this.text, {super.key, this.size = 44, Color? color})
    : _color = color;
  final String text;
  final double size;
  final Color? _color;
  Color get color => _color ?? C.primary;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: size / 2,
    backgroundColor: color.withOpacity(.14),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: size * .34,
      ),
    ),
  );
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboard,
    this.required = false,
    this.maxLines = 1,
    this.prefix,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.maxLength,
    this.obscure = false,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboard;
  final bool required, readOnly, obscure;
  final int maxLines;
  final int? maxLength;
  final Widget? prefix, suffix;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: tr(label),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            children: [
              if (required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: C.danger),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          maxLength: maxLength,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint == null ? null : tr(hint!),
            prefixIcon: prefix,
            suffixIcon: suffix,
            counterText: '',
          ),
        ),
      ],
    ),
  );
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.trailing,
    this.controller,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final Widget? trailing;
  final TextEditingController? controller;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint == null ? null : tr(hint!),
            prefixIcon: Icon(Icons.search, color: C.muted),
            isDense: true,
          ),
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 10), trailing!],
    ],
  );
}

class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: labels.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) => ChoiceChip(
        label: Text(labels[i]),
        selected: i == selected,
        onSelected: (_) => onSelect(i),
        selectedColor: C.primary,
        backgroundColor: C.card,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: i == selected ? Colors.white : C.text,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: i == selected ? C.primary : C.border),
      ),
    ),
  );
}

/// Primary button with loading state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: loading ? null : onPressed,
    child: loading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 20),
              ],
            ],
          ),
  );
}

/// Blue gradient app bar content used by Inventory / Purchases / Customers etc.
PreferredSizeWidget blueAppBar(
  BuildContext context,
  String title, {
  String? subtitle,
  List<Widget>? actions,
  bool back = true,
}) {
  return AppBar(
    backgroundColor: C.primary,
    foregroundColor: Colors.white,
    automaticallyImplyLeading: back,
    titleSpacing: back ? 0 : 16,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
      ],
    ),
    actions: actions,
  );
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? C.danger : C.text,
      ),
    );
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String msg, {
  String ok = 'Confirm',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            ok,
            style: TextStyle(
              color: danger ? C.danger : C.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<DateTime?> pickDate(
  BuildContext context, {
  DateTime? initial,
  DateTime? first,
  DateTime? last,
}) => showDatePicker(
  context: context,
  initialDate: initial ?? DateTime.now(),
  firstDate: first ?? DateTime(2020),
  lastDate: last ?? DateTime(2100),
);
