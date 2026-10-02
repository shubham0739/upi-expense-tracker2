import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/sms_service.dart';
import '../state/app_state.dart';
import 'reminders_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _currency;

  @override
  void initState() {
    super.initState();
    _currency = TextEditingController(
        text: context.read<AppState>().currencySymbol);
  }

  @override
  void dispose() {
    _currency.dispose();
    super.dispose();
  }

  Future<void> _toggleSms(AppState state, bool value) async {
    if (value) {
      final granted = await SmsService.instance.requestPermission();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'SMS permission denied. Detection is on, but no payments will be '
              'detected until you allow it in system settings.'),
        ));
      }
    }
    await state.setSmsAutoDetect(value);
  }

  Future<void> _export(AppState state) async {
    final path = await state.exportCsv();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(path != null
          ? 'CSV saved to $path'
          : 'Export cancelled'),
    ));
  }

  Future<void> _clearAll(AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
            'This removes every expense, budget, reminder and custom category '
            'from this device. It cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete everything')),
        ],
      ),
    );
    if (ok == true) await state.clearAllData();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('Payment detection',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Auto-detect from UPI SMS'),
                    subtitle: const Text(
                        'After you return from a UPI app, read the bank\'s '
                        'confirmation SMS to pre-fill amount and payee. '
                        'You can always correct or type it manually.'),
                    value: state.smsAutoDetect,
                    onChanged: (v) => _toggleSms(state, v),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: FutureBuilder<bool>(
                      future: SmsService.instance.hasPermission,
                      builder: (context, snapshot) {
                        final granted = snapshot.data ?? false;
                        return Row(
                          children: [
                            Icon(
                              granted
                                  ? Icons.verified_outlined
                                  : Icons.info_outline,
                              size: 16,
                              color: granted
                                  ? const Color(0xFF43A047)
                                  : scheme.outline,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              granted
                                  ? 'SMS permission: granted'
                                  : 'SMS permission: not granted',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.outline),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Preferences', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Currency symbol'),
                    subtitle: const Text('Shown before every amount.'),
                    trailing: SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _currency,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8),
                        ),
                        onSubmitted: (v) => state.setCurrencySymbol(v),
                      ),
                    ),
                    onTap: () async {
                      await state.setCurrencySymbol(_currency.text);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Currency saved')));
                    },
                  ),
                  ListTile(
                    title: const Text('Theme'),
                    subtitle: Text(
                        state.themeMode == ThemeMode.dark
                            ? 'Dark'
                            : state.themeMode == ThemeMode.light
                                ? 'Light'
                                : 'System'),
                    trailing: DropdownButton<ThemeMode>(
                      value: state.themeMode,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                            value: ThemeMode.system, child: Text('System')),
                        DropdownMenuItem(
                            value: ThemeMode.light, child: Text('Light')),
                        DropdownMenuItem(
                            value: ThemeMode.dark, child: Text('Dark')),
                      ],
                      onChanged: (v) {
                        if (v != null) state.setThemeMode(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Data', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.event_repeat),
                    title: const Text('Recurring reminders'),
                    subtitle: const Text('Rent, EMIs, subscriptions…'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const RemindersScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Export as CSV'),
                    subtitle: const Text('Save all expenses to Downloads and share.'),
                    onTap: () => _export(state),
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined,
                        color: scheme.error),
                    title: Text('Delete all data',
                        style: TextStyle(color: scheme.error)),
                    onTap: () => _clearAll(state),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('About', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('How it works',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      '1. Tap a UPI app on the Home tab — it opens.\n'
                      '2. Pay there as you normally would.\n'
                      '3. Come back here: the app asks what you paid for and '
                      'pre-fills the amount from your bank\'s SMS (when '
                      'enabled).\n'
                      '4. Confirm — it\'s saved with the amount, payee, '
                      'category and date.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: scheme.outline),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'All data stays on your device. The app has no '
                            'network permission and no analytics.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.outline),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('UPI Expense Tracker · v1.0.0',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.outline)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
