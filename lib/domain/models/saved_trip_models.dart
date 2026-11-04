/// Pure domain entities representing bookmarked journeys and transit operators.
/// Completely decoupled from UI frameworks, SQLite databases, or remote APIs.

enum TransitTerritory {
  all('all', 'Euskadi'),
  bizkaia('bizkaia', 'Bizkaia'),
  gipuzkoa('gipuzkoa', 'Gipuzkoa'),
  araba('araba', 'Araba');

  const TransitTerritory(this.id, this.name);
  final String id;
  final String name;

  static TransitTerritory fromId(String id) {
    return TransitTerritory.values.firstWhere(
      (t) => t.id == id,
      orElse: () => TransitTerritory.all,
    );
  }

  /// Detects the territory from geographic coordinates.
  /// Falls back to [TransitTerritory.bizkaia] if indeterminate.
  static TransitTerritory territoryFromCoordinates(double lat, double lon) {
    if (lat >= 43.02 && lon <= -2.55) {
      return TransitTerritory.bizkaia;
    }
    if (lat >= 43.02 && lon > -2.55) {
      return TransitTerritory.gipuzkoa;
    }
    if (lat < 43.02) {
      return TransitTerritory.araba;
    }
    return TransitTerritory.bizkaia;
  }

  /// Default operator for a given territory.
  static TransitOperator defaultOperatorFor(TransitTerritory territory) {
    return switch (territory) {
      TransitTerritory.bizkaia => TransitOperator.metro,
      TransitTerritory.gipuzkoa => TransitOperator.dbus,
      TransitTerritory.araba => TransitOperator.tuvisa,
      TransitTerritory.all => TransitOperator.metro,
    };
  }
}

enum TransitModeType {
  metro('metro', 'Metro'),
  train('train', 'Cercanías/Tren'),
  tram('tram', 'Tranvía'),
  bus('bus', 'Autobús'),
  funicular('funicular', 'Funicular');

  const TransitModeType(this.id, this.label);
  final String id;
  final String label;

  static TransitModeType fromId(String id) {
    return TransitModeType.values.firstWhere(
      (m) => m.id == id,
      orElse: () => TransitModeType.metro,
    );
  }
}

