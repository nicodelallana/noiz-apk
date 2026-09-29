import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BizkaiaTransitApp());
}

/// Root application widget for Bizkaia Transit.
class BizkaiaTransitApp extends StatelessWidget {
  const BizkaiaTransitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bizkaia Transit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE30613)),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Bizkaia Transit — Inicializando...'),
        ),
      ),
    );
  }
}
