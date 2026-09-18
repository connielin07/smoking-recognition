import 'dart:math';

class SensorSample {
  const SensorSample({
    required this.timestamp,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });
  final DateTime timestamp;
  final double ax, ay, az, gx, gy, gz;
  double get motionEnergy =>
      sqrt(ax * ax + ay * ay + az * az) + (gx.abs() + gy.abs() + gz.abs()) / 90;
}

class SensorDevice {
  const SensorDevice({
    required this.id,
    required this.name,
    this.connected = false,
  });
  final String id;
  final String name;
  final bool connected;
}

class RecognitionInterval {
  const RecognitionInterval({
    required this.start,
    required this.end,
    required this.confidence,
  });
  final DateTime start;
  final DateTime end;
  final double confidence;
  Duration get duration => end.difference(start);
  Map<String, dynamic> toJson() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'confidence': confidence,
  };
  factory RecognitionInterval.fromJson(Map<String, dynamic> json) =>
      RecognitionInterval(
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        confidence: (json['confidence'] as num).toDouble(),
      );
}

class SmokingSession {
  const SmokingSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.intervals,
  });
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<RecognitionInterval> intervals;
  Duration get totalSmokingDuration => intervals.fold(
    Duration.zero,
    (total, interval) => total + interval.duration,
  );
  Duration get duration => endedAt.difference(startedAt);
  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'intervals': intervals.map((item) => item.toJson()).toList(),
  };
  factory SmokingSession.fromJson(Map<String, dynamic> json) => SmokingSession(
    id: json['id'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    endedAt: DateTime.parse(json['endedAt'] as String),
    intervals: (json['intervals'] as List<dynamic>)
        .map(
          (item) => RecognitionInterval.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
  );
}
