import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/expense_card.dart';
import '../widgets/month_selector.dart';
import '../widgets/payment_prompt_sheet.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _search = TextEditingController();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _categoryFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Expense> _filtered(AppState state) {
    final key = monthKey(_month);
    final q = _search.text.trim().toLowerCase();
    return state.expenses.where((e) {
      if (monthKey(e.date) != key) return false;
      if (_categoryFilter != null && e.category != _categoryFilter) return false;
      if (q.isNotEmpty &&
          !e.payee.toLowerCase().contains(q) &&
          !e.note.toLowerCase().contains(q) &&
          !e.category.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _edit(AppState state, Expense e) async {
    final updated =
        await showPaymentPromptSheet(context, state: state, initial: e);
    if (updated == null) return;
    await state.saveExpense(updated);
  }

  Future<bool> _confirmDelete(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
            '${formatMoney(e.amount)} · ${e.payee.isEmpty ? e.category : e.payee}'),
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
    return ok ?? false;
  }

  String _groupLabel(String day) {
    final d = DateTime.parse(day);
    final today = DateTime.now();
    if (day == dayKey(today)) return 'Today';
    if (day == dayKey(today.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return formatDate(d).split(',').first;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final filtered = _filtered(state);
    final total = filtered.fold(0.0, (s, e) => s + e.amount);

    final groups = <String, List<Expense>>{};
    for (final e in filtered) {
      groups.putIfAbsent(dayKey(e.date), () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search payee, note, category…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            MonthSelector(
              month: _month,
              onChanged: (m) => setState(() => _month = m),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _categoryFilter == null,
                      onSelected: (_) =>
                          setState(() => _categoryFilter = null),
                    ),
                  ),
                  ...state.categories.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(c.name),
                          selected: _categoryFilter == c.name,
                          onSelected: (_) => setState(
                              () => _categoryFilter = c.name),
                        ),
                      )),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off,
                      title: 'Nothing here',
                      subtitle: 'Try a different month or filter.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 4),
                            child: Text(
                              _groupLabel(entry.key),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                            ),
                          ),
                          ...entry.value.map((e) => Dismissible(
                                key: ValueKey('exp-${e.id ?? e.createdAt}'),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) => _confirmDelete(e),
                                onDismissed: (_) => state.deleteExpense(e.id!),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.delete_outline,
                                      color: Colors.white),
                                ),
                                child: ExpenseCard(
                                  expense: e,
                                  state: state,
                                  onTap: () => _edit(state, e),
                                ),
                              )),
                        ],
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            '${filtered.length} entries · ${formatMoney(total, symbol: state.currencySymbol)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context).colorScheme.outline),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
