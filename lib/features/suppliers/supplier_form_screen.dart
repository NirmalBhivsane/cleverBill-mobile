import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../inventory/inventory_screens.dart' show suppliersProvider;
import 'supplier_constants.dart';

class SupplierFormScreen extends ConsumerStatefulWidget {
  const SupplierFormScreen({super.key, this.supplier});
  final Supplier? supplier;

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormState();
}

class _SupplierFormState extends ConsumerState<SupplierFormScreen> {
  late final _name = TextEditingController(text: widget.supplier?.name);
  late final _contact = TextEditingController(text: widget.supplier?.contact);
  late final _phone = TextEditingController(text: widget.supplier?.phone);
  late final _email = TextEditingController(text: widget.supplier?.email);
  late final _addr = TextEditingController(text: widget.supplier?.address);
  late final _gst = TextEditingController(text: widget.supplier?.gstin);
  late final _opening = TextEditingController(
    text: (widget.supplier?.openingBalance ?? 0) > 0
        ? widget.supplier!.openingBalance.toStringAsFixed(0)
        : '',
  );

  late String _state = widget.supplier?.state.isNotEmpty == true
      ? widget.supplier!.state
      : 'Maharashtra';
  late bool _active = widget.supplier?.active ?? true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _gst.addListener(_onGstinChanged);
  }

  @override
  void dispose() {
    _gst.removeListener(_onGstinChanged);
    _name.dispose();
    _contact.dispose();
    _phone.dispose();
    _email.dispose();
    _addr.dispose();
    _gst.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _onGstinChanged() {
    final gstin = _gst.text.trim();
    if (gstin.length >= 2) {
      final detected = stateFromGstin(gstin);
      if (detected != null && detected != _state) {
        setState(() => _state = detected);
      }
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    final gstin = _gst.text.trim().toUpperCase();

    if (name.isEmpty) {
      return toast(context, 'Enter supplier name', error: true);
    }

    if (phone.isEmpty) {
      return toast(context, 'Enter phone number', error: true);
    }

    if (!isValidPhone(phone)) {
      return toast(context, 'Enter a valid 10-digit phone number', error: true);
    }

    if (email.isNotEmpty && !email.contains('@')) {
      return toast(context, 'Enter a valid email address', error: true);
    }

    if (gstin.isNotEmpty && !isValidGstin(gstin)) {
      return toast(
        context,
        'Enter a valid 15-character GSTIN (e.g. 27ABCDE1234F1Z5)',
        error: true,
      );
    }

    // Duplicate detection checks (SUP-AC-01 / Requirements doc)
    final existingSuppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final otherSuppliers = existingSuppliers.where(
      (s) => s.id != widget.supplier?.id,
    );

    // Duplicate phone warning
    final dupPhone = otherSuppliers
        .where(
          (s) =>
              s.phone.replaceAll(RegExp(r'\D'), '') ==
              phone.replaceAll(RegExp(r'\D'), ''),
        )
        .firstOrNull;

    if (dupPhone != null) {
      final proceed = await confirm(
        context,
        'Duplicate Phone Warning',
        'A supplier named "${dupPhone.name}" already uses the phone number $phone. Do you want to proceed and save anyway?',
        ok: 'Proceed',
      );
      if (!proceed) return;
    }

    // Duplicate GSTIN warning
    if (gstin.isNotEmpty) {
      final dupGst = otherSuppliers
          .where((s) => s.gstin.toUpperCase() == gstin)
          .firstOrNull;
      if (dupGst != null) {
        final proceed = await confirm(
          context,
          'Duplicate GSTIN Warning',
          'A supplier named "${dupGst.name}" already uses the GSTIN $gstin. Do you want to proceed and save anyway?',
          ok: 'Proceed',
        );
        if (!proceed) return;
      }
    }

    setState(() => _busy = true);
    try {
      String? n(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();

      final stateMatch = indianStates.where((st) => st.name == _state).firstOrNull;

      await ref.read(apiProvider).saveSupplier({
        'name': name,
        'contactPerson': n(_contact),
        'phone': phone,
        'email': n(_email),
        'address': n(_addr),
        'gstin': gstin.isEmpty ? null : gstin,
        'state': _state,
        'stateCode': stateMatch?.code,
        'active': _active,
        'status': _active ? 'ACTIVE' : 'INACTIVE',
        if (_opening.text.trim().isNotEmpty)
          'openingBalance': double.tryParse(_opening.text.trim()) ?? 0.0,
      }, id: widget.supplier?.id);

      ref.invalidate(suppliersProvider);
      if (mounted) {
        toast(context, 'Supplier saved successfully');
        context.pop();
      }
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier == null ? 'Add Supplier' : 'Edit Supplier'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabeledField(
            label: 'Supplier Name *',
            controller: _name,
            required: true,
            hint: 'e.g. Ramesh Traders / Kantilal Kamble',
          ),
          LabeledField(
            label: 'Contact Person',
            controller: _contact,
            hint: 'e.g. Ramesh Patil',
          ),
          LabeledField(
            label: 'Phone Number *',
            controller: _phone,
            keyboard: TextInputType.phone,
            required: true,
            maxLength: 10,
            hint: 'e.g. 9876543210',
          ),
          LabeledField(
            label: 'Email Address',
            controller: _email,
            keyboard: TextInputType.emailAddress,
            hint: 'e.g. supplier@example.com',
          ),
          LabeledField(
            label: 'GSTIN (optional)',
            controller: _gst,
            hint: 'e.g. 27ABCDE1234F1Z5',
          ),

          // State Dropdown (with auto-fill from GSTIN)
          const Text(
            'State *',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: indianStates.any((s) => s.name == _state)
                ? _state
                : indianStates.first.name,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: [
              for (final st in indianStates)
                DropdownMenuItem(value: st.name, child: Text(st.name)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _state = v);
            },
          ),
          const SizedBox(height: 14),

          LabeledField(
            label: 'Address',
            controller: _addr,
            maxLines: 2,
            hint: 'Street, Area, City, Pin Code',
          ),

          LabeledField(
            label: 'Opening Payable Balance (₹)',
            controller: _opening,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            hint: 'Optional initial opening balance',
          ),

          // Active / Inactive switch
          SwitchListTile(
            title: const Text(
              'Active Supplier',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              _active
                  ? 'Supplier is active and available for new purchases'
                  : 'Supplier is inactive and hidden from new orders',
              style: TextStyle(fontSize: 12, color: C.muted),
            ),
            value: _active,
            activeColor: C.success,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 20),

          PrimaryButton('Save Supplier', loading: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

