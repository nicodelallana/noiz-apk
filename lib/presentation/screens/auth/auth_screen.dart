import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/glass/aurora_background.dart';
import '../../widgets/glass/glass_surface.dart';

final _text = AppTypography.textTheme();

/// Authentication screen with native Google Sign-In and Sign in with Apple.
class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

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

    final isIOS = !kIsWeb && Platform.isIOS;

    return AuroraBackground(
      animate: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      // Clear the back button on top and the floating tab
                      // bar at the bottom.
                      padding: const EdgeInsets.fromLTRB(24, 72, 24, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: AppMark(size: 72),
                          ),
                          const SizedBox(height: 22),
                          Semantics(
                            header: true,
                            child: Text(
                              'Iniciar sesión',
                              style: _text.displayMedium!.copyWith(
                                color: AppColors.darkTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sincroniza tus viajes guardados y compártelos '
                            'entre dispositivos.',
                            style: _text.bodyLarge!.copyWith(
                              color: AppColors.darkTextSecondary,
                            ),
                          ),

                          const Spacer(),
                          const SizedBox(height: 32),

                          // Google Sign-In Button
                          SignInButton(
                            provider: SignInProvider.google,
                            isLoading: isLoading,
                            onPressed: () async {
                              final success = await ref
                                  .read(authControllerProvider.notifier)
                                  .signInWithGoogle();
                              if (success && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),

                          // Apple Sign-In Button (iOS or preview)
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
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Privacy Notice
                          Text(
                            'Al continuar, aceptas la política de privacidad. '
                            'Tus datos de transporte y trayectos se almacenan '
                            'de forma segura.',
                            style: _text.bodySmall!.copyWith(
                              color: AppColors.darkTextSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                left: 16,
                child: GlassButton(
                  semanticLabel: 'Atrás',
                  padding: const EdgeInsets.all(9),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    size: 26,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app's mark: a superellipse tile in the accent blue.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(size * 0.27),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3D9BFF), AppColors.accent, Color(0xFF0060DF)],
          ),
          shadows: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.35),
              blurRadius: size * 0.33,
              offset: Offset(0, size * 0.12),
            ),
          ],
        ),
        child: Icon(
          Icons.directions_transit_filled_rounded,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}

enum SignInProvider { google, apple }

/// Full-width capsule sign-in button. Solid, not glass: both providers ask
/// for their own button styles (Apple's white style, Google's dark style).
class SignInButton extends StatelessWidget {
  const SignInButton({
    super.key,
    required this.provider,
    required this.isLoading,
    required this.onPressed,
  });

  final SignInProvider provider;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final apple = provider == SignInProvider.apple;
    final background = apple ? Colors.white : const Color(0xFF131314);
    final foreground = apple ? Colors.black : const Color(0xFFE3E3E3);
    final shape = StadiumBorder(
      side: apple
          ? BorderSide.none
          : const BorderSide(color: Color(0xFF8E918F), width: 1),
    );

    return Material(
      color: background,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        customBorder: shape,
        // Grows with large text instead of clipping the label.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(foreground),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          apple ? Icons.apple : Icons.g_mobiledata,
                          size: apple ? 22 : 28,
                          color: foreground,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            apple
                                ? 'Continuar con Apple'
                                : 'Continuar con Google',
                            textAlign: TextAlign.center,
                            style:
                                _text.titleMedium!.copyWith(color: foreground),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
