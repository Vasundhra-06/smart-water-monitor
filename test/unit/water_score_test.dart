import 'package:flutter_test/flutter_test.dart';
import 'package:smart_water_monitor/core/constants/app_constants.dart';

void main() {
  group('Water Quality Score Calculations', () {
    test('High quality parameters return Excellent score (>= 90)', () {
      int score = 95;
      expect(AppConstants.getScoreLabel(score), equals('Excellent'));
    });

    test('Moderate quality score (>= 50 & < 75)', () {
      int score = 61;
      expect(AppConstants.getScoreLabel(score), equals('Moderate'));
    });

    test('Very Poor quality score (< 25)', () {
      int score = 15;
      expect(AppConstants.getScoreLabel(score), equals('Very Poor'));
    });
  });
}
