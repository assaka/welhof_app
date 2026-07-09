import 'package:shared_preferences/shared_preferences.dart';

/// Mock phone-registration service for the demo.
///
/// It persists the registered phone number locally and validates a fixed
/// demo OTP. To go to production, replace [sendCode] / [verifyCode] with
/// Firebase Phone Auth (verifyPhoneNumber / signInWithCredential) — the rest
/// of the UI can stay exactly as-is.
class AuthService {
  static const _kPhoneKey = 'welhof.registered_phone';
  static const demoOtp = '1234';

  /// Pretends to send an SMS code. Returns after a short delay.
  Future<void> sendCode(String phoneNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    // In production: trigger FirebaseAuth.instance.verifyPhoneNumber(...)
  }

  /// Verifies the code and, on success, stores the phone as registered.
  Future<bool> verifyCode(String phoneNumber, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
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
