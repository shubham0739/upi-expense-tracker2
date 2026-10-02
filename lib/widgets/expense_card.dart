import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

/// One expense row: category icon, payee/category title, meta line, amount.
class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final AppState state;
  final VoidCallback onTap;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final catColor = state.categoryColor(expense.category);
    final catIcon = state.categoryIcon(expense.category);
    final title = expense.payee.isEmpty ? expense.category : expense.payee;
    final meta = [
      expense.category,
      if (expense.paidVia.isNotEmpty) expense.paidVia,
      formatDate(expense.date),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: catColor.withOpacity(0.15),
          child: Icon(catIcon, color: catColor, size: 20),
        ),
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(
          formatMoney(expense.amount, symbol: state.currencySymbol),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: scheme.error,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
