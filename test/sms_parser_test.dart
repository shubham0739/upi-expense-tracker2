import 'package:flutter_test/flutter_test.dart';
import 'package:upi_expense_tracker/models/models.dart';
import 'package:upi_expense_tracker/utils/categories.dart';

void main() {
  test('extractAmount parses typical UPI debit SMS formats', () {
    expect(extractAmount('Dear Customer, A/c XX1234 debited with Rs.200.00 on 02-10-26. Info: UPI/123456789012. Avl bal Rs.5000.00.'), 200.0);
    expect(extractAmount('Your a/c XX1234 debited INR 1,250 on 02-10-26 (UPI Ref 123456789012)'), 1250.0);
    expect(extractAmount('Rs 45.50 paid from your account via UPI'), 45.5);
    expect(extractAmount('no money mentioned here'), null);
  });

  test('extractPayee finds VPA and paid-to names', () {
    expect(extractPayee('Info: UPI/1234/VPA/swiggy@ybl.'), 'swiggy@ybl');
    expect(extractPayee('You paid to Sharma Store via UPI on 02-10-26'), 'Sharma Store');
  });

  test('inferCategory suggests a category from payee keywords', () {
    expect(inferCategory('zomato'), 'Food');
    expect(inferCategory('Uber Trip'), 'Travel');
    expect(inferCategory('apollo pharmacy'), 'Health');
    expect(inferCategory('unknown payee'), 'Other');
  });

  test('nextDueDate computes the next monthly occurrence', () {
    final r = Reminder(title: 'Rent', frequency: 'monthly', dayOf: 5);
    final due = nextDueDate(r, DateTime(2026, 10, 10));
    expect(due, DateTime(2026, 11, 5));
  });

  test('nextDueDate handles today falling on the due day', () {
    final r = Reminder(title: 'Rent', frequency: 'monthly', dayOf: 10);
    final due = nextDueDate(r, DateTime(2026, 10, 10));
    expect(due, DateTime(2026, 10, 10));
  });

  test('nextDueDate weekly picks the next matching weekday', () {
    // 2026-10-02 is a Friday (weekday 5). Ask for Tuesday (2).
    final r = Reminder(title: 'Gym', frequency: 'weekly', dayOf: 2);
    expect(nextDueDate(r, DateTime(2026, 10, 2)), DateTime(2026, 10, 6));
  });
}
