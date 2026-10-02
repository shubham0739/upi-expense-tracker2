import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upi_expense_tracker/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState renders its icon and text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nothing here',
          subtitle: 'Yet',
        ),
      ),
    ));
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Yet'), findsOneWidget);
  });
}
