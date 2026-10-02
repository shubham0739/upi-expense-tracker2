import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/upi_launcher.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/expense_card.dart';
import '../widgets/payment_prompt_sheet.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int tab) onGoToTab;

  const HomeScreen({super.key, required this.onGoToTab});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _launchApp(
      BuildContext context, AppState state, UpiApp app) async {
    final ok = await UpiLauncher.launch(app);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '${app.name} opened. Pay there, then come back here.'
          : 'Could not open ${app.name}. Is it installed?'),
    ));
  }

  Future<void> _logManually(BuildContext context, AppState state) async {
    final expense = await showPaymentPromptSheet(context, state: state);
    if (expense == null || !context.mounted) return;
    await state.saveExpense(expense);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Saved ${formatMoney(expense.amount, symbol: state.currencySymbol)}'
          '${expense.payee.isEmpty ? '' : ' for ${expense.payee}'}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monthTotal = state.spentThisMonth();
    final recent = state.expenses.take(5).toList();
    final overallBudget = state.budgets.where((b) => b.category.isEmpty).toList();
    final budget = overallBudget.isEmpty ? null : overallBudget.first;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            Text(_greeting,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.outline)),
            const SizedBox(height: 2),
            Text('Let\'s track your spending.',
                style: Theme.of(context).textTheme.titleLarge),

            const SizedBox(height: 16),
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spent in ${monthLabel(now)}',
                        style: TextStyle(color: scheme.onPrimaryContainer)),
                    const SizedBox(height: 6),
                    Text(
                      formatMoney(monthTotal, symbol: state.currencySymbol),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800),
                    ),
                    if (budget != null) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: (monthTotal / budget.amount)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                        backgroundColor: scheme.onPrimaryContainer.withOpacity(0.15),
                        color: monthTotal > budget.amount
                            ? scheme.error
                            : scheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        monthTotal > budget.amount
                            ? 'Over budget by ${formatMoney(monthTotal - budget.amount, symbol: state.currencySymbol)}'
                            : '${formatMoney(budget.amount - monthTotal, symbol: state.currencySymbol)} left of ${formatMoney(budget.amount, symbol: state.currencySymbol)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text('Pay with', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Pick a UPI app, pay as usual, then come back here.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.outline)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
              children: UpiLauncher.apps.map((app) {
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _launchApp(context, state, app),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: app.color,
                            child: Icon(app.icon, color: Colors.white, size: 24),
                          ),
                          const SizedBox(height: 8),
                          Text(app.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            if (state.dueReminders.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Due now', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...state.dueReminders.map((r) {
                final due = nextDueDate(r, now);
                final dueLabel = r.frequency == 'weekly'
                    ? 'Every ${weekdayName(r.dayOf)}'
                    : 'Due ${formatDate(due ?? now).split(',').first}';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.event_repeat)),
                    title: Text(r.title),
                    subtitle: Text(
                        '${formatMoney(r.amount, symbol: state.currencySymbol)}'
                        ' · $dueLabel'),
                    trailing: FilledButton.tonal(
                      onPressed: () => state.logReminder(r),
                      child: const Text('Log paid'),
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent', style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                    onPressed: () => onGoToTab(1),
                    child: const Text('See all')),
              ],
            ),
            if (recent.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No expenses yet',
                subtitle:
                    'Tap a UPI app above, pay, come back, and log what it was for.',
              )
            else
              ...recent.map((e) => ExpenseCard(
                    expense: e,
                    state: state,
                    onTap: () => onGoToTab(1),
                  )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _logManually(context, state),
        icon: const Icon(Icons.add),
        label: const Text('Log payment'),
      ),
    );
  }
}
