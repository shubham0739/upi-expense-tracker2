# UPI Expense Tracker (Flutter · Android)

A UPI-first expense tracker. The core flow is exactly the one you described:

1. Open the app → tap a UPI app (**Google Pay, PhonePe, Paytm, BHIM, Amazon Pay**).
2. That app opens. You pay there normally — scan a QR at the restaurant, whatever.
3. You come back to this app. It asks **"What did you pay for?"** — with the
   amount and payee already filled in from your bank's UPI confirmation SMS
   (when enabled) — and you pick a category (e.g. *Food*).
4. The expense is saved: *₹200 paid to the restaurant, Food, via PhonePe, 2 Oct 2026*.

## Features

| Area | What you get |
| --- | --- |
| **Core flow** | UPI app launcher grid → pay → return → "what did you pay for?" sheet |
| **Auto-detect** | Reads the bank's UPI SMS to pre-fill amount + payee, with a toggle in Settings (manual entry always available) |
| **Smart categories** | Payee keywords (swiggy → Food, uber → Travel, amazon → Shopping…) auto-suggest the category; custom categories supported |
| **History** | Search, month navigation, category filters, grouped by day, swipe to delete, tap to edit |
| **Analytics** | Category pie chart, day-by-day bars, 6-month trend line, top payees |
| **Budgets** | Overall or per-category, monthly or weekly, progress bars and over-budget alerts |
| **Reminders** | Recurring payments (rent, EMIs, subscriptions) with "Log paid" when due |
| **Export** | CSV of everything to Downloads + Android share sheet |
| **Privacy** | Everything stays on your device — no network permission, no analytics |

## 📱 Get it on your phone — cloud build (no Flutter on your PC)

The easiest way to get the app on your Android phone: let GitHub's free cloud
computers build the APK for you. You don't install anything on your PC —
just upload the project and download the finished file.

1. **Create a free GitHub account** at <https://github.com/signup> (if you
   don't have one).
2. **Create a new repository**: click **+ → New repository** → name it
   `upi-expense-tracker` → choose **Public** → **Create repository**.
3. **Upload the project**: on the repo page click **uploading an existing
   file** → open this project's folder on your PC → select **everything
   inside it** (Ctrl+A) → drag the selection into the upload area → **Commit
   changes**.
   ⚠️ Drag the *contents* of the folder, not the folder itself.
4. **The build starts automatically** after the upload. Watch it at
   **Actions** → "Build APK" (click "I understand my workflows" the first
   time). It takes about 5–8 minutes. You can also re-run it anytime with
   the **Run workflow** button.
5. **Download the APK**: when the run is green, click it → scroll to
   **Artifacts** → download `upi-expense-tracker-apk` (a zip) → extract →
   `app-release.apk`.
6. **Get it onto the phone** — any of these:
   - USB cable: copy `app-release.apk` to the phone's Downloads folder;
   - send it to yourself via WhatsApp / Telegram / Google Drive; or
   - on the phone, log into GitHub in Chrome, download the same artifact,
     and extract it with **Files by Google** or **ZArchiver**.
7. **Install**: tap the APK → allow **install from unknown sources** for
   that app → if Play Protect warns, tap **Install anyway** → open
   **UPI Expense Tracker**.
8. **First use**: go to the Settings tab → turn on **Auto-detect from UPI
   SMS** → allow the SMS permission when asked. Make sure your UPI apps
   (GPay/PhonePe/Paytm…) are installed on the phone.

Notes:

- The APK is signed with a default key — perfectly fine for personal use.
- The repo only contains code; your expense data lives on your phone, and the
  app has no network permission at all.
- Changed your mind about something in the code? Re-upload the changed files
  and the workflow rebuilds automatically.

## Requirements

- **Flutter 3.22+** (Dart 3.4+), Android Studio with the Android SDK, a JDK
- An Android phone (a real phone with UPI apps and a SIM is needed for the full
  SMS-detection experience; an emulator works for manual logging)

