import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/screens/metro/metro_departures_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: BizkaiaTransitApp(),
    ),
  );
}

/// Root application widget for Bizkaia Transit.
class BizkaiaTransitApp extends StatelessWidget {
  const BizkaiaTransitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bizkaia Transit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE30613)),
        useMaterial3: true,
      ),
      home: const MetroDeparturesScreen(),
    );
  }
}
