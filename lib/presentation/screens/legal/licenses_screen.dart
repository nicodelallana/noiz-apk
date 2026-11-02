import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/presentation/screens/legal/legal_texts.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/aurora_background.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/content.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/glass_surface.dart';

final _text = AppTypography.textTheme();

/// Data sources, their licences and the independence disclaimer, reachable
/// from Settings (`/settings/licenses`) without signing in.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      animate: false,
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
                // Top clears the floating back button; bottom the tab bar.
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 120),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Fuentes de datos y licencias',
                        style: _text.displayMedium!.copyWith(
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ),
                  ),
                  const DisclaimerCard(),
                  const SectionHeader(
                    'Fuentes',
                    subtitle: 'Toca un enlace para copiarlo.',
                    padding: EdgeInsets.fromLTRB(4, 28, 4, 10),
                  ),
                  SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < dataSources.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.only(left: 16),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColors.darkBorder,
                              ),
                            ),
                          _SourceTile(source: dataSources[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Semantics(
                      button: true,
                      child: InkWell(
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: 'Noiz',
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Licencias de software de terceros',
                                    style: _text.bodyLarge!.copyWith(
                                      color: AppColors.darkTextPrimary,
                                    ),
                                  ),
                                ),
                                const ExcludeSemantics(
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 22,
                                    color: AppColors.darkTextTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

/// The store-mandated independence notice, reused in onboarding and settings.
class DisclaimerCard extends StatelessWidget {
  const DisclaimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              LegalTexts.disclaimer,
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

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});

  final DataSource source;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source.name,
            style: _text.titleSmall!.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            source.provider,
            style: _text.bodySmall!.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 14,
            children: [
              _CopyLink(
                icon: Icons.link_rounded,
                label: source.url.replaceFirst(RegExp('^https?://'), ''),
                value: source.url,
              ),
              _CopyLink(
                icon: Icons.copyright_rounded,
                label: 'Licencia: ${source.license}',
                value: source.licenseUrl ?? source.license,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The project has no url_launcher dependency, so links are copyable.
class _CopyLink extends StatelessWidget {
  const _CopyLink({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    void copy() {
      Clipboard.setData(ClipboardData(text: value));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace copiado')),
      );
    }

    return Semantics(
      button: true,
      label: '$label. Copiar enlace',
      excludeSemantics: true,
      onTap: copy,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: copy,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.accent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: _text.labelMedium!.copyWith(
                    color: AppColors.accent,
                    fontSize: 13,
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