enum TransitOperator {
  metro(
    id: 'metro',
    name: 'Metro Bilbao',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.metro,
    colorHex: 0xFFE8590C,
    hasRealtime: true,
  ),
  renfe(
    id: 'renfe',
    name: 'Renfe Cercanías',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.train,
    colorHex: 0xFFD0142B,
    hasRealtime: true,
  ),
  euskotren(
    id: 'euskotren',
    name: 'Euskotren',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.train,
    colorHex: 0xFF025DA9,
    hasRealtime: true,
  ),
  tranbiaBilbao(
    id: 'tranbia_bilbao',
    name: 'Tranvía de Bilbao',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.tram,
    colorHex: 0xFF2FA650,
    hasRealtime: true,
  ),
  tranbiaGasteiz(
    id: 'tranbia_gasteiz',
    name: 'Tranvía de Vitoria-Gasteiz',
    territory: TransitTerritory.araba,
    mode: TransitModeType.tram,
    colorHex: 0xFF2FA650,
    hasRealtime: true,
  ),
  bizkaibus(
    id: 'bizkaibus',
    name: 'Bizkaibus',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.bus,
    colorHex: 0xFF2E9E4F,
    hasRealtime: true,
  ),
  bilbobus(
    id: 'bilbobus',
    name: 'Bilbobus',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.bus,
    colorHex: 0xFFD7143C,
    hasRealtime: true,
  ),
  dbus(
    id: 'dbus',
    name: 'Dbus',
    territory: TransitTerritory.gipuzkoa,
    mode: TransitModeType.bus,
    colorHex: 0xFF1D7FD1,
    hasRealtime: true,
  ),
  lurraldebus(
    id: 'lurraldebus',
    name: 'Lurraldebus',
    territory: TransitTerritory.gipuzkoa,
    mode: TransitModeType.bus,
    colorHex: 0xFF5E9424,
    hasRealtime: true,
  ),
  tuvisa(
    id: 'tuvisa',
    name: 'TUVISA',
    territory: TransitTerritory.araba,
    mode: TransitModeType.bus,
    colorHex: 0xFF12979F,
    hasRealtime: true,
  ),
  alavabus(
    id: 'alavabus',
    name: 'Álavabus',
    territory: TransitTerritory.araba,
    mode: TransitModeType.bus,
    colorHex: 0xFFB04A8E,
    hasRealtime: false,
  ),
  artxanda(
    id: 'artxanda',
    name: 'Funicular de Artxanda',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.funicular,
    colorHex: 0xFFDC0B0B,
    hasRealtime: false,
  ),
  laUnion(
    id: 'la_union',
    name: 'La Unión',
    territory: TransitTerritory.araba,
    mode: TransitModeType.bus,
    colorHex: 0xFF30609D,
    hasRealtime: false,
  ),
  renfeMedia(
    id: 'renfe_media',
    name: 'Renfe Media Distancia',
    territory: TransitTerritory.araba,
    mode: TransitModeType.train,
    colorHex: 0xFF7B1FA2,
    hasRealtime: false,
  ),
  kbus(
    id: 'kbus',
    name: 'Kbus (Barakaldo)',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.bus,
    colorHex: 0xFF2B5B84,
    hasRealtime: true,
  ),
  etxebarribus(
    id: 'etxebarribus',
    name: 'EtxeBarriBus',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.bus,
    colorHex: 0xFF007A3D,
    hasRealtime: true,
  ),
  erandioBusa(
    id: 'erandio_busa',
    name: 'Erandio! busa',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.bus,
    colorHex: 0xFF00897B,
    hasRealtime: true,
  ),
  lejoanBusa(
    id: 'lejoan_busa',
    name: 'Lejoan busa',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.bus,
    colorHex: 0xFF5C6BC0,
    hasRealtime: true,
  ),
  sopelbus(
    id: 'sopelbus',
    name: 'Sopelbus',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.bus,
    colorHex: 0xFF00ACC1,
    hasRealtime: true,
  ),
  bermibusa(
    id: 'bermibusa',
    name: 'Bermibusa',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.bus,
    colorHex: 0xFF1E88E5,
    hasRealtime: true,
  ),
  pteColgante(
    id: 'pte_colgante',
    name: 'Puente Colgante',
    territory: TransitTerritory.bizkaia,
    mode: TransitModeType.funicular,
    colorHex: 0xFF8D6E63,
    hasRealtime: false,
  ),
  irunbus(
    id: 'irunbus',
    name: 'Irunbus',
    territory: TransitTerritory.gipuzkoa,
    mode: TransitModeType.bus,
    colorHex: 0xFF0072CE,
    hasRealtime: false,
  ),
  errenteria(
    id: 'errenteria',
    name: 'Errenteria Urbanoa',
    territory: TransitTerritory.gipuzkoa,
    mode: TransitModeType.bus,
    colorHex: 0xFF3949AB,
    hasRealtime: true,
  ),
  zarauzkoHiribusa(
    id: 'zarauzko_hiribusa',
    name: 'Zarauzko hiribusa',
    territory: TransitTerritory.gipuzkoa,
    mode: TransitModeType.bus,
    colorHex: 0xFF0097A7,
    hasRealtime: true,
  ),
  hernanikoHiribusa(
    id: 'hernaniko_hiribusa',
    name: 'Hernaniko hiribusa',
    territory: TransitTerritory.gipuzkoa,
    mode: TransitModeType.bus,
    colorHex: 0xFF43A047,
    hasRealtime: true,
  ),
  tolosa(
    id: 'tolosa',
    name: 'Urbano de Tolosa',
    territory: TransitTerritory.gipuzkoa,
    mode: TransitModeType.bus,
    colorHex: 0xFF7CB342,
    hasRealtime: true,
  ),
  eibar(
    id: 'eibar',
    name: 'Udalbus (Eibar)',
    territory: TransitTerritory.gipuzkoa,
    mode: TransitModeType.bus,
    colorHex: 0xFF8E24AA,
    hasRealtime: true,
  ),
  arrasate(
    id: 'arrasate',
    name: 'Arrasate',
    territory: TransitTerritory.gipuzkoa,
    mode: TransitModeType.bus,
    colorHex: 0xFFD81B60,
    hasRealtime: true,
  ),
  onati(
    id: 'onati',
    name: 'Oñati',
    territory: TransitTerritory.gipuzkoa,
    mode: TransitModeType.bus,
    colorHex: 0xFF546E7A,
    hasRealtime: true,
  ),
  lasarte(
    id: 'lasarte',
    name: 'Lasarte (Manttangorri)',
    territory: TransitTerritory.gipuzkoa,
    mode: TransitModeType.bus,
    colorHex: 0xFFE65100,
    hasRealtime: false,
  ),
  oiartzun(
    id: 'oiartzun',
    name: 'Xorrola (Oiartzun)',
    territory: TransitTerritory.gipuzkoa,
    mode: TransitModeType.bus,
    colorHex: 0xFF6D4C41,
    hasRealtime: true,
  );

