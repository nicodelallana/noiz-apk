import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'presentation/providers/saved_trips_providers.dart';
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
class BizkaiaTransitApp extends ConsumerStatefulWidget {
  const BizkaiaTransitApp({super.key});

  @override
  ConsumerState<BizkaiaTransitApp> createState() => _BizkaiaTransitAppState();
}

class _BizkaiaTransitAppState extends ConsumerState<BizkaiaTransitApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _initHomeWidgetInteractions();

    _lifecycleListener = AppLifecycleListener(
      onPause: () {
        ref.read(widgetUpdateServiceProvider).update();
      },
      onDetach: () {
        ref.read(widgetUpdateServiceProvider).update();
      },
    );
  }

  void _initHomeWidgetInteractions() {
    // Initial launch via widget tap
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null) {
        _handleWidgetUri(uri);
      }
    });

    // Stream when app is already running in background
    HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        _handleWidgetUri(uri);
      }
    });
  }

  void _handleWidgetUri(Uri uri) {
    debugPrint('Launched from home widget with uri: $uri');
    // Deep links formatted as bizkaiatransit://trip/{id} or bizkaiatransit://departures
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

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
