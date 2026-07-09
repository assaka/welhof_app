# Welhof app — one-time setup.
# Scaffolds the native Android/iOS projects around the Dart source in lib/,
# then re-applies the app source and the camera/photo permissions.
#
# Run once from this folder:   powershell -ExecutionPolicy Bypass -File .\setup.ps1

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter is not on PATH. Install it first: https://docs.flutter.dev/get-started/install/windows"
}

Write-Host "==> Backing up app source..." -ForegroundColor Cyan
$backup = Join-Path $env:TEMP "welhof_app_src_backup"
if (Test-Path $backup) { Remove-Item $backup -Recurse -Force }
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item (Join-Path $root "pubspec.yaml") $backup
Copy-Item (Join-Path $root "lib") (Join-Path $backup "lib") -Recurse

Write-Host "==> Generating native scaffolding (flutter create)..." -ForegroundColor Cyan
& flutter create --org com.welhof --project-name welhof_app --platforms=android,ios .

Write-Host "==> Restoring app source over the generated template..." -ForegroundColor Cyan
Copy-Item (Join-Path $backup "pubspec.yaml") (Join-Path $root "pubspec.yaml") -Force
Remove-Item (Join-Path $root "lib") -Recurse -Force
Copy-Item (Join-Path $backup "lib") (Join-Path $root "lib") -Recurse -Force

# ---- Android permissions ----
$manifest = Join-Path $root "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifest) {
    Write-Host "==> Patching AndroidManifest.xml (camera)..." -ForegroundColor Cyan
    $m = Get-Content $manifest -Raw
    if ($m -notmatch "android.permission.CAMERA") {
        $perms = @'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
'@
        $m = $m -replace '<manifest xmlns:android="http://schemas.android.com/apk/res/android">', $perms
        Set-Content $manifest $m -Encoding UTF8
    }
}

# ---- iOS permissions ----
$plist = Join-Path $root "ios\Runner\Info.plist"
if (Test-Path $plist) {
    Write-Host "==> Patching iOS Info.plist (camera + photos)..." -ForegroundColor Cyan
    $p = Get-Content $plist -Raw
    if ($p -notmatch "NSCameraUsageDescription") {
        $keys = @'
	<key>NSCameraUsageDescription</key>
	<string>De Welhof-app gebruikt de camera om barcodes te scannen en foto's te maken.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>De Welhof-app heeft toegang tot je fotobibliotheek nodig om een foto te kiezen.</string>
</dict>
'@
        $p = $p -replace '</dict>\s*</plist>', "$keys`n</plist>"
        Set-Content $plist $p -Encoding UTF8
    }
}

Write-Host "==> Fetching packages (flutter pub get)..." -ForegroundColor Cyan
& flutter pub get

Write-Host ""
Write-Host "Done. Connect a device and run:  flutter run" -ForegroundColor Green
