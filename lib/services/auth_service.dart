import 'package:shared_preferences/shared_preferences.dart';

/// Mock phone-registration service for the demo.
///
/// Access is restricted to an allowlist of phone numbers. It persists the
/// registered phone locally and validates a fixed demo OTP. To go to
/// production, replace [sendCode] / [verifyCode] with Firebase Phone Auth
/// (verifyPhoneNumber / signInWithCredential) — the rest of the UI can stay
/// exactly as-is.
class AuthService {
  static const _kPhoneKey = 'welhof.registered_phone';
  static const demoOtp = '1234';

  /// Phone numbers permitted to register (demo allowlist), stored normalized
  /// (Dutch national number without country code or leading zero).
  static const List<String> allowedNumbers = <String>['610000000'];

  /// Normalizes a Dutch number to its national significant digits:
  /// strips spaces/symbols, a `+31`/`0031`/`31` country code and a leading 0.
  /// e.g. `0610000000`, `+31 6 10000000`, `06-10000000` → `610000000`.
  static String normalize(String input) {
    var d = input.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0031')) {
      d = d.substring(4);
    } else if (d.startsWith('31')) {
      d = d.substring(2);
    }
    if (d.startsWith('0')) d = d.substring(1);
    return d;
  }

  /// Whether [phone] is on the allowlist.
  bool isAllowed(String phone) => allowedNumbers.contains(normalize(phone));

  /// Pretends to send an SMS code. Returns after a short delay.
  Future<void> sendCode(String phoneNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    // In production: trigger FirebaseAuth.instance.verifyPhoneNumber(...)
  }

  /// Verifies the code and, on success, stores the phone as registered.
  /// Rejects numbers that are not on the allowlist.
  Future<bool> verifyCode(String phoneNumber, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!isAllowed(phoneNumber)) return false;
    if (code.trim() != demoOtp) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPhoneKey, phoneNumber);
    return true;
  }

  /// Returns the registered phone number, or null if not signed in.
  Future<String?> registeredPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPhoneKey);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPhoneKey);
  }
}
