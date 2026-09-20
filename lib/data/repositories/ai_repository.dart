import '../models/ai_analysis_result.dart';
import '../../core/services/mock_sensor_service.dart';

abstract class IAIRepository {
  Future<AIAnalysisResult> getAIAnalysisForTank(String tankId);
}

class AIRepository implements IAIRepository {
  final MockSensorService _mockService = MockSensorService.instance;

  @override
  Future<AIAnalysisResult> getAIAnalysisForTank(String tankId) async {
    return _mockService.getAIAnalysis(tankId);
  }
}
