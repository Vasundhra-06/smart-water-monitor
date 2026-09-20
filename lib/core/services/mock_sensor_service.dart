import 'dart:async';
import 'dart:math';
import '../../data/models/sensor_reading.dart';
import '../../data/models/tank.dart';
import '../../data/models/device.dart';
import '../../data/models/alert.dart';
import '../../data/models/cleaning_record.dart';
import '../../data/models/ai_analysis_result.dart';
import '../constants/app_constants.dart';

class MockSensorService {
  static final MockSensorService instance = MockSensorService._internal();
  MockSensorService._internal() {
    _initSeedData();
    _startLiveTicker();
  }

  final _random = Random();
  final _streamController = StreamController<SensorReading>.broadcast();
  Stream<SensorReading> get sensorStream => _streamController.stream;

  // Active scenario overrides for developer demo mode
  SimulationScenario _currentScenario = SimulationScenario.normal;
  SimulationScenario get currentScenario => _currentScenario;

  // Memory datasets
  late List<Tank> _tanks;
  late Map<String, Device> _devices;
  late Map<String, List<SensorReading>> _historyMap;
  late List<AlertItem> _alerts;
  late List<CleaningRecord> _cleaningHistory;
  late Map<String, AIAnalysisResult> _aiResults;

  void setScenario(SimulationScenario scenario) {
    _currentScenario = scenario;
    if (scenario == SimulationScenario.deteriorating || scenario == SimulationScenario.critical) {
      _triggerDeteriorationPeak();
    }
  }

