import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/navigation/transport_mode_fab.dart';
import 'presentation/providers/saved_trips_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with compile-time environment variables.
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

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
    final router = ref.watch(goRouterProvider);
    final transportMode = ref.watch(transportModeProvider);
    final isBus = transportMode == TransportMode.bus;

    return MaterialApp.router(
      title: 'Noiz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(isBus: isBus),
      routerConfig: router,
    );
  }
}
