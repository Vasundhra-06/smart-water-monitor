import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../data/models/sensor_reading.dart';

class ThingSpeakHttpService {
  static final ThingSpeakHttpService instance = ThingSpeakHttpService._internal();
  ThingSpeakHttpService._internal() {
    _loadResetPreferences();
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

  bool _isResetMode = false;
  bool get isResetMode => _isResetMode;
  int _resetMinEntryId = 0;
  DateTime? _resetTimestamp;

  Future<void> _loadResetPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isResetMode = prefs.getBool('sensor_reset_mode') ?? false;
      _resetMinEntryId = prefs.getInt('sensor_reset_min_entry_id') ?? 0;
      final ts = prefs.getString('sensor_reset_timestamp');
      if (ts != null) {
        _resetTimestamp = DateTime.tryParse(ts);
      }
      if (_isResetMode) {
        _cachedHistory = [];
        _lastFetchedReading = SensorReading.zero(tankId: 'tank-main');
        _streamController.add(_lastFetchedReading!);
        _historyStreamController.add([]);
      }
    } catch (_) {}
  }

  Future<void> resetAllData() async {
    int maxEntry = int.tryParse(_lastFetchedReading?.id ?? '0') ?? 0;
    for (var r in _cachedHistory) {
      final idNum = int.tryParse(r.id) ?? 0;
      if (idNum > maxEntry) maxEntry = idNum;
    }

    try {
      final thingSpeakUrl = Uri.parse(
        'https://api.thingspeak.com/channels/${AppConstants.thingSpeakChannelId}/feeds/last.json',
      );
      final response = await http.get(thingSpeakUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final int entryId = int.tryParse(data['entry_id']?.toString() ?? '0') ?? 0;
        if (entryId > maxEntry) maxEntry = entryId;
      }
    } catch (_) {}

    _resetMinEntryId = maxEntry;
    _resetTimestamp = DateTime.now();
    _isResetMode = true;
    _cachedHistory = [];

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sensor_reset_mode', true);
      await prefs.setInt('sensor_reset_min_entry_id', _resetMinEntryId);
      await prefs.setString('sensor_reset_timestamp', _resetTimestamp!.toIso8601String());
    } catch (_) {}

    final zeroReading = SensorReading.zero(tankId: 'tank-main');
    _lastFetchedReading = zeroReading;
    _streamController.add(zeroReading);
    _historyStreamController.add([]);
  }

  void _startPolling() {
    // Initial fetch immediately
    fetchLatestReading();
    fetchHistoricalReadings('tank-main');

    // Poll ThingSpeak every 15 seconds to respect ThingSpeak rates
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final reading = await fetchLatestReading();
      if (!_isResetMode) {
        if (_cachedHistory.isEmpty || (_cachedHistory.isNotEmpty && _cachedHistory.last.id != reading.id)) {
          await fetchHistoricalReadings('tank-main');
        }
      }
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
          final int entryId = int.tryParse(data['entry_id']?.toString() ?? '0') ?? 0;

          if (_isResetMode) {
            if (entryId > _resetMinEntryId) {
              // Fresh reading received after reset! Automatically exit reset mode and stream new values
              _isResetMode = false;
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('sensor_reset_mode', false);
              } catch (_) {}
              final reading = SensorReading.fromThingSpeakBackendJson(data, tankId: tankId);
              _lastFetchedReading = reading;
              _streamController.add(reading);
              return reading;
            } else {
              // Still awaiting sensor dipping
              final zero = SensorReading.zero(tankId: tankId);
              _lastFetchedReading = zero;
              return zero;
            }
          }

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
        final int entryId = int.tryParse(data['entry_id']?.toString() ?? '0') ?? 0;

        if (_isResetMode) {
          if (entryId > _resetMinEntryId) {
            _isResetMode = false;
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('sensor_reset_mode', false);
            } catch (_) {}
            final reading = SensorReading.fromThingSpeakBackendJson(data, tankId: tankId);
            _lastFetchedReading = reading;
            _streamController.add(reading);
            return reading;
          } else {
            final zero = SensorReading.zero(tankId: tankId);
            _lastFetchedReading = zero;
            return zero;
          }
        }

        final reading = SensorReading.fromThingSpeakBackendJson(data, tankId: tankId);
        _lastFetchedReading = reading;
        _streamController.add(reading);
        return reading;
      }
    } catch (_) {}

    // 3. Fallback to cached reading or baseline if offline
    if (_isResetMode) {
      return SensorReading.zero(tankId: tankId);
    }
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
          var list = feeds
              .map((item) => SensorReading.fromThingSpeakBackendJson(item, tankId: tankId))
              .toList();

          if (_isResetMode) {
            list = list.where((r) => (int.tryParse(r.id) ?? 0) > _resetMinEntryId).toList();
            if (list.isEmpty) {
              _cachedHistory = [];
              _historyStreamController.add([]);
              return [];
            } else {
              _isResetMode = false;
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('sensor_reset_mode', false);
              } catch (_) {}
            }
          } else {
            list = list.where((r) => r.timestamp.isAfter(DateTime(2026, 10, 1)) && (int.tryParse(r.id) ?? 999) >= 27).toList();
          }

          // Deduplicate readings with identical entry IDs
          final deduplicated = <SensorReading>[];
          final seenIds = <String>{};
          for (final r in list) {
            if (seenIds.add(r.id)) {
              deduplicated.add(r);
            }
          }

          if (deduplicated.isNotEmpty) {
            _cachedHistory = deduplicated;
            _historyStreamController.add(deduplicated);
            return deduplicated;
          } else if (_isResetMode) {
            _cachedHistory = [];
            _historyStreamController.add([]);
            return [];
          }
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
          final listMapped = list
              .map((item) => SensorReading.fromThingSpeakBackendJson(item, tankId: tankId))
              .where((r) => r.timestamp.isAfter(DateTime(2026, 10, 1)) && (int.tryParse(r.id) ?? 999) >= 27)
              .toList();
          if (listMapped.isNotEmpty) {
            _cachedHistory = listMapped;
            _historyStreamController.add(listMapped);
            return listMapped;
          }
        }
      }
    } catch (_) {}

    if (_isResetMode) {
      _cachedHistory = [];
      _historyStreamController.add([]);
      return [];
    }

    if (_cachedHistory.isNotEmpty) {
      return _cachedHistory;
    }

    // Fallback
    final latest = await fetchLatestReading(tankId: tankId);
    return latest.isZero ? [] : [latest];
  }

  void dispose() {
    _pollingTimer?.cancel();
    _streamController.close();
    _historyStreamController.close();
  }
}
