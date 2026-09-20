import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../../data/models/sensor_reading.dart';

class ThingSpeakHttpService {
  static final ThingSpeakHttpService instance = ThingSpeakHttpService._internal();
  ThingSpeakHttpService._internal() {
    _startPolling();
  }

  final _streamController = StreamController<SensorReading>.broadcast();
  Stream<SensorReading> get liveSensorStream => _streamController.stream;

  Timer? _pollingTimer;
  SensorReading? _lastFetchedReading;
  SensorReading? get latestCachedReading => _lastFetchedReading;

  void _startPolling() {
    // Initial fetch immediately
    fetchLatestReading();

    // Poll Python backend every 15 seconds to respect ThingSpeak rates
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      fetchLatestReading();
    });
  }

  Future<SensorReading> fetchLatestReading({String tankId = 'tank-main'}) async {
    // 1. Direct ThingSpeak Cloud API (Real-time live feeds)
    try {
      final thingSpeakUrl = Uri.parse(
        'https://api.thingspeak.com/channels/${AppConstants.thingSpeakChannelId}/feeds/last.json',
      );
      final response = await http.get(thingSpeakUrl).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('entry_id') && data['entry_id'] != null) {
          final reading = SensorReading.fromThingSpeakBackendJson(data, tankId: tankId);
          _lastFetchedReading = reading;
          _streamController.add(reading);
          return reading;
        }
      }
    } catch (_) {
      // Fall through to backend API if ThingSpeak direct call encounters network issue
    }

    // 2. Try configured Backend API endpoint (e.g., Render / localhost)
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/v1/water-quality/latest');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final Map<String, dynamic> data = (body['data'] is Map<String, dynamic>)
            ? (body['data'] as Map<String, dynamic>)
            : body;
        final reading = SensorReading.fromThingSpeakBackendJson(data, tankId: tankId);
        _lastFetchedReading = reading;
        _streamController.add(reading);
        return reading;
      }
    } catch (_) {}

    // 3. Fallback to cached reading or baseline if offline
    if (_lastFetchedReading != null) {
      return _lastFetchedReading!;
    }
    final fallback = SensorReading(
      id: 'fallback',
      deviceId: 'ESP32_OFFLINE',
      tankId: tankId,
      timestamp: DateTime.now(),
      ph: 7.2,
      tds: 235.0,
      turbidity: 1.2,
      temperature: 26.5,
      waterLevel: 78.0,
    );
    return fallback;
  }

  Future<List<SensorReading>> fetchHistoricalReadings(String tankId, {int results = 50}) async {
    // 1. Direct ThingSpeak Cloud API (Real-time history)
    try {
      final thingSpeakUrl = Uri.parse(
        'https://api.thingspeak.com/channels/${AppConstants.thingSpeakChannelId}/feeds.json?results=$results',
      );
      final response = await http.get(thingSpeakUrl).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = json.decode(response.body);
        final List<dynamic> feeds = jsonBody['feeds'] ?? [];
        if (feeds.isNotEmpty) {
          return feeds.map((item) => SensorReading.fromThingSpeakBackendJson(item, tankId: tankId)).toList();
        }
      }
    } catch (_) {}

    // 2. Try configured Backend API endpoint
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/v1/water-quality/history?results=$results');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = json.decode(response.body);
        final List<dynamic> list = jsonBody['data'] ?? [];
        if (list.isNotEmpty) {
          return list.map((item) => SensorReading.fromThingSpeakBackendJson(item, tankId: tankId)).toList();
        }
      }
    } catch (_) {}

    // Fallback
    final latest = await fetchLatestReading(tankId: tankId);
    return [latest];
  }

  void dispose() {
    _pollingTimer?.cancel();
    _streamController.close();
  }
}
