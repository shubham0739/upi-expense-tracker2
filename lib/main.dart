import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/models.dart';
import 'screens/analytics_screen.dart';
import 'screens/budgets_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'utils/format.dart';
import 'widgets/payment_prompt_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();
  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const UpiTrackerApp(),
    ),
  );
}

class UpiTrackerApp extends StatelessWidget {
  const UpiTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'UPI Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: state.themeMode,
      home: const RootShell(),
    );
  }
}

/// Bottom-navigation shell. Also watches app lifecycle so it can ask
/// "what did you pay for?" whenever the user comes back from a UPI app.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int _tab = 0;
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appState == null) {
      _appState = context.read<AppState>();
      _appState!.returnPrompt.addListener(_onReturnPrompt);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appState?.returnPrompt.removeListener(_onReturnPrompt);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appState?.handleReturnToApp();
    }
  }

  void _onReturnPrompt() {
    final appState = _appState;
    if (appState == null) return;
    final prompt = appState.returnPrompt.value;
    if (prompt == null) return;
    appState.returnPrompt.value = null;
    _askWhatWasItFor(prompt);
  }

  Future<void> _askWhatWasItFor(ReturnPromptData prompt) async {
    final appState = _appState;
    if (appState == null) return;
    final expense = await showPaymentPromptSheet(
      context,
      state: appState,
      candidates: prompt.candidates,
      appId: prompt.appId,
    );
    if (expense == null) return;
    await appState.saveExpense(expense);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Saved ${formatMoney(expense.amount, symbol: appState.currencySymbol)}'
          '${expense.payee.isEmpty ? '' : ' for ${expense.payee}'}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onGoToTab: _goToTab),
      const HistoryScreen(),
      const AnalyticsScreen(),
      const BudgetsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'History'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: 'Budgets'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  void _goToTab(int i) => setState(() => _tab = i);
}
