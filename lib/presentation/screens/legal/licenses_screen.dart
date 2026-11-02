import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/presentation/screens/legal/legal_texts.dart';

/// Data sources, their licences and the independence disclaimer, reachable
/// from Settings (`/settings/licenses`) without signing in.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: AppColors.darkBackground,
        title: const Text('Fuentes de datos y licencias'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const DisclaimerCard(),
          const SizedBox(height: 20),
          for (final source in dataSources) _SourceTile(source: source),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Noiz',
            ),
            child: const Text('Licencias de software de terceros'),
          ),
        ],
      ),
    );
  }
}

/// The store-mandated independence notice, reused in onboarding and settings.
class DisclaimerCard extends StatelessWidget {
  const DisclaimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: const Text(
        LegalTexts.disclaimer,
        style: TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: 12.5,
          height: 1.4,
        ),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source.name,
            style: const TextStyle(
              color: AppColors.darkTextPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            source.provider,
            style: const TextStyle(
              color: AppColors.darkTextSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            children: [
              _CopyLink(label: source.url, value: source.url),
              _CopyLink(
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
  const _CopyLink({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enlace copiado')),
        );
      },
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.opDbus,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
