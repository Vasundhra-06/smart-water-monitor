import '../models/cleaning_record.dart';
import '../../core/services/mock_sensor_service.dart';

abstract class ICleaningRepository {
  Future<List<CleaningRecord>> getCleaningHistory(String tankId);
  Future<void> recordCleaning(String tankId, String technicianName, String notes, String method);
}

class CleaningRepository implements ICleaningRepository {
  final MockSensorService _mockService = MockSensorService.instance;

  @override
  Future<List<CleaningRecord>> getCleaningHistory(String tankId) async {
    return _mockService.getCleaningHistory(tankId);
  }

  @override
  Future<void> recordCleaning(String tankId, String technicianName, String notes, String method) async {
    _mockService.recordCleaningEvent(tankId, technicianName, notes, method);
  }
}
