# Welhof App

Flutter demo app for Welhof. Users get access by registering a phone number,
then reach two demo features from the home dashboard:

- **Barcode scanner** (`mobile_scanner`)
- **Photo capture** (`image_picker` — camera or gallery)

## Screens

| Flow | File |
| --- | --- |
| Phone registration | `lib/screens/registration_screen.dart` |
| OTP verification | `lib/screens/otp_screen.dart` |
| Home dashboard | `lib/screens/home_screen.dart` |
| Barcode scanner | `lib/screens/scanner_screen.dart` |
| Photo capture | `lib/screens/photo_screen.dart` |
| Mock auth / session | `lib/services/auth_service.dart` |

## Demo login

Phone auth is **mocked** so the demo runs offline with no backend:

1. Enter any Dutch mobile number (e.g. `6 12 34 56 78`).
2. Enter the demo OTP: **`1234`**.

The session (registered phone) is persisted with `shared_preferences`, so the
app opens straight to the dashboard on the next launch. Use the logout button
(top-right of the dashboard) to reset.

## Setup

Flutter must be installed and on `PATH`
(<https://docs.flutter.dev/get-started/install/windows>). Then, from this
folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

`setup.ps1` generates the native Android/iOS projects, re-applies the app
source, adds the camera/photo permissions, and runs `flutter pub get`.

Then run on a connected device or emulator:

```powershell
flutter run
```

> Barcode scanning and camera capture require a **physical device** (emulators
> have no real camera).

## Going to production (real phone auth)

Swap the mock in `lib/services/auth_service.dart` for Firebase Phone Auth:

- `sendCode()` → `FirebaseAuth.instance.verifyPhoneNumber(...)`
- `verifyCode()` → build a `PhoneAuthCredential` and `signInWithCredential(...)`

The UI (`registration_screen.dart` / `otp_screen.dart`) needs no changes — it
only calls those two methods.
