import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

abstract class SensorGateway {
  Future<List<SensorDevice>> scan();
  Future<void> connect(String deviceId);
  Future<void> disconnect();
  Stream<SensorSample> samples();
  bool get isConnected;
}

class SimulatedSensorGateway implements SensorGateway {
  final _controller = StreamController<SensorSample>.broadcast();
  final _random = Random(42);
  Timer? _timer;
  int _tick = 0;
  bool _connected = false;
  @override
  bool get isConnected => _connected;
  @override
  Future<List<SensorDevice>> scan() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return const [
      SensorDevice(id: 'wrist-imu-01', name: 'SmokeSense Wrist IMU'),
    ];
  }

  @override
  Future<void> connect(String deviceId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _timer?.cancel();
    _timer = null;
  }

  @override
  Stream<SensorSample> samples() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (!_connected) return;
      final phase = (_tick % 1000) / 50.0;
      final smoking = (phase >= 4 && phase < 7) || (phase >= 12 && phase < 15);
      final n = (_random.nextDouble() - .5) * .25;
      final a = smoking ? 5.5 : .9;
      _controller.add(
        SensorSample(
          timestamp: DateTime.now(),
          ax: a * sin(_tick / 4) + n,
          ay: a * cos(_tick / 5) + n,
          az: 9.8 + a * sin(_tick / 7) + n,
          gx: (smoking ? 135 : 20) * sin(_tick / 4),
          gy: (smoking ? 110 : 16) * cos(_tick / 5),
          gz: (smoking ? 90 : 12) * sin(_tick / 7),
        ),
      );
      _tick++;
    });
    return _controller.stream;
  }
}

class SmokingRecognizer {
  bool _smoking = false;
  DateTime? _start;
  List<SensorSample> _window = [];
  final List<RecognitionInterval> _completed = [];
  bool get isSmoking => _smoking;
  List<RecognitionInterval> get intervals => List.unmodifiable(_completed);
  double get confidence {
    if (_window.isEmpty) return 0;
    final energy =
        _window.map((s) => s.motionEnergy).reduce((a, b) => a + b) /
        _window.length;
    return ((energy - 8) / 8).clamp(.1, .98);
  }

  void add(SensorSample sample) {
    _window = [..._window, sample];
    if (_window.length > 50) _window.removeAt(0);
    if (_window.length < 25) return;
    final active = confidence >= .55;
    if (active && !_smoking) {
      _smoking = true;
      _start = sample.timestamp;
    } else if (!active && _smoking) {
      _completed.add(
        RecognitionInterval(
          start: _start!,
          end: sample.timestamp,
          confidence: confidence.clamp(.55, .98),
        ),
      );
      _smoking = false;
      _start = null;
    }
  }

  List<RecognitionInterval> finish(DateTime end) {
    if (_smoking && _start != null) {
      _completed.add(
        RecognitionInterval(start: _start!, end: end, confidence: confidence),
      );
    }
    _smoking = false;
    _start = null;
    return intervals;
  }
}

abstract class SessionRepository {
  Future<String?> loadGuestName();
  Future<void> saveGuestName(String name);
  Future<List<SmokingSession>> loadSessions();
  Future<void> saveSession(SmokingSession session);
}

class LocalSessionRepository implements SessionRepository {
  static const _nameKey = 'guest_name', _sessionsKey = 'smoking_sessions';
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();
  @override
  Future<String?> loadGuestName() async => (await _prefs).getString(_nameKey);
  @override
  Future<void> saveGuestName(String name) async {
    await (await _prefs).setString(_nameKey, name);
  }

  @override
  Future<List<SmokingSession>> loadSessions() async {
    final raw = (await _prefs).getString(_sessionsKey);
    if (raw == null) return seedSessions();
    return (jsonDecode(raw) as List<dynamic>)
        .map((item) => SmokingSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveSession(SmokingSession session) async {
    final sessions = await loadSessions();
    await (await _prefs).setString(
      _sessionsKey,
      jsonEncode([session, ...sessions].map((item) => item.toJson()).toList()),
    );
  }
}

List<SmokingSession> seedSessions() {
  final now = DateTime.now();
  return List.generate(4, (index) {
    final end = now.subtract(Duration(days: index + 1, hours: index * 2));
    final start = end.subtract(Duration(minutes: 4 + index));
    return SmokingSession(
      id: 'seed-$index',
      startedAt: start,
      endedAt: end,
      intervals: [
        RecognitionInterval(
          start: start.add(const Duration(minutes: 1)),
          end: start.add(Duration(minutes: 1, seconds: 20 + index * 8)),
          confidence: .82,
        ),
        RecognitionInterval(
          start: start.add(const Duration(minutes: 3)),
          end: end,
          confidence: .76,
        ),
      ],
    );
  });
}