  void _initSeedData() {
    final now = DateTime.now();

    _tanks = [
      Tank(
        id: 'tank-main',
        tankName: 'Main Tank',
        location: 'Main Academic Building Roof',
        capacity: 5000.0,
        description: 'Primary drinking water supply for academic block',
        status: TankStatus.online,
        deviceId: 'TANK_001',
        installationDate: now.subtract(const Duration(days: 120)),
        lastCleanedAt: now.subtract(const Duration(days: 6)),
        createdAt: now.subtract(const Duration(days: 120)),
        updatedAt: now,
      ),
      Tank(
        id: 'tank-hostel',
        tankName: 'Hostel Block A Tank',
        location: 'Student Hostel Complex',
        capacity: 10000.0,
        description: 'Hostel drinking and domestic water storage',
        status: TankStatus.online,
        deviceId: 'TANK_002',
        installationDate: now.subtract(const Duration(days: 200)),
        lastCleanedAt: now.subtract(const Duration(days: 14)),
        createdAt: now.subtract(const Duration(days: 200)),
        updatedAt: now,
      ),
      Tank(
        id: 'tank-canteen',
        tankName: 'Central Canteen Tank',
        location: 'Central Dining Hall',
        capacity: 3000.0,
        description: 'Food preparation and drinking water storage',
        status: TankStatus.online,
        deviceId: 'TANK_003',
        installationDate: now.subtract(const Duration(days: 90)),
        lastCleanedAt: now.subtract(const Duration(days: 22)),
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
      ),
      Tank(
        id: 'tank-ro',
        tankName: 'Library RO Tank',
        location: 'Library Building Ground Floor',
        capacity: 2000.0,
        description: 'Filtered RO drinking water storage tank',
        status: TankStatus.online,
        deviceId: 'TANK_004',
        installationDate: now.subtract(const Duration(days: 60)),
        lastCleanedAt: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now,
      ),
    ];

    _devices = {
      'TANK_001': Device(
        id: 'dev-1',
        deviceId: 'TANK_001',
        tankId: 'tank-main',
        deviceName: 'ESP32 Main Academic Unit',
        firmwareVersion: 'v1.2.4',
        isOnline: true,
        lastSeenAt: now,
        powerStatus: PowerStatus.mains,
        batteryVoltage: 4.2,
      ),
      'TANK_002': Device(
        id: 'dev-2',
        deviceId: 'TANK_002',
        tankId: 'tank-hostel',
        deviceName: 'ESP32 Hostel Unit',
        firmwareVersion: 'v1.2.4',
        isOnline: true,
        lastSeenAt: now,
        powerStatus: PowerStatus.mains,
        batteryVoltage: 4.1,
      ),
      'TANK_003': Device(
        id: 'dev-3',
        deviceId: 'TANK_003',
        tankId: 'tank-canteen',
        deviceName: 'ESP32 Canteen Unit',
        firmwareVersion: 'v1.1.0',
        isOnline: true,
        lastSeenAt: now,
        powerStatus: PowerStatus.backup,
        batteryVoltage: 3.8,
      ),
      'TANK_004': Device(
        id: 'dev-4',
        deviceId: 'TANK_004',
        tankId: 'tank-ro',
        deviceName: 'ESP32 Library RO Unit',
        firmwareVersion: 'v1.2.4',
        isOnline: true,
        lastSeenAt: now,
        powerStatus: PowerStatus.mains,
        batteryVoltage: 4.2,
      ),
    };

    // Generate 30 days of realistic history
    _historyMap = {};
    for (var tank in _tanks) {
      _historyMap[tank.id] = _generateHistoryForTank(tank.id, tank.deviceId ?? 'TANK_001');
    }

    _alerts = [
      AlertItem(
        id: 'alert-1',
        tankId: 'tank-canteen',
        deviceId: 'TANK_003',
        alertType: 'cleaning',
        severity: 'CRITICAL',
        title: '🔴 CRITICAL CLEANING REQUIRED: Abnormal Turbidity & Score Drop',
        message: 'High-severity emergency alert: Water Quality Score dropped into Danger Zone (<40/100) due to severe Turbidity peak (4.62 NTU) and floor sediment accumulation in Central Canteen Tank. Immediate tank scrubbing & inspection required.',
        parameter: 'turbidity',
        value: 4.62,
        threshold: 2.5,
        detectedAt: now.subtract(const Duration(hours: 2)),
        isRead: false,
        isResolved: false,
      ),
      AlertItem(
        id: 'alert-2',
        tankId: 'tank-canteen',
        deviceId: 'TANK_003',
        alertType: 'power',
        severity: 'WARNING',
        title: 'Battery Backup Mode Active',
        message: 'Central Canteen Tank device operating on battery backup (Battery: 74%). Mains power supply disconnected.',
        parameter: 'power_source',
        value: 0,
        threshold: 0,
        detectedAt: now.subtract(const Duration(hours: 4)),
        isRead: true,
        isResolved: false,
      ),
    ];

    _cleaningHistory = [
      CleaningRecord(
        id: 'clean-1',
        tankId: 'tank-main',
        cleanedAt: now.subtract(const Duration(days: 6)),
        cleanedBy: 'Rajesh Kumar (Technician)',
        notes: 'Routine quarterly tank cleaning and UV bulb replacement.',
        cleaningMethod: 'High-pressure Jet Wash & Chlorine Sanitization',
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      CleaningRecord(
        id: 'clean-2',
        tankId: 'tank-main',
        cleanedAt: now.subtract(const Duration(days: 32)),
        cleanedBy: 'Suresh Sharma (Technician)',
        notes: 'Sediment removal and tank walls scrubbing',
        cleaningMethod: 'Scrubbing & Flushing',
        createdAt: now.subtract(const Duration(days: 32)),
      ),
      CleaningRecord(
        id: 'clean-3',
        tankId: 'tank-hostel',
        cleanedAt: now.subtract(const Duration(days: 14)),
        cleanedBy: 'Amit Patel (Technician)',
        notes: 'Filter backwash and walls sanitization',
        cleaningMethod: 'Pressure Wash & Descaling',
        createdAt: now.subtract(const Duration(days: 14)),
      ),
      CleaningRecord(
        id: 'clean-4',
        tankId: 'tank-canteen',
        cleanedAt: now.subtract(const Duration(days: 22)),
        cleanedBy: 'Vikram Singh (Technician)',
        notes: 'Food-grade chemical sanitization, sediment vacuuming, and inflow filter replacement.',
        cleaningMethod: 'Chemical Sanitization & Deep Scrubbing',
        createdAt: now.subtract(const Duration(days: 22)),
      ),
      CleaningRecord(
        id: 'clean-5',
        tankId: 'tank-ro',
        cleanedAt: now.subtract(const Duration(days: 9)),
        cleanedBy: 'Rajesh Kumar (Technician)',
        notes: 'RO membrane flush, carbon filter renewal, and UV chamber sterilizing.',
        cleaningMethod: 'RO Membrane Clean & UV Sterilization',
        createdAt: now.subtract(const Duration(days: 9)),
      ),
    ];

    _aiResults = {
      'tank-main': AIAnalysisResult(
        id: 'ai-1',
        tankId: 'tank-main',
        analysisTime: now,
        waterQualityScore: 85,
        status: 'GOOD',
        summary: 'Water-quality parameters are stable following the recent cleaning on 10 Aug 2026.',
        detectedAnomalies: [],
        trend: 'STABLE',
        cleaningRecommendation: false,
        predictedDeterioration: 'Estimated stable duration remaining: 18 days',
        confidence: 0.94,
      ),
      'tank-canteen': AIAnalysisResult(
        id: 'ai-2',
        tankId: 'tank-canteen',
        analysisTime: now,
        waterQualityScore: 61,
        status: 'ATTENTION',
        summary: 'Water quality in Central Canteen Tank is deteriorating. Turbidity peak detected (4.62 NTU).',
        detectedAnomalies: [
          AnomalyItem(parameter: 'turbidity', severity: 'HIGH', reason: 'Rapid spike from baseline of 1.1 NTU')
        ],
        trend: 'DETERIORATING',
        cleaningRecommendation: true,
        predictedDeterioration: 'Immediate tank inspection and cleaning recommended',
        confidence: 0.92,
      ),
    };
  }

  List<SensorReading> _generateHistoryForTank(String tankId, String deviceId) {
    final List<SensorReading> list = [];
    final now = DateTime.now();

    for (int i = 30; i >= 0; i--) {
      final time = now.subtract(Duration(days: i));

      double ph = 7.2 + (_random.nextDouble() * 0.15 - 0.07);
      double tds = 210.0 + (_random.nextDouble() * 10 - 5);
      double turb = 0.9 + (_random.nextDouble() * 0.2);
      double temp = 25.5 + (_random.nextDouble() * 1.0 - 0.5);
      double level = 82.0 + (_random.nextDouble() * 6 - 3);

      // Inject a realistic deterioration curve for tank-main between 8 days ago and 3 days ago
      if (tankId == 'tank-main' && i >= 3 && i <= 8) {
        ph = 6.2 - (8 - i) * 0.05;
        tds = 320.0 + (8 - i) * 35.0;
        turb = 2.2 + (8 - i) * 0.55; // Spikes up to 4.95 NTU
        temp = 28.5 + (8 - i) * 0.4;
      } else if (tankId == 'tank-canteen' && i >= 2 && i <= 5) {
        turb = 1.2 + (5 - i) * 1.1 + (_random.nextDouble() * 0.3);
        tds = 250.0 + (5 - i) * 40.0;
      }

      list.add(SensorReading(
        id: 'hist-$tankId-$i',
        deviceId: deviceId,
        tankId: tankId,
        timestamp: time,
        ph: double.parse(ph.toStringAsFixed(2)),
        tds: double.parse(tds.toStringAsFixed(1)),
        turbidity: double.parse(turb.toStringAsFixed(2)),
        temperature: double.parse(temp.toStringAsFixed(1)),
        waterLevel: double.parse(level.toStringAsFixed(1)),
      ));
    }
    return list;
  }

  void _triggerDeteriorationPeak() {
    final now = DateTime.now();
    final latestReading = SensorReading(
      id: 'sim-peak-${now.millisecondsSinceEpoch}',
      deviceId: 'TANK_001',
      tankId: 'tank-main',
      timestamp: now,
      ph: 6.8,
      tds: 485.0,
      turbidity: 4.62,
      temperature: 28.2,
      waterLevel: 62.0,
    );
    _historyMap['tank-main']?.add(latestReading);
    _streamController.add(latestReading);

    _aiResults['tank-main'] = AIAnalysisResult(
      id: 'ai-sim-${now.millisecondsSinceEpoch}',
      tankId: 'tank-main',
      analysisTime: now,
      waterQualityScore: 58,
      status: 'ATTENTION',
      summary: 'Deterioration scenario triggered! Abnormal turbidity peak detected (4.62 NTU, historical baseline 1.1 NTU).',
      detectedAnomalies: [
        AnomalyItem(parameter: 'turbidity', severity: 'HIGH', reason: 'Spike to 4.62 NTU (+320% from baseline)'),
        AnomalyItem(parameter: 'tds', severity: 'MEDIUM', reason: 'TDS elevated to 485 ppm')
      ],
      trend: 'DETERIORATING',
      cleaningRecommendation: true,
      predictedDeterioration: 'Tank inspection and cleaning recommended immediately',
      confidence: 0.94,
    );

    _alerts.insert(
      0,
      AlertItem(
        id: 'alert-sim-${now.millisecondsSinceEpoch}',
        tankId: 'tank-main',
        deviceId: 'TANK_001',
        alertType: 'cleaning',
        severity: 'WARNING',
        title: 'Water Quality Alert',
        message: 'Water quality in Main Tank is deteriorating. Abnormal turbidity peak detected (4.62 NTU). Please inspect/clean tank.',
        parameter: 'turbidity',
        value: 4.62,
        threshold: 2.5,
        detectedAt: now,
        isRead: false,
        isResolved: false,
      ),
    );
  }

  void _startLiveTicker() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      for (var tank in _tanks) {
        double ph = 7.15 + (_random.nextDouble() * 0.2 - 0.1);
        double tds = 230.0 + (_random.nextDouble() * 8 - 4);
        double turb = 1.1 + (_random.nextDouble() * 0.2 - 0.1);
        double temp = 26.5 + (_random.nextDouble() * 1.0 - 0.5);
        double level = 78.0 + (_random.nextDouble() * 2.0 - 1.0);

        if (_currentScenario == SimulationScenario.deteriorating && tank.id == 'tank-main') {
          turb = 4.62;
          tds = 485.0;
        }

        final reading = SensorReading(
          id: 'tick-${tank.id}-${DateTime.now().millisecondsSinceEpoch}',
          deviceId: tank.deviceId ?? 'TANK_001',
          tankId: tank.id,
          timestamp: DateTime.now(),
          ph: double.parse(ph.toStringAsFixed(2)),
          tds: double.parse(tds.toStringAsFixed(1)),
          turbidity: double.parse(turb.toStringAsFixed(2)),
          temperature: double.parse(temp.toStringAsFixed(1)),
          waterLevel: double.parse(level.toStringAsFixed(1)),
        );

        _historyMap[tank.id]?.add(reading);
        if (_historyMap[tank.id]!.length > 100) {
          _historyMap[tank.id]!.removeAt(0);
        }
        _streamController.add(reading);
      }
    });
  }

  // API Methods
  List<Tank> getTanks() => List.unmodifiable(_tanks);

  Tank? getTankById(String id) {
    try {
      return _tanks.firstWhere((t) => t.id == id);
    } catch (_) {
      return _tanks.first;
    }
  }

  Device? getDeviceForTank(String tankId) => _devices.values.firstWhere((d) => d.tankId == tankId, orElse: () => _devices['TANK_001']!);

  List<SensorReading> getReadingsForTank(String tankId) => _historyMap[tankId] ?? [];

  SensorReading getLatestReading(String tankId) {
    final list = _historyMap[tankId];
    if (list != null && list.isNotEmpty) {
      return list.last;
    }
    return SensorReading(
      id: 'default',
      deviceId: 'TANK_001',
      tankId: tankId,
      timestamp: DateTime.now(),
      ph: 7.2,
      tds: 235.0,
      turbidity: 1.2,
      temperature: 26.5,
      waterLevel: 78.0,
    );
  }

  List<AlertItem> getAlerts() => List.unmodifiable(_alerts);

  List<CleaningRecord> getCleaningHistory([String? tankId]) {
    if (tankId == null || tankId == 'all' || tankId.isEmpty) {
      return List.unmodifiable(_cleaningHistory);
    }
    return _cleaningHistory.where((c) => c.tankId == tankId).toList();
  }

  AIAnalysisResult getAIAnalysis(String tankId) {
    return _aiResults[tankId] ?? AIAnalysisResult(
      id: 'ai-default',
      tankId: tankId,
      analysisTime: DateTime.now(),
      waterQualityScore: 85,
      status: 'GOOD',
      summary: 'Water parameters operate stably against historical baseline.',
      detectedAnomalies: [],
      trend: 'STABLE',
      cleaningRecommendation: false,
      predictedDeterioration: 'No cleaning required currently.',
      confidence: 0.95,
    );
  }

  void recordCleaningEvent(String tankId, String technicianName, String notes, String method) {
    final now = DateTime.now();
    final newRecord = CleaningRecord(
      id: 'clean-${now.millisecondsSinceEpoch}',
      tankId: tankId,
      cleanedAt: now,
      cleanedBy: technicianName,
      notes: notes,
      cleaningMethod: method,
      createdAt: now,
    );
    _cleaningHistory.insert(0, newRecord);

    // Update Tank last cleaned timestamp
    int index = _tanks.indexWhere((t) => t.id == tankId);
    if (index != -1) {
      final old = _tanks[index];
      _tanks[index] = Tank(
        id: old.id,
        tankName: old.tankName,
        location: old.location,
        capacity: old.capacity,
        description: old.description,
        status: old.status,
        deviceId: old.deviceId,
        installationDate: old.installationDate,
        lastCleanedAt: now,
        createdAt: old.createdAt,
        updatedAt: now,
      );
    }

    // Reset AI baseline & trend after cleaning
    _aiResults[tankId] = AIAnalysisResult(
      id: 'ai-reset-${now.millisecondsSinceEpoch}',
      tankId: tankId,
      analysisTime: now,
      waterQualityScore: 92,
      status: 'EXCELLENT',
      summary: 'Tank successfully cleaned on ${now.day} ${_getMonthName(now.month)} ${now.year}. Baseline trend reset to optimal parameters.',
      detectedAnomalies: [],
      trend: 'STABLE',
      cleaningRecommendation: false,
      predictedDeterioration: 'Estimated stable period: 25 days',
      confidence: 0.98,
    );
  }

  void addTank(Tank tank) {
    _tanks.add(tank);
    _historyMap[tank.id] = _generateHistoryForTank(tank.id, tank.deviceId ?? 'TANK_005');
  }

  String _getMonthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }
}