## Setup

```powershell
# 1. From this folder, fetch dependencies
flutter pub get

# 2. Generate Android scaffolding and apply the app's customizations
pwsh ./setup_android.ps1

# 3. Run on a connected device / emulator
flutter run
```

`setup_android.ps1` runs `flutter create` to produce the standard Android
project files, then applies:

- `AndroidManifest.xml` — `READ_SMS` permission + `<queries>` for Android 11+
  package visibility of the UPI apps (from `platform_overrides/`)
- `MainActivity.kt` — the platform channel that reads the SMS inbox
  (`com.akash.upitracker/sms`)
- `minSdk = 23` in `android/app/build.gradle.kts`

## Building an APK

```powershell
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

Copy it to your phone and install it (allow "install from unknown sources").
The app is signed with the debug key by default — fine for personal use.

## Permissions & privacy notes

- The app requests **SMS access** only when you turn on auto-detection in
  Settings. If you deny it, everything else still works — you just type the
  amount yourself.
- Google Play restricts apps that read SMS. This app is intended for **personal
  use / sideloading**; if you ever want to publish it, remove the SMS feature
  first or prepare a justification.
- All data lives in a local SQLite database on the device. There is no network
  permission at all.

## How SMS auto-detection works

When you tap a UPI app on the home screen, the app remembers the launch time.
When you come back (the app detects the resume), it queries the SMS inbox for
messages since that moment that look like UPI payment confirmations
(`"debited"`, `"UPI"`, `"paid to"`), parses the amount
(`Rs.200.00` / `INR 1,250` / `₹45.50`) and payee, and shows the best
candidates in the "What did you pay for?" sheet. Picking one pre-fills the
form; the SMS id is stored so the same message is never logged twice.

Banks may deliver the SMS a few seconds late, so the lookup also runs from the
launch timestamp rather than only from the resume moment.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `gradle` sync or build errors after setup | Delete the `android/` folder and re-run `pwsh ./setup_android.ps1`. Make sure your JDK is version 17+. |
| Build fails on `compileSdk` / `minSdk` | Open `android/app/build.gradle.kts` and set `compileSdk = 34` and `minSdk = 23`. |
| No SMS is detected | Check the toggle in Settings, grant SMS permission there (or in Android app settings), and make sure your bank actually sends SMS confirmations. Manual entry always works. |
| A UPI app won't open | The package name may have changed with an app update. Edit the list in `lib/services/upi_launcher.dart` and rebuild. |
| "App not installed" for a UPI app | Install that UPI app on the phone, or tap a different one. |
| SMS permission dialog never appears | Some ROMs (MIUI etc.) need the permission granted manually in Settings → Apps → UPI Expense Tracker → Permissions. |

## Project structure

```
lib/
  main.dart                     app entry + bottom-nav shell + resume detection
  models/models.dart            Expense, Budget, Reminder, UpiApp, SMS parsing
  data/database.dart            SQLite schema
  state/app_state.dart          central state, queries, return-from-UPI flow
  services/upi_launcher.dart    UPI app registry + launching
  services/sms_service.dart     SMS platform-channel bridge
  services/csv_export.dart      CSV + share
  screens/                      home, history, analytics, budgets, reminders, settings
  widgets/                      payment prompt sheet, expense card, etc.
  utils/                        money/date formatting, categories & inference
platform_overrides/             Android manifest + MainActivity applied by setup script
test/                           unit tests for SMS parsing, due dates, categories
```

## Customizing

- **Add another UPI app**: append to `UpiLauncher.apps` in
  `lib/services/upi_launcher.dart` and add its package to `<queries>` in
  `platform_overrides/android/app/src/main/AndroidManifest.xml`.
- **Change categories**: edit `defaultCategories` in `lib/utils/categories.dart`.
- **Change currency**: Settings → currency symbol (default ₹).
