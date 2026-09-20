import 'package:flutter_test/flutter_test.dart';
import 'package:smart_water_monitor/core/services/mock_sensor_service.dart';
import 'package:smart_water_monitor/core/constants/app_constants.dart';

void main() {
  group('AI Trend & Anomaly Detection', () {
    test('Initial seed state loads tanks and 30-day realistic history', () {
      final mock = MockSensorService.instance;
      final tanks = mock.getTanks();
      expect(tanks.length, greaterThanOrEqualTo(4));

      final readings = mock.getReadingsForTank('tank-main');
      expect(readings.length, greaterThan(20));
    });

    test('Triggering deteriorating scenario produces abnormal turbidity peak', () {
      final mock = MockSensorService.instance;
      mock.setScenario(SimulationScenario.deteriorating);

      final aiResult = mock.getAIAnalysis('tank-main');
      expect(aiResult.cleaningRecommendation, isTrue);
      expect(aiResult.status, equals('ATTENTION'));
    });
  });
}
