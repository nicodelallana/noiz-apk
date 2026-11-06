import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/presentation/screens/legal/legal_texts.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/aurora_background.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/content.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/glass_surface.dart';

final _text = AppTypography.textTheme();

/// Privacy policy screen displaying how user and device data is treated in Noiz,
/// fully compliant with Google Play Console and RGPD (GDPR) requirements.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 120),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Política de Privacidad',
                        style: _text.displayMedium!.copyWith(
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ),
                  ),

                  // Public web link card (Google Play requirement)
                  SurfaceCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.public_rounded,
                              size: 20,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'URL pública oficial',
                              style: _text.titleSmall!.copyWith(
                                color: AppColors.darkTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Esta política se encuentra alojada públicamente en HTTPS '
                          'para cumplir con los estándares de Google Play Console:',
                          style: _text.bodySmall!.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Semantics(
                          button: true,
                          label: 'Copiar enlace a la política de privacidad web',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Clipboard.setData(
                                const ClipboardData(
                                  text: LegalTexts.privacyPolicyUrl,
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('URL pública copiada al portapapeles'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.accent.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.link_rounded,
                                    size: 16,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      LegalTexts.privacyPolicyUrl,
                                      style: _text.labelMedium!.copyWith(
                                        color: AppColors.accent,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.copy_rounded,
                                    size: 14,
                                    color: AppColors.accent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SectionHeader(
                    '1. Principio Offline-First y Privacidad',
                    subtitle: 'Uso anónimo por defecto.',
                    padding: EdgeInsets.fromLTRB(4, 24, 4, 10),
                  ),
                  const _PolicyCard(
                    icon: Icons.shield_outlined,
                    title: 'Sin registro obligatorio',
                    description:
                        'Noiz está diseñada para que puedas consultar cualquier '
                        'horario, estación, mapa y tarifa de Bizkaia y Euskadi '
                        'completamente offline o de forma anónima, sin necesidad de '
                        'crear una cuenta.',
                  ),

                  const SectionHeader(
                    '2. Datos y Permisos del Dispositivo',
                    subtitle: 'Finalidad transparente y uso local.',
                    padding: EdgeInsets.fromLTRB(4, 24, 4, 10),
                  ),
                  const _PolicyCard(
                    icon: Icons.my_location_rounded,
                    title: 'Ubicación (GPS / Red)',
                    description:
                        'Se utiliza exclusivamente en primer plano mientras usas '
                        'la app para calcular paradas cercanas y rutas desde tu '
                        'posición. No se registra ningún historial de localización '
                        'ni se comparte con terceros.',
                  ),
                  const SizedBox(height: 10),
                  const _PolicyCard(
                    icon: Icons.timer_outlined,
                    title: 'Servicio en pantalla de bloqueo',
                    description:
                        'El servicio de primer plano (Foreground Service) solo se '
                        'activa si pides explícitamente ver el contador de salida '
                        'en vivo de un transporte en tu pantalla de bloqueo. '
                        'Se apaga al concluir el trayecto.',
                  ),
                  const SizedBox(height: 10),
                  const _PolicyCard(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notificaciones',
                    description:
                        'Utilizadas de forma local para avisarte de incidencias o '
                        'salidas programadas solicitadas. Puedes desactivarlas en '
                        'cualquier momento desde los ajustes de Android.',
                  ),

                  const SectionHeader(
                    '3. Cuenta Opcional y Sincronización',
                    subtitle: 'Control total de tus datos.',
                    padding: EdgeInsets.fromLTRB(4, 24, 4, 10),
                  ),
                  const _PolicyCard(
                    icon: Icons.sync_rounded,
                    title: 'Sincronización con Supabase (Opcional)',
                    description:
                        'Si inicias sesión con Google o Apple, únicamente se '
                        'almacena tu identificador y tus viajes guardados con '
                        'seguridad a nivel de fila (Row Level Security).',
                  ),
                  const SizedBox(height: 10),
                  const _PolicyCard(
                    icon: Icons.delete_forever_rounded,
                    title: 'Eliminación completa de la cuenta',
                    description:
                        'En el menú de Ajustes dispones del botón "Eliminar definitivamente '
                        'mi cuenta". Al pulsarlo, todos tus datos y favoritos se '
                        'borran de forma instantánea e irreversible.',
                  ),

                  const SectionHeader(
                    '4. Ausencia de Publicidad y No Venta de Datos',
                    subtitle: 'Cero rastreadores comerciales.',
                    padding: EdgeInsets.fromLTRB(4, 24, 4, 10),
                  ),
                  const _PolicyCard(
                    icon: Icons.money_off_rounded,
                    title: 'Sin anuncios publicitarios',
                    description:
                        'Noiz no incluye publicidad de terceros (sin AdMob ni redes de anuncios), '
                        'no rastrea tu actividad para perfiles comerciales y no '
                        'vende tus datos a ninguna entidad.',
                  ),

                  const SectionHeader(
                    '5. Contacto y Derechos RGPD',
                    subtitle: 'Acceso, rectificación y supresión.',
                    padding: EdgeInsets.fromLTRB(4, 24, 4, 10),
                  ),
                  SurfaceCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Responsable de la aplicación:',
                          style: _text.titleSmall!.copyWith(
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nicolas Pascual de la Llana · ${LegalTexts.developerEmail}',
                          style: _text.bodySmall!.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Para cualquier solicitud relacionada con tus datos o '
                          'derechos de privacidad bajo el RGPD, puedes contactar por email.',
                          style: _text.bodySmall!.copyWith(
                            color: AppColors.darkTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Floating back button
              Positioned(
                top: 8,
                left: 16,
                child: GlassButton(
                  blur: true,
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

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 20,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _text.titleSmall!.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: _text.bodySmall!.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
