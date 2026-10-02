import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  Future<void> _editReminder(BuildContext context, AppState state,
      [Reminder? existing]) async {
    final titleController =
        TextEditingController(text: existing?.title ?? '');
    final amountController = TextEditingController(
        text: existing == null ? '' : existing!.amount.toStringAsFixed(0));
    var frequency = existing?.frequency ?? 'monthly';
    var dayOf = existing?.dayOf ?? 1;
    var category = existing?.category ?? 'Other';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit reminder' : 'New reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                      labelText: 'Title', hintText: 'e.g. House rent'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '${state.currencySymbol} '),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: state.categories
                      .map((c) => DropdownMenuItem(
                          value: c.name, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => category = v ?? 'Other'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: 'Repeats'),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => frequency = v ?? 'monthly'),
                ),
                const SizedBox(height: 12),
                if (frequency == 'monthly')
                  DropdownButtonFormField<int>(
                    value: dayOf < 1 ? 1 : (dayOf > 28 ? 28 : dayOf),
                    decoration:
                        const InputDecoration(labelText: 'Day of month'),
                    items: List.generate(
                        28, (i) => i + 1,
                    ).map((d) => DropdownMenuItem(
                        value: d, child: Text('$d'))).toList(),
                    onChanged: (v) => setDialogState(() => dayOf = v ?? 1),
                  ),
                if (frequency == 'weekly')
                  DropdownButtonFormField<int>(
                    value: dayOf < 1 ? 1 : (dayOf > 7 ? 7 : dayOf),
                    decoration: const InputDecoration(labelText: 'Day of week'),
                    items: List.generate(7, (i) => i + 1)
                        .map((d) => DropdownMenuItem(
                            value: d, child: Text(weekdayName(d))))
                        .toList(),
                    onChanged: (v) => setDialogState(() => dayOf = v ?? 1),
                  ),
                if (frequency == 'yearly') ...[
                  DropdownButtonFormField<int>(
                    value: dayOf >= 100 ? dayOf ~/ 100 : 1,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: List.generate(12, (i) => i + 1)
                        .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(shortMonth(DateTime(2024, m, 1)))))
                        .toList(),
                    onChanged: (v) => setDialogState(() {
                      final day = dayOf >= 100 ? dayOf % 100 : 1;
                      dayOf = (v ?? 1) * 100 + day;
                    }),
                  ),
                  DropdownButtonFormField<int>(
                    value: dayOf >= 100 ? dayOf % 100 : 1,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: List.generate(28, (i) => i + 1)
                        .map((d) =>
                            DropdownMenuItem(value: d, child: Text('$d')))
                        .toList(),
                    onChanged: (v) => setDialogState(() {
                      final month = dayOf >= 100 ? dayOf ~/ 100 : 1;
                      dayOf = month * 100 + (v ?? 1);
                    }),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    await state.saveReminder(Reminder(
      id: existing?.id,
      title: title,
      category: category,
      amount: amount,
      frequency: frequency,
      dayOf: dayOf,
      lastFired: existing?.lastFired,
      enabled: existing?.enabled ?? true,
    ));
  }

  Future<void> _confirmDelete(
      BuildContext context, AppState state, Reminder r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text(r.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await state.deleteReminder(r.id!);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring reminders')),
      body: SafeArea(
        child: state.reminders.isEmpty
            ? const EmptyState(
                icon: Icons.event_repeat,
                title: 'No reminders',
                subtitle:
                    'Add rent, EMIs, or subscriptions so the app nudges you when they are due.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                children: [
                  for (final r in state.reminders)
                    Card(
                      child: ListTile(
                        onTap: () => _editReminder(context, state, r),
                        leading: CircleAvatar(
                          child: Icon(state.categoryIcon(r.category),
                              size: 20),
                        ),
                        title: Text(r.title),
                        subtitle: Text(_subtitle(r, now, state)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (state.dueReminders.any((d) => d.id == r.id))
                              FilledButton.tonal(
                                onPressed: () => state.logReminder(r),
                                child: const Text('Log paid'),
                              ),
                            Switch(
                              value: r.enabled,
                              onChanged: (v) => state.saveReminder(Reminder(
                                id: r.id,
                                title: r.title,
                                category: r.category,
                                amount: r.amount,
                                frequency: r.frequency,
                                dayOf: r.dayOf,
                                lastFired: r.lastFired,
                                enabled: v,
                              )),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _confirmDelete(context, state, r),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editReminder(context, state),
        icon: const Icon(Icons.add),
        label: const Text('Add reminder'),
      ),
    );
  }

  String _subtitle(Reminder r, DateTime now, AppState state) {
    final parts = [
      '${formatMoney(r.amount, symbol: state.currencySymbol)}',
    ];
    switch (r.frequency) {
      case 'weekly':
        parts.add('every ${weekdayName(r.dayOf)}');
        break;
      case 'yearly':
        final m = r.dayOf ~/ 100;
        final safeM = m < 1 ? 1 : (m > 12 ? 12 : m);
        final d = r.dayOf % 100;
        parts.add('every ${shortMonth(DateTime(2024, safeM, 1))} $d');
        break;
      default:
        parts.add('every month on day ${r.dayOf}');
    }
    final due = nextDueDate(r, now);
    parts.add(due != null ? 'next: ${formatDate(due).split(',').first}' : '');
    return parts.join(' · ');
  }
}
