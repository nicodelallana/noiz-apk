import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/models/auth_models.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/glass/content.dart';
import '../legal/licenses_screen.dart';
import 'auth_screen.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/shapes.dart';

final _text = AppTypography.textTheme();

/// User profile and account management screen with mandatory account deletion compliance.
class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: profileAsync.when(
          loading: () => const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LargeTitle('Cuenta'),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 120),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
              ),
            ],
          ),
          error: (e, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _LargeTitle('Cuenta'),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
                  child: Center(
                    child: Text(
                      'Error al cargar perfil: $e',
                      textAlign: TextAlign.center,
                      style: _text.bodyMedium!.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          data: (profile) {
            if (profile == null) {
              // Guest mode: the whole app works without an account.
              return ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  const _LargeTitle('Cuenta'),
                  _UnauthenticatedView(
                    onLoginPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AuthScreen(),
                        ),
                      );
                    },
                  ),
                  const _LegalSection(),
                ],
              );
            }

            return _ProfileContent(profile: profile);
          },
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = profile.displayName.isNotEmpty
        ? profile.displayName[0].toUpperCase()
        : '?';

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        const _LargeTitle('Cuenta'),

        // 1. User header
        _InsetGroup(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.darkSurfaceElevated,
                    foregroundColor: AppColors.darkTextPrimary,
                    backgroundImage: profile.avatarUrl != null
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl == null
                        ? Text(
                            initial,
                            style: _text.titleLarge!.copyWith(
                              color: AppColors.darkTextPrimary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _text.titleLarge!.copyWith(
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                        if (profile.email != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            profile.email!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _text.bodyMedium!.copyWith(
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // 2. Account actions
        _InsetGroup(
          children: [
            _SettingsRow(
              icon: Icons.logout_rounded,
              tileColor: const Color(0xFF636366),
              title: 'Cerrar sesión',
              showChevron: false,
              onTap: () async {
                await ref.read(authControllerProvider.notifier).signOut();
              },
            ),
          ],
        ),

        // 3. Danger zone: mandatory account deletion (Apple 5.1.1(v) & Google Play)
        _InsetGroup(
          footer:
              'Borra permanentemente tu perfil, trayectos guardados y ajustes.',
          children: [
            _SettingsRow(
              icon: Icons.delete_forever_rounded,
              tileColor: AppColors.disruptedRed,
              title: 'Eliminar cuenta y datos',
              titleColor: AppColors.disruptedRed,
              showChevron: false,
              onTap: () => _confirmAccountDeletion(context, ref),
            ),
          ],
        ),

        const _LegalSection(),
      ],
    );
  }

  void _confirmAccountDeletion(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.darkSurfaceElevated,
          shape: continuousShape(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text('¿Eliminar tu cuenta?'),
          content: const Text(
            'Esta acción es definitiva e irreversible. Todos tus datos personales, '
            'viajes guardados y códigos compartidos se eliminarán de nuestros servidores.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.disruptedRed,
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                try {
                  await ref
                      .read(authControllerProvider.notifier)
                      .deleteAccount();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Cuenta eliminada con éxito.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al eliminar cuenta: $e')),
                    );
                  }
                }
              },
              child: const Text('Eliminar definitivamente'),
            ),
          ],
        );
      },
    );
  }
}

/// Data sources, licences and the independence disclaimer (store policy).
class _LegalSection extends StatelessWidget {
  const _LegalSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InsetGroup(
          children: [
            _SettingsRow(
              icon: Icons.gavel_rounded,
              tileColor: const Color(0xFF5E5CE6),
              title: 'Fuentes de datos y licencias',
              onTap: () => context.push('/settings/licenses'),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: DisclaimerCard(),
        ),
      ],
    );
  }
}

class _UnauthenticatedView extends StatelessWidget {
  const _UnauthenticatedView({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return _InsetGroup(
      footer: 'Toda la app funciona sin cuenta.',
      children: [
        Semantics(
          button: true,
          label: 'Iniciar sesión. No has iniciado sesión.',
          excludeSemantics: true,
          onTap: onLoginPressed,
          child: InkWell(
            onTap: onLoginPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const ShapeDecoration(
                      shape: CircleBorder(),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF8E8E93), Color(0xFF636366)],
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Iniciar sesión',
                          style: _text.titleMedium!.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No has iniciado sesión. Entra con Google o Apple '
                          'para sincronizar tus viajes.',
                          style: _text.bodySmall!.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _Chevron(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// iOS inset-grouped list pieces
// ---------------------------------------------------------------------------

/// iOS large title, left aligned.
class _LargeTitle extends StatelessWidget {
  const _LargeTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: _text.displayMedium!.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
      ),
    );
  }
}

/// A solid card holding rows separated by inset hairlines, with an optional
/// footnote underneath.
class _InsetGroup extends StatelessWidget {
  const _InsetGroup({required this.children, this.footer});

  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.only(left: 60),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.darkBorder,
                      ),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                footer!,
                style: _text.bodySmall!.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 52 px row: coloured icon tile, title, chevron.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.tileColor,
    required this.title,
    required this.onTap,
    this.titleColor = AppColors.darkTextPrimary,
    this.showChevron = true,
  });

  final IconData icon;
  final Color tileColor;
  final String title;
  final Color titleColor;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: ShapeDecoration(
                    color: tileColor,
                    shape: continuousShape(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: _text.bodyLarge!.copyWith(color: titleColor),
                  ),
                ),
                if (showChevron) const _Chevron(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Icon(
        Icons.chevron_right_rounded,
        size: 22,
        color: AppColors.darkTextTertiary,
      ),
    );
  }
}
