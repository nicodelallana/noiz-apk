import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';

/// Animated onboarding shown when the user is not signed in.
///
/// Features:
/// - 3 feature-introduction pages with animated icons
/// - Final sign-in page with Google / Apple buttons
/// - "Continuar sin cuenta" skip option
/// - Smooth page indicator dots
/// - Respects reduced motion (MediaQuery.disableAnimationsOf)
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _skip() {
    ref.read(onboardingCompletedProvider.notifier).state = true;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Saltar',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
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
                children: const [
                  _FeaturePage(
                    icon: Icons.departure_board,
                    iconColor: Color(0xFFE2001A),
                    title: 'Metro y Bus en un vistazo',
                    description:
                        'Consulta las próximas salidas de Metro Bilbao y Bizkaibus en tiempo real.',
                  ),
                  _FeaturePage(
                    icon: Icons.bookmark_added,
                    iconColor: Color(0xFF00A651),
                    title: 'Guarda tus viajes',
                    description:
                        'Marca tus trayectos habituales y accédelos con un toque.',
                  ),
                  _FeaturePage(
                    icon: Icons.widgets_rounded,
                    iconColor: Color(0xFF1D1D1B),
                    title: 'Widget en tu pantalla',
                    description:
                        'Añade un widget a tu pantalla de inicio para ver horarios sin abrir la app.',
                  ),
                  _SignInPage(),
                ],
              ),
            ),

            // Bottom controls: dots + button
            Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: bottomPadding + 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PageIndicator(
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                  ),
                  const SizedBox(height: 24),
                  if (_currentPage < _totalPages - 1)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _nextPage,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _currentPage == _totalPages - 2
                              ? 'Empezar'
                              : 'Siguiente',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Feature introduction page
// ---------------------------------------------------------------------------

class _FeaturePage extends StatelessWidget {
  const _FeaturePage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Animated icon
          reduceMotion
              ? _StaticIcon(icon: icon, color: iconColor)
              : _AnimatedIcon(icon: icon, color: iconColor),

          const SizedBox(height: 48),

          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _StaticIcon extends StatelessWidget {
  const _StaticIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 56, color: color),
    );
  }
}

class _AnimatedIcon extends StatefulWidget {
  const _AnimatedIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.15),
                blurRadius: 32,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Icon(widget.icon, size: 56, color: widget.color),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // App icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFE2001A),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE2001A).withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_transit_filled,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Noiz',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Inicia sesión para sincronizar tus viajes entre dispositivos.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const Spacer(),

          // Google sign-in
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: isLoading
                  ? null
                  : () async {
                      final success = await ref
                          .read(authControllerProvider.notifier)
                          .signInWithGoogle();
                      if (success && context.mounted) {
                        context.go('/');
                      }
                    },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child:
                          CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.g_mobiledata, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Continuar con Google',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Apple sign-in (iOS only)
          if (isIOS) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final success = await ref
                            .read(authControllerProvider.notifier)
                            .signInWithApple();
                        if (success && context.mounted) {
                          context.go('/');
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.apple, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Continuar con Apple',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Skip / continue without account
          TextButton(
            onPressed: () {
              ref.read(onboardingCompletedProvider.notifier).state = true;
              context.go('/');
            },
            child: Text(
              'Continuar sin cuenta',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Al continuar, aceptas la política de privacidad. '
            'Tus datos se almacenan de forma segura.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 11,
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page indicator dots
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
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
