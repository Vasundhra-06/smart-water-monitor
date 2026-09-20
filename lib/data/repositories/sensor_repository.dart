import '../models/sensor_reading.dart';
import '../../core/services/thing_speak_http_service.dart';

abstract class ISensorRepository {
  Stream<SensorReading> getLiveSensorStream();
  Future<List<SensorReading>> getHistoricalReadings(String tankId);
  Future<SensorReading> getLatestReading(String tankId);
}

class SensorRepository implements ISensorRepository {
  final ThingSpeakHttpService _service = ThingSpeakHttpService.instance;

  @override
  Stream<SensorReading> getLiveSensorStream() {
    return _service.liveSensorStream;
  }

  @override
  Future<List<SensorReading>> getHistoricalReadings(String tankId) async {
    return _service.fetchHistoricalReadings(tankId);
  }

  @override
  Future<SensorReading> getLatestReading(String tankId) async {
    return _service.fetchLatestReading(tankId: tankId);
  }
}
