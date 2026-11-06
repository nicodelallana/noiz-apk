/// Store-required legal copy (Google Play impersonation policy, Apple 5.2).
abstract final class LegalTexts {
  static const disclaimer =
      'Esta aplicación es una herramienta independiente y no cuenta con '
      'afiliación oficial ni representación de Metro Bilbao S.A., Renfe '
      'Operadora, Euskotren, Bilbobus, Bizkaibus ni el Consorcio de '
      'Transportes de Bizkaia (CTB). La información procede de portales '
      'oficiales de datos abiertos bajo licencias públicas de reutilización.';

  /// Public web URL hosted on GitHub Pages (meets Google Play HTTPS / no-login requirement).
  static const privacyPolicyUrl =
      'https://nicodelallana.github.io/noiz-apk/privacy.html';

  /// Contact email for data protection and support inquiries.
  static const developerEmail = 'nicolaspascualdelallana@gmail.com';
}

/// One open-data source and its reuse licence (see docs/licencias-datos.md).
class DataSource {
  const DataSource({
    required this.name,
    required this.provider,
    required this.url,
    required this.license,
    this.licenseUrl,
  });

  final String name;
  final String provider;
  final String url;
  final String license;
  final String? licenseUrl;
}

const dataSources = [
  DataSource(
    name: 'Consorcio de Transportes de Bizkaia (CTB)',
    provider: 'Horarios, paradas y tiempo real',
    url: 'https://data.ctb.eus',
    license: 'CC BY 4.0',
    licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
  ),
  DataSource(
    name: 'Bizkaibus',
    provider: 'Diputación Foral de Bizkaia',
    url: 'https://baliabideak.bizkaia.eus',
    license: 'CC BY 4.0',
    licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
  ),
  DataSource(
    name: 'Bilbobus',
    provider: 'Ayuntamiento de Bilbao · Open Data Euskadi',
    url: 'https://opendata.euskadi.eus',
    license: 'CC BY 4.0',
    licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
  ),
  DataSource(
    name: 'Euskotren',
    provider: 'Eusko Trenbideak · CTB / Moveuskadi',
    url: 'https://data.ctb.eus',
    license: 'CC BY 4.0',
    licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
  ),
  DataSource(
    name: 'Moveuskadi',
    provider: 'Gobierno Vasco · Open Data Euskadi',
    url: 'https://opendata.euskadi.eus',
    license: 'CC BY 4.0',
    licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
  ),
  DataSource(
    name: 'Metro Bilbao',
    provider: 'Metro Bilbao S.A. · datos abiertos',
    url: 'https://www.metrobilbao.eus',
    license: 'Reutilización abierta con atribución',
  ),
  DataSource(
    name: 'Renfe Cercanías',
    provider: 'Renfe Viajeros · Ministerio de Transportes',
    url: 'https://data.renfe.com',
    license: 'Reutilización del sector público (Ley 37/2007)',
  ),
  DataSource(
    name: 'Mapa base',
    provider: 'OpenFreeMap · © colaboradores de OpenStreetMap',
    url: 'https://www.openstreetmap.org/copyright',
    license: 'ODbL',
    licenseUrl: 'https://opendatacommons.org/licenses/odbl/',
  ),
];
