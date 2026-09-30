import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/auth_models.dart';
import '../../providers/auth_providers.dart';
import 'auth_screen.dart';

/// User profile and account management screen with mandatory account deletion compliance.
class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Cuenta'),
      ),
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(child: Text('Error al cargar perfil: $e')),
        data: (profile) {
          if (profile == null) {
            return _UnauthenticatedView(
              onLoginPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
                );
              },
            );
          }

          return _ProfileContent(profile: profile);
        },
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 1. User Header Card
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          profile.displayName.isNotEmpty
                              ? profile.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (profile.email != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile.email!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 2. Account Actions
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Cerrar sesión'),
          onTap: () async {
            await ref.read(authControllerProvider.notifier).signOut();
          },
        ),

        const Divider(height: 32),

        // 3. Danger Zone: Mandatory Account Deletion (Apple 5.1.1(v) & Google Play)
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text(
            'Eliminar cuenta y datos',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Borra permanentemente tu perfil, trayectos guardados y ajustes.',
          ),
          onTap: () => _confirmAccountDeletion(context, ref),
        ),
      ],
    );
  }

  void _confirmAccountDeletion(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('¿Eliminar tu cuenta?'),
          content: const Text(
            'Esta acción es definitiva e irreversible. Todos tus datos personales, '
            'viajes guardados y códigos compartidos se eliminarán de nuestros servidores.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
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

class _UnauthenticatedView extends StatelessWidget {
  const _UnauthenticatedView({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined,
                size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No has iniciado sesión',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inicia sesión con tu cuenta de Google o Apple para sincronizar tus viajes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onLoginPressed,
              child: const Text('Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
