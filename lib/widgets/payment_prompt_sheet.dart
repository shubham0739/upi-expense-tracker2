import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/upi_launcher.dart';
import '../state/app_state.dart';
import '../utils/categories.dart';
import '../utils/format.dart';

/// Opens the "what did you pay for?" bottom sheet.
///
/// Pass [candidates] (SMSes detected while away), [appId] (the UPI app that
/// was launched), or [initial] (an existing expense to edit). Returns the
/// built expense, or null when the user dismissed the sheet.
Future<Expense?> showPaymentPromptSheet(
  BuildContext context, {
  required AppState state,
  List<SmsCandidate> candidates = const [],
  String? appId,
  Expense? initial,
  double? prefillAmount,
  String? prefillPayee,
  String? prefillCategory,
}) {
  return showModalBottomSheet<Expense>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: PaymentPromptSheet(
        state: state,
        candidates: candidates,
        appId: appId,
        initial: initial,
        prefillAmount: prefillAmount,
        prefillPayee: prefillPayee,
        prefillCategory: prefillCategory,
      ),
    ),
  );
}

class PaymentPromptSheet extends StatefulWidget {
  final AppState state;
  final List<SmsCandidate> candidates;
  final String? appId;
  final Expense? initial;
  final double? prefillAmount;
  final String? prefillPayee;
  final String? prefillCategory;

  const PaymentPromptSheet({
    super.key,
    required this.state,
    this.candidates = const [],
    this.appId,
    this.initial,
    this.prefillAmount,
    this.prefillPayee,
    this.prefillCategory,
  });

  @override
  State<PaymentPromptSheet> createState() => _PaymentPromptSheetState();
}

class _PaymentPromptSheetState extends State<PaymentPromptSheet> {
  static const List<String> _paidViaOptions = [
    'Google Pay', 'PhonePe', 'Paytm', 'BHIM', 'Amazon Pay',
    'UPI', 'Cash', 'Card',
  ];

  late final TextEditingController _amount;
  late final TextEditingController _payee;
  late final TextEditingController _note;
  late String _category;
  late DateTime _date;
  late String _paidVia;
  int? _selectedCandidateIndex;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _category = e?.category ??
        widget.prefillCategory ??
        inferCategory(widget.prefillPayee ?? '');
    _date = e?.date ?? DateTime.now();
    _paidVia = e?.paidVia ??
        (widget.appId != null ? UpiLauncher.byId(widget.appId!).name : 'UPI');
    // The dropdown asserts when the value is not among its items, so map any
    // non-standard value (e.g. 'Recurring' from a reminder) to 'UPI'.
    if (!_paidViaOptions.contains(_paidVia)) _paidVia = 'UPI';
    _amount = TextEditingController(text: _initialAmount());
    _payee = TextEditingController(text: e?.payee ?? widget.prefillPayee ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    if (widget.candidates.isNotEmpty && e == null) {
      _applyCandidate(0);
    }
  }

  String _initialAmount() {
    if (e != null) return e!.amount.toStringAsFixed(2);
    if (widget.prefillAmount != null) {
      return widget.prefillAmount!.toStringAsFixed(2);
    }
    return '';
  }

  Expense? get e => widget.initial;

  /// Fills the form from candidate [index] without rebuilding.
  void _applyCandidate(int index) {
    final c = widget.candidates[index];
    _selectedCandidateIndex = index;
    _amount.text = c.amount?.toStringAsFixed(2) ?? _amount.text;
    _payee.text = c.payee ?? _payee.text;
    _date = c.date;
    _paidVia = 'UPI';
    final suggested = inferCategory('${c.payee ?? ''} ${c.body}');
    if (suggested != 'Other') _category = suggested;
  }

  @override
  void dispose() {
    _amount.dispose();
    _payee.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    final candidate =
        _selectedCandidateIndex != null && widget.candidates.isNotEmpty
            ? widget.candidates[_selectedCandidateIndex!]
            : null;
    final expense = Expense(
      id: widget.initial?.id,
      amount: amount,
      payee: _payee.text.trim(),
      category: _category,
      note: _note.text.trim(),
      paidVia: _paidVia,
      date: _date,
      smsId: candidate?.smsId,
    );
    Navigator.of(context).pop(expense);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
            picked.year, picked.month, picked.day, _date.hour, _date.minute);
      });
    }
  }

  Future<void> _newCategory() async {
    final controller = TextEditingController();
    Color color = customCategoryPalette.first;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: customCategoryPalette.map((c) {
                  final selected = c == color;
                  return InkWell(
                    onTap: () => setDialogState(() => color = c),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: c,
                      child: selected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await widget.state.addCustomCategory(name, color);
      if (mounted) setState(() => _category = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final candidates = widget.candidates;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.initial != null ? 'Edit expense' : 'What did you pay for?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          if (candidates.isNotEmpty) ...[
            Text('Detected payments', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ...candidates.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              final selected = i == _selectedCandidateIndex;
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: selected ? scheme.primary : scheme.outlineVariant),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                      selected ? Icons.check_circle : Icons.sms_outlined,
                      color: selected ? scheme.primary : scheme.outline),
                  title: Text(
                    '${c.amount != null ? formatMoney(c.amount!, symbol: widget.state.currencySymbol) : 'Amount?'}'
                    '${c.payee != null ? ' · ${c.payee}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle:
                      Text('${DateFormat('HH:mm').format(c.date)} · ${c.sender}'),
                  onTap: () => setState(() => _applyCandidate(i)),
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => _selectedCandidateIndex = null),
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('None of these — enter manually'),
            ),
            const Divider(),
          ],

          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '${widget.state.currencySymbol} ',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _payee,
            decoration: const InputDecoration(
              labelText: 'Paid to (shop / person)',
              hintText: 'e.g. Sharma Restaurant',
            ),
          ),
          const SizedBox(height: 16),

          Text('Category', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ...widget.state.categories.map((c) => ChoiceChip(
                    label: Text(c.name),
                    avatar: Icon(c.icon, size: 16, color: c.color),
                    selected: _category == c.name,
                    onSelected: (_) => setState(() => _category = c.name),
                  )),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('New'),
                onPressed: _newCategory,
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. Dinner with friends',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(DateFormat('d MMM yyyy · h:mm a').format(_date)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _paidVia,
                  decoration: const InputDecoration(
                    labelText: 'Paid via',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  items: _paidViaOptions
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _paidVia = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(widget.initial != null ? 'Save changes' : 'Save expense'),
            ),
          ),
        ],
      ),
    );
  }
}
