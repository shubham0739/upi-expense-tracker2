import 'package:flutter/material.dart';

import '../utils/format.dart';

/// Chevron-based month selector shared by History and Analytics.
class MonthSelector extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  const MonthSelector({
    super.key,
    required this.month,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1, 1)),
        ),
        Text(
          monthLabel(month),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(DateTime(month.year, month.month + 1, 1)),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => onChanged(DateTime(DateTime.now().year, DateTime.now().month, 1)),
          child: Text('This month',
              style: TextStyle(color: scheme.primary)),
        ),
      ],
    );
  }
}
