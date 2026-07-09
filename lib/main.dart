import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'screens/registration_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(const WelhofApp());
}

class WelhofApp extends StatelessWidget {
  const WelhofApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welhof',
      debugShowCheckedModeBanner: false,
      theme: buildWelhofTheme(),
      home: const _Gate(),
    );
  }
}

/// Decides the first screen based on whether a phone is already registered.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  final _auth = AuthService();
  late Future<String?> _phoneFuture;

  @override
  void initState() {
    super.initState();
    _phoneFuture = _auth.registeredPhone();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _phoneFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final phone = snapshot.data;
        if (phone == null) {
          return const RegistrationScreen();
        }
        return HomeScreen(phoneNumber: phone);
      },
    );
  }
}
