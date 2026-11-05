import 'package:flutter_test/flutter_test.dart';

import 'package:bizkaia_transit/domain/models/transit_models.dart';

void main() {
  group('Stop Code and Identification Tests', () {
    test('extracts stop code from parenthesized string in name', () {
      const stop = Stop(
        id: 'bizkaibus:1065',
        name: 'SAN JUAN (1065)',
        operatorId: 'bizkaibus',
      );
      expect(stop.code, equals('1065'));
    });

    test('extracts stop code when municipality is also in parentheses', () {
      const stop = Stop(
        id: 'bizkaibus:1066',
        name: 'SAN JUAN (Muskiz) (1066)',
        operatorId: 'bizkaibus',
      );
      expect(stop.code, equals('1066'));
    });

    test('extracts stop code for UPV / EHU stops', () {
      const stop = Stop(
        id: 'bizkaibus:3515',
        name: 'EHU BIBLIOTEKA (3515)',
        operatorId: 'bizkaibus',
      );
      expect(stop.code, equals('3515'));
    });

    test('extracts stop code from ID when name does not contain number', () {
      const stop = Stop(
        id: 'renfe:13506',
        name: 'Muskiz',
        operatorId: 'renfe',
      );
      expect(stop.code, equals('13506'));
    });

    test('extracts station name identifier for metro stops', () {
      const stop = Stop(
        id: 'metro:abando',
        name: 'Abando',
        operatorId: 'metro',
      );
      expect(stop.code, equals('abando'));
    });
  });
}
