import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/glass/aurora_background.dart';
import '../../widgets/glass/content.dart';
import '../../widgets/glass/glass_surface.dart';
import '../../widgets/glass/motion.dart';
import '../auth/auth_screen.dart';
import '../legal/legal_texts.dart';

final _text = AppTypography.textTheme();

/// Onboarding shown when the user is not signed in.
///
/// - 3 feature pages, each with a floating glass preview over the aurora
/// - Final sign-in page with Google / Apple buttons
/// - "Saltar" and "Continuar sin cuenta" both finish onboarding as a guest
/// - Morphing capsule page indicator
/// - Respects reduced motion (no parallax, no page animation)
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _totalPages = 4;

  /// Third aurora glow per page: it drifts to the colour of what the page
  /// talks about.
  static const _pageGlow = [
    AppColors.opMetroBilbao,
    AppColors.opBizkaibus,
    AppColors.accent,
    AppColors.accent,
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      if (Motion.reduced(context)) {
        _pageController.jumpToPage(_currentPage + 1);
      } else {
        _pageController.animateToPage(
          _currentPage + 1,
          duration: Motion.smooth.duration,
          curve: Motion.smooth.curve,
        );
      }
    }
  }

  void _skip() {
    ref.read(onboardingCompletedProvider.notifier).state = true;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _totalPages - 1;

    return AuroraBackground(
      accent: _pageGlow[_currentPage],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Skip
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GlassButton(
                    kind: GlassKind.clear,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    onPressed: _skip,
                    child: Text(
                      'Saltar',
                      style: _text.labelLarge!.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ),
              ),

              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [
                    _FeaturePage(
                      index: 0,
                      controller: _pageController,
                      preview: const _DeparturePreview(),
                      title: 'Metro y bus de un vistazo',
                      description:
                          'Consulta las próximas salidas de Metro Bilbao y '
                          'Bizkaibus según su horario.',
                    ),
                    _FeaturePage(
                      index: 1,
                      controller: _pageController,
                      preview: const _SavedTripsPreview(),
                      title: 'Guarda tus viajes',
                      description:
                          'Marca tus trayectos habituales y ábrelos con un '
                          'toque.',
                    ),
                    _FeaturePage(
                      index: 2,
                      controller: _pageController,
                      preview: const _WidgetPreview(),
                      title: 'Widget en tu pantalla',
                      description:
                          'Añade un widget a tu pantalla de inicio para ver '
                          'horarios sin abrir la app.',
                    ),
                    const _SignInPage(),
                  ],
                ),
              ),

              // Bottom controls: indicator + one full-width action. The slot
              // keeps its height on every page so the pages never jump.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PageIndicator(
                      currentPage: _currentPage,
                      totalPages: _totalPages,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: isLast
                          ? GlassButton(
                              kind: GlassKind.clear,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              onPressed: _skip,
                              child: Center(
                                child: Text(
                                  'Continuar sin cuenta',
                                  style: _text.titleMedium!.copyWith(
                                    color: AppColors.darkTextPrimary,
                                  ),
                                ),
                              ),
                            )
                          : GlassButton(
                              tint: AppColors.accent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              onPressed: _nextPage,
                              child: Center(
                                child: Text(
                                  _currentPage == _totalPages - 2
                                      ? 'Empezar'
                                      : 'Siguiente',
                                  style: _text.titleMedium!.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feature introduction page
// ---------------------------------------------------------------------------

class _FeaturePage extends StatelessWidget {
  const _FeaturePage({
    required this.index,
    required this.controller,
    required this.preview,
    required this.title,
    required this.description,
  });

  final int index;
  final PageController controller;
  final Widget preview;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);

    // The glass preview is a layer of its own: it trails the page while
    // swiping (parallax). Moved, never faded — fading breaks the blur.
    final floating = ExcludeSemantics(
      child: reduced
          ? preview
          : AnimatedBuilder(
              animation: controller,
              child: preview,
              builder: (context, child) {
                var page = index.toDouble();
                if (controller.hasClients &&
                    controller.position.hasContentDimensions) {
                  page = controller.page ?? page;
                }
                final delta = page - index;
                return Transform.translate(
                  offset: Offset(delta * 90, delta.abs() * 18),
                  child: child,
                );
              },
            ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decorative mock-ups: shrink rather than overflow on short
          // screens or with large text.
          Expanded(
            child: Center(
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: FittedBox(fit: BoxFit.scaleDown, child: floating),
              ),
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              title,
              style: _text.displayMedium!.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: _text.bodyLarge!.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Page 1: the next departures, labelled "Según horario" — the app reads
/// timetables, not live positions.
class _DeparturePreview extends StatelessWidget {
  const _DeparturePreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: GlassSurface(
        kind: GlassKind.clear,
        radius: 28,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const LineBadge(
                  label: 'L1',
                  color: AppColors.opMetroBilbao,
                  large: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hacia Plentzia',
                        style: _text.titleMedium!.copyWith(
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                      Text(
                        'Desde Moyua',
                        style: _text.bodySmall!.copyWith(
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CountdownText(minutes: 4),
                SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: DepartureStatus(isRealtime: false),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: Color(0x1FFFFFFF)),
            const SizedBox(height: 12),
            Row(
              children: [
                const LineBadge(label: 'A3136', color: AppColors.opBizkaibus),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hacia Bilbao',
                    style: _text.bodyMedium!.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                ),
                Text(
                  '12 min',
                  style: AppTypography.time.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Page 2: two saved trips with their next scheduled departure.
class _SavedTripsPreview extends StatelessWidget {
  const _SavedTripsPreview();

  @override
  Widget build(BuildContext context) {
    Widget trip(String name, String route, String time, Color color) {
      return Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: ShapeDecoration(
              color: color,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Icon(
              Icons.bookmark_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: _text.titleMedium!.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                Text(
                  route,
                  style: _text.bodySmall!.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: AppTypography.time.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.darkTextPrimary,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: 300,
      child: GlassSurface(
        kind: GlassKind.clear,
        radius: 28,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            trip('Casa → Trabajo', 'Bagatza → Kabiezes', '08:12',
                AppColors.opMetroBilbao),
            const Padding(
              padding: EdgeInsets.only(left: 48, top: 12, bottom: 12),
              child: Divider(height: 1, thickness: 1, color: Color(0x1FFFFFFF)),
            ),
            trip('Clase', 'Moyua → Leioa', '15:40', AppColors.opBizkaibus),
          ],
        ),
      ),
    );
  }
}

/// Page 3: a home-screen widget.
class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      height: 172,
      child: GlassSurface(
        kind: GlassKind.clear,
        radius: 36,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                LineBadge(label: 'L2', color: AppColors.opMetroBilbao),
                Spacer(),
                Icon(
                  Icons.directions_subway_rounded,
                  size: 18,
                  color: AppColors.darkTextSecondary,
                ),
              ],
            ),
            const Spacer(),
            Text(
              'Hacia Kabiezes',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _text.bodySmall!.copyWith(
                color: AppColors.darkTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            CountdownText(
              minutes: 7,
              style: AppTypography.countdownSmall.copyWith(fontSize: 34),
              unitStyle: _text.bodyMedium!.copyWith(
                color: AppColors.darkTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Según horario',
              style: AppTypography.time.copyWith(
                fontSize: 12,
                color: AppColors.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sign-in page (final onboarding page)
// ---------------------------------------------------------------------------

class _SignInPage extends ConsumerWidget {
  const _SignInPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final isIOS = !kIsWeb && Platform.isIOS;

    ref.listen<AsyncValue<void>>(authControllerProvider, (_, state) {
      if (state.hasError && !state.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar sesión: ${state.error}'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AppMark(size: 80),
                ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    'Noiz',
                    style: _text.displayMedium!.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inicia sesión para sincronizar tus viajes entre '
                  'dispositivos.',
                  style: _text.bodyLarge!.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                // Google sign-in
                SignInButton(
                  provider: SignInProvider.google,
                  isLoading: isLoading,
                  onPressed: () async {
                    final success = await ref
                        .read(authControllerProvider.notifier)
                        .signInWithGoogle();
                    if (success && context.mounted) {
                      context.go('/');
                    }
                  },
                ),

                // Apple sign-in (iOS only)
                if (isIOS) ...[
                  const SizedBox(height: 12),
                  SignInButton(
                    provider: SignInProvider.apple,
                    isLoading: isLoading,
                    onPressed: () async {
                      final success = await ref
                          .read(authControllerProvider.notifier)
                          .signInWithApple();
                      if (success && context.mounted) {
                        context.go('/');
                      }
                    },
                  ),
                ],

                const SizedBox(height: 16),

                Text(
                  'Al continuar, aceptas la política de privacidad. '
                  'Tus datos se almacenan de forma segura.',
                  style: _text.bodySmall!.copyWith(
                    color: AppColors.darkTextSecondary,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 10),

                // Independence notice required by both stores.
                Text(
                  LegalTexts.disclaimer,
                  style: _text.bodySmall!.copyWith(
                    color: AppColors.darkTextTertiary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Page indicator: the current dot stretches into a capsule
// ---------------------------------------------------------------------------

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.currentPage,
    required this.totalPages,
  });

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final m = Motion.snappy;

    return Semantics(
      label: 'Página ${currentPage + 1} de $totalPages',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalPages, (index) {
          final isActive = index == currentPage;
          return AnimatedContainer(
            duration: reduced ? Motion.reducedFade : m.duration,
            curve: reduced ? Curves.linear : m.curve,
            margin: const EdgeInsets.symmetric(horizontal: 3.5),
            width: isActive ? 24 : 7,
            height: 7,
            decoration: ShapeDecoration(
              color: Colors.white.withValues(alpha: isActive ? 0.95 : 0.28),
              shape: const StadiumBorder(),
            ),
          );
        }),
      ),
    );
  }
}
