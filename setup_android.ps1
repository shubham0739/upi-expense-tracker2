# Sets up the Android platform scaffolding for UPI Expense Tracker.
#
# Run from the project root AFTER installing Flutter:
#   pwsh ./setup_android.ps1
#
# It generates the canonical Android files with `flutter create`, then applies
# the app's customizations (SMS permission + package queries in the manifest,
# the SMS-reading platform channel in MainActivity.kt, and minSdk 23).

$ErrorActionPreference = 'Stop'

Write-Host '1/5 Generating Android scaffolding (flutter create)...' -ForegroundColor Cyan
flutter create --org com.akash.upitracker --project-name upi_expense_tracker --platforms android .

Write-Host '2/5 Applying AndroidManifest override (READ_SMS + UPI package queries)...' -ForegroundColor Cyan
Copy-Item -Force platform_overrides/android/app/src/main/AndroidManifest.xml android/app/src/main/AndroidManifest.xml

Write-Host '3/5 Applying MainActivity override (SMS platform channel)...' -ForegroundColor Cyan
$overrideKt = 'platform_overrides/android/app/src/main/kotlin/com/akash/upitracker/upi_expense_tracker/MainActivity.kt'
$existing = @(Get-ChildItem -Recurse -Filter MainActivity.kt android/app/src/main/kotlin -ErrorAction SilentlyContinue)
if ($existing.Count -eq 0) {
    $targetDir = 'android/app/src/main/kotlin/com/akash/upitracker/upi_expense_tracker'
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Copy-Item -Force $overrideKt (Join-Path $targetDir 'MainActivity.kt')
    Write-Host "  (no existing MainActivity found; wrote to $targetDir)"
} else {
    foreach ($f in $existing) {
        Copy-Item -Force $overrideKt $f.FullName
        Write-Host "  (overwrote $($f.FullName))"
    }
}

Write-Host '4/5 Bumping minSdk to 23...' -ForegroundColor Cyan
$gradle = 'android/app/build.gradle.kts'
if (Test-Path $gradle) {
    $content = Get-Content $gradle -Raw
    if ($content -match 'minSdk = flutter\.minSdkVersion') {
        $content = $content -replace 'minSdk = flutter\.minSdkVersion', 'minSdk = 23'
        Set-Content $gradle $content -NoNewline
        Write-Host '  (minSdk set to 23)'
    } elseif ($content -match 'minSdk\s*=\s*23') {
        Write-Host '  (minSdk already 23)'
    } else {
        Write-Host "  (!) Could not find minSdk line - please set minSdk = 23 in $gradle manually" -ForegroundColor Yellow
    }
} else {
    Write-Host "  (!) $gradle not found - please set minSdk = 23 manually" -ForegroundColor Yellow
}

Write-Host '5/5 Done.' -ForegroundColor Green
Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Green
Write-Host '  flutter pub get'
Write-Host '  flutter run    (with a phone connected or an emulator running)'
