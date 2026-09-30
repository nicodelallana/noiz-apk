/// Pure domain entities representing bookmarked journeys and transit operators.
/// Completely decoupled from UI frameworks, SQLite databases, or remote APIs.

enum TransitOperator {
  metro(id: 'metro', name: 'Metro Bilbao'),
  bizkaibus(id: 'bizkaibus', name: 'Bizkaibus'),
  bilbobus(id: 'bilbobus', name: 'Bilbobus'),
  euskotren(id: 'euskotren', name: 'Euskotren'),
  renfe(id: 'renfe', name: 'Renfe Cercanías');

  const TransitOperator({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  static TransitOperator fromId(String id) {
    return TransitOperator.values.firstWhere(
      (op) => op.id == id,
      orElse: () => TransitOperator.metro,
    );
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
