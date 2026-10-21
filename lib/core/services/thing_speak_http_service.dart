import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../data/models/sensor_reading.dart';

class ThingSpeakHttpService {
  static final ThingSpeakHttpService instance = ThingSpeakHttpService._internal();
  ThingSpeakHttpService._internal() {
    _clearOldResetMode(); // Always clear stale reset flags on startup
    _startPolling();
  }

  final _streamController = StreamController<SensorReading>.broadcast();
  Stream<SensorReading> get liveSensorStream => _streamController.stream;

  final _historyStreamController = StreamController<List<SensorReading>>.broadcast();
  Stream<List<SensorReading>> get historyStream => _historyStreamController.stream;

  List<SensorReading> _cachedHistory = [];
  List<SensorReading> get cachedHistory => List.unmodifiable(_cachedHistory);

  Timer? _pollingTimer;
  SensorReading? _lastFetchedReading;
  SensorReading? get latestCachedReading => _lastFetchedReading;

  // Reset mode permanently disabled — always show live data
  bool get isResetMode => false;
  int get _resetMinEntryId => 0;

  // Clears any stale reset mode stored from previous sessions
  Future<void> _clearOldResetMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sensor_reset_mode', false);
      await prefs.remove('sensor_reset_min_entry_id');
      await prefs.remove('sensor_reset_timestamp');
    } catch (_) {}
  }

  // Kept for UI button compatibility — now just refreshes live data
  Future<void> resetAllData() async {
    await _clearOldResetMode();
    await fetchLatestReading();
    await fetchHistoricalReadings('tank-main');
  }

  // Kept for UI button compatibility — now just refreshes live data
  Future<void> exitResetMode({String tankId = 'tank-main'}) async {
    await _clearOldResetMode();
    await fetchLatestReading(tankId: tankId);
    await fetchHistoricalReadings(tankId);
  }

  void _startPolling() {
    fetchLatestReading();
    fetchHistoricalReadings('tank-main');
    // Poll every 15 seconds (ThingSpeak minimum rate limit)
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await fetchLatestReading();
      await fetchHistoricalReadings('tank-main');
    });
  }

  Future<SensorReading> fetchLatestReading({String tankId = 'tank-main'}) async {
    try {
      final thingSpeakUrl = Uri.parse(
        'https://api.thingspeak.com/channels/${AppConstants.thingSpeakChannelId}/feeds/last.json',
      );
      final response = await http.get(thingSpeakUrl).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('entry_id') && data['entry_id'] != null) {
          // Always stream real data — no reset mode blocking
          final reading = SensorReading.fromThingSpeakBackendJson(data, tankId: tankId);
          _lastFetchedReading = reading;
          _streamController.add(reading);
          return reading;
        }
      }
    } catch (_) {}
    if (_lastFetchedReading != null) return _lastFetchedReading!;
    return SensorReading.zero(tankId: tankId);
  }

  Future<List<SensorReading>> fetchHistoricalReadings(String tankId, {int results = 50}) async {
    try {
      final thingSpeakUrl = Uri.parse(
        'https://api.thingspeak.com/channels/${AppConstants.thingSpeakChannelId}/feeds.json?results=$results',
      );
      final response = await http.get(thingSpeakUrl).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = json.decode(response.body);
        final List<dynamic> feeds = jsonBody['feeds'] ?? [];
        if (feeds.isNotEmpty) {
          // Show ALL real readings, no filtering by reset mode
          final list = feeds
              .map((item) => SensorReading.fromThingSpeakBackendJson(item, tankId: tankId))
              .where((r) => !r.isZero)
              .toList();
          final seen = <String>{};
          final deduped = list.where((r) => seen.add(r.id)).toList();
          if (deduped.isNotEmpty) {
            _cachedHistory = deduped;
            _historyStreamController.add(deduped);
            return deduped;
          }
        }
      }
    } catch (_) {}
    if (_cachedHistory.isNotEmpty) return _cachedHistory;
    return [];
  }

  void dispose() {
    _pollingTimer?.cancel();
    _streamController.close();
    _historyStreamController.close();
  }
}
