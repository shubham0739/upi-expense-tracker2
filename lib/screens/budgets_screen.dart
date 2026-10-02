import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  Future<void> _editBudget(BuildContext context, AppState state,
      [Budget? existing]) async {
    var category = existing?.category ?? '';
    var period = existing?.period ?? 'monthly';
    final amountController =
        TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit budget' : 'New budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Applies to'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Overall')),
                  ...state.categories
                      .map((c) => DropdownMenuItem(
                          value: c.name, child: Text(c.name))),
                ],
                onChanged: (v) => setDialogState(() => category = v ?? ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Limit',
                  prefixText: '${state.currencySymbol} ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: period,
                decoration: const InputDecoration(labelText: 'Period'),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                ],
                onChanged: (v) => setDialogState(() => period = v ?? 'monthly'),
              ),
            ],
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
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) return;
    await state.saveBudget(Budget(
      id: existing?.id,
      category: category,
      amount: amount,
      period: period,
    ));
  }

  Future<void> _confirmDelete(BuildContext context, AppState state, Budget b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text(b.category.isEmpty
            ? 'Overall budget of ${formatMoney(b.amount, symbol: state.currencySymbol)}'
            : '${b.category} budget of ${formatMoney(b.amount, symbol: state.currencySymbol)}'),
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
    if (ok == true) await state.deleteBudget(b.id!);
  }

  Widget _budgetCard(
      BuildContext context, AppState state, Budget b) {
    final scheme = Theme.of(context).colorScheme;
    final spent = state.spentForBudget(b);
    final ratio = b.amount <= 0 ? 0.0 : spent / b.amount;
    final over = spent > b.amount;
    final label = b.category.isEmpty ? 'Overall' : b.category;
    final icon = b.category.isEmpty
        ? Icons.pie_chart_outline
        : state.categoryIcon(b.category);
    final color = over
        ? scheme.error
        : ratio > 0.7
            ? const Color(0xFFFFB300)
            : const Color(0xFF43A047);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _editBudget(context, state, b);
                    if (v == 'delete') _confirmDelete(context, state, b);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatMoney(spent, symbol: state.currencySymbol)} / '
                  '${formatMoney(b.amount, symbol: state.currencySymbol)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('${(ratio * 100).round()}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              over
                  ? 'Over budget by ${formatMoney(spent - b.amount, symbol: state.currencySymbol)}'
                  : '${formatMoney(b.amount - spent, symbol: state.currencySymbol)} left (${b.period})',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: over ? scheme.error : scheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: SafeArea(
        child: state.budgets.isEmpty
            ? const EmptyState(
                icon: Icons.savings_outlined,
                title: 'No budgets yet',
                subtitle:
                    'Set a monthly or weekly limit and track it against your spending.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                children: [
                  for (final b in state.budgets) ...[
                    _budgetCard(context, state, b),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editBudget(context, state),
        icon: const Icon(Icons.add),
        label: const Text('Add budget'),
      ),
    );
  }
}
