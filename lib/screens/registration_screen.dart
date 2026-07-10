import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import 'otp_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _auth = AuthService();
  // Prefilled with the allowed demo number.
  final _controller = TextEditingController(text: '0610000000');
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    final phone = _controller.text.trim();
    await _auth.sendCode(phone);
    if (!mounted) return;
    setState(() => _sending = false);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OtpScreen(phoneNumber: phone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: WelhofColors.brand,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.chair_alt_rounded,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 28),
                Text(
                  'Welkom bij Welhof',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: WelhofColors.ink,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Registreer met je telefoonnummer om toegang te krijgen.',
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _controller,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 +\-]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Telefoonnummer',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '0612345678',
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (AuthService.normalize(v).length < 9) {
                      return 'Voer een geldig telefoonnummer in';
                    }
                    if (!_auth.isAllowed(v)) {
                      return 'Dit nummer heeft geen toegang tot de app';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _sending ? null : _submit,
                  child: _sending
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verstuur code'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Demo: alleen 0610000000 heeft toegang. Code 1234.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
