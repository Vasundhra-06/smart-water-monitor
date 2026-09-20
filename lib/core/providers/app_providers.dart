import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/tank.dart';
import '../../data/models/device.dart';
import '../../data/models/sensor_reading.dart';
import '../../data/models/alert.dart';
import '../../data/models/cleaning_record.dart';
import '../../data/models/ai_analysis_result.dart';
import '../../data/repositories/sensor_repository.dart';
import '../../data/repositories/tank_repository.dart';
import '../../data/repositories/alert_repository.dart';
import '../../data/repositories/cleaning_repository.dart';
import '../../data/repositories/ai_repository.dart';
import '../constants/app_constants.dart';
import '../services/mock_sensor_service.dart';

// Repository Providers
final sensorRepositoryProvider = Provider<ISensorRepository>((ref) => SensorRepository());
final tankRepositoryProvider = Provider<ITankRepository>((ref) => TankRepository());
final alertRepositoryProvider = Provider<IAlertRepository>((ref) => AlertRepository());
final cleaningRepositoryProvider = Provider<ICleaningRepository>((ref) => CleaningRepository());
final aiRepositoryProvider = Provider<IAIRepository>((ref) => AIRepository());

// User Role Provider
final userRoleProvider = StateProvider<UserRole>((ref) => UserRole.admin);

// Active Selected Tank Provider
final selectedTankProvider = StateProvider<Tank?>((ref) {
  final tanks = ref.watch(tanksProvider).value;
  if (tanks != null && tanks.isNotEmpty) {
    return tanks.first;
  }
  return MockSensorService.instance.getTanks().first;
});

// Simulation Scenario Provider
final simulationScenarioProvider = StateProvider<SimulationScenario>((ref) {
  return MockSensorService.instance.currentScenario;
});

// Async Data Providers
final tanksProvider = FutureProvider<List<Tank>>((ref) async {
  final repo = ref.watch(tankRepositoryProvider);
  return repo.getTanks();
});

final deviceForTankProvider = FutureProvider.family<Device?, String>((ref, tankId) async {
  final repo = ref.watch(tankRepositoryProvider);
  return repo.getDeviceForTank(tankId);
});

final historicalReadingsProvider = FutureProvider.family<List<SensorReading>, String>((ref, tankId) async {
  final repo = ref.watch(sensorRepositoryProvider);
  return repo.getHistoricalReadings(tankId);
});

final liveSensorStreamProvider = StreamProvider<SensorReading>((ref) {
  final repo = ref.watch(sensorRepositoryProvider);
  return repo.getLiveSensorStream();
});

final latestReadingProvider = FutureProvider.family<SensorReading, String>((ref, tankId) async {
  final repo = ref.watch(sensorRepositoryProvider);
  return repo.getLatestReading(tankId);
});

final aiAnalysisProvider = FutureProvider.family<AIAnalysisResult, String>((ref, tankId) async {
  final repo = ref.watch(aiRepositoryProvider);
  return repo.getAIAnalysisForTank(tankId);
});

final alertsProvider = FutureProvider<List<AlertItem>>((ref) async {
  final repo = ref.watch(alertRepositoryProvider);
  return repo.getAlerts();
});

final cleaningHistoryProvider = FutureProvider.family<List<CleaningRecord>, String>((ref, tankId) async {
  final repo = ref.watch(cleaningRepositoryProvider);
  return repo.getCleaningHistory(tankId);
});