  const TransitOperator({
    required this.id,
    required this.name,
    this.territory = TransitTerritory.bizkaia,
    this.mode = TransitModeType.metro,
    this.colorHex = 0xFFE8590C,
    this.hasRealtime = true,
  });

  final String id;
  final String name;
  final TransitTerritory territory;
  final TransitModeType mode;
  final int colorHex;
  final bool hasRealtime;

  static TransitOperator fromId(String id) {
    final clean = id.toLowerCase().trim();
    if (clean == 'renfe_cercanias') return TransitOperator.renfe;
    if (clean == 'renfe_media') return TransitOperator.renfeMedia;
    return TransitOperator.values.firstWhere(
      (op) => op.id == clean,
      orElse: () => TransitOperator.metro,
    );
  }

  static List<TransitOperator> byTerritory(TransitTerritory territory) {
    if (territory == TransitTerritory.all) return TransitOperator.values;
    return TransitOperator.values.where((op) {
      if (op.territory == territory) return true;
      // Renfe Cercanías serves both Bizkaia and Gipuzkoa (Cercanías Donostia)
      if (op == TransitOperator.renfe &&
          (territory == TransitTerritory.bizkaia ||
              territory == TransitTerritory.gipuzkoa)) {
        return true;
      }
      // Renfe Media Distancia connects across Araba, Gipuzkoa and Bizkaia
      if (op == TransitOperator.renfeMedia &&
          (territory == TransitTerritory.araba ||
              territory == TransitTerritory.gipuzkoa ||
              territory == TransitTerritory.bizkaia)) {
        return true;
      }
      return false;
    }).toList();
  }
}

class SavedTrip {
  const SavedTrip({
    required this.id,
    required this.userId,
    required this.name,
    required this.operator,
    required this.originStopId,
    required this.originStopName,
    required this.destStopId,
    required this.destStopName,
    this.routeId,
    this.directionId,
    this.widgetEnabled = true,
    this.sortOrder = 0,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final TransitOperator operator;
  final String originStopId;
  final String originStopName;
  final String destStopId;
  final String destStopName;
  final String? routeId;
  final int? directionId;
  final bool widgetEnabled;
  final int sortOrder;
  final DateTime createdAt;

  SavedTrip copyWith({
    String? id,
    String? userId,
    String? name,
    TransitOperator? operator,
    String? originStopId,
    String? originStopName,
    String? destStopId,
    String? destStopName,
    String? routeId,
    int? directionId,
    bool? widgetEnabled,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return SavedTrip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      operator: operator ?? this.operator,
      originStopId: originStopId ?? this.originStopId,
      originStopName: originStopName ?? this.originStopName,
      destStopId: destStopId ?? this.destStopId,
      destStopName: destStopName ?? this.destStopName,
      routeId: routeId ?? this.routeId,
      directionId: directionId ?? this.directionId,
      widgetEnabled: widgetEnabled ?? this.widgetEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedTrip &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          name == other.name &&
          originStopId == other.originStopId &&
          destStopId == other.destStopId &&
          widgetEnabled == other.widgetEnabled &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      name.hashCode ^
      originStopId.hashCode ^
      destStopId.hashCode ^
      widgetEnabled.hashCode ^
      sortOrder.hashCode;

  @override
  String toString() =>
      'SavedTrip($name: $originStopName -> $destStopName, widget: $widgetEnabled)';
}
