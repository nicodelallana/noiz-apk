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
    return TransitOperator.values.firstWhere(
      (op) => op.id == id,
      orElse: () => TransitOperator.metro,
    );
  }

  static List<TransitOperator> byTerritory(TransitTerritory territory) {
    if (territory == TransitTerritory.all) return TransitOperator.values;
    return TransitOperator.values
        .where((op) => op.territory == territory)
        .toList();
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
