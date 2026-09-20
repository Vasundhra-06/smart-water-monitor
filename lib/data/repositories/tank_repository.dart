import '../models/tank.dart';
import '../models/device.dart';
import '../../core/services/mock_sensor_service.dart';

abstract class ITankRepository {
  Future<List<Tank>> getTanks();
  Future<Tank?> getTankById(String id);
  Future<Device?> getDeviceForTank(String tankId);
  Future<void> addTank(Tank tank);
  Future<void> deleteTank(String tankId);
}

class TankRepository implements ITankRepository {
  final MockSensorService _mockService = MockSensorService.instance;

  @override
  Future<List<Tank>> getTanks() async {
    return _mockService.getTanks();
  }

  @override
  Future<Tank?> getTankById(String id) async {
    return _mockService.getTankById(id);
  }

  @override
  Future<Device?> getDeviceForTank(String tankId) async {
    return _mockService.getDeviceForTank(tankId);
  }

  @override
  Future<void> addTank(Tank tank) async {
    _mockService.addTank(tank);
  }

  @override
  Future<void> deleteTank(String tankId) async {
    _mockService.deleteTank(tankId);
  }
}
