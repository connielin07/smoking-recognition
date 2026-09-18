import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoking_recognition/models.dart';
import 'package:smoking_recognition/smoking_app.dart';
import 'package:smoking_recognition/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('guest access opens the Chinese dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SmokingRecognitionApp());
    await tester.pumpAndSettle();
    expect(find.text('吸菸動作辨識'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '小安');
    await tester.tap(find.text('開始使用'));
    await tester.pumpAndSettle();
    expect(find.text('你好，小安'), findsOneWidget);
    expect(find.text('開始一次動作辨識'), findsOneWidget);
  });

  test('recognizer creates an interval for a high energy sequence', () {
    final recognizer = SmokingRecognizer();
    final start = DateTime(2026, 1, 1);
    for (var i = 0; i < 30; i++) {
      recognizer.add(
        SensorSample(
          timestamp: start.add(Duration(milliseconds: i * 20)),
          ax: 8,
          ay: 8,
          az: 16,
          gx: 160,
          gy: 140,
          gz: 100,
        ),
      );
    }
    for (var i = 30; i < 100; i++) {
      recognizer.add(
        SensorSample(
          timestamp: start.add(Duration(milliseconds: i * 20)),
          ax: .1,
          ay: .1,
          az: 9.8,
          gx: 1,
          gy: 1,
          gz: 1,
        ),
      );
    }
    expect(recognizer.intervals, hasLength(1));
    expect(recognizer.intervals.single.duration, greaterThan(Duration.zero));
  });

  test('session aggregates smoking duration', () {
    final start = DateTime(2026, 1, 1, 9);
    final session = SmokingSession(
      id: 'test',
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 4)),
      intervals: [
        RecognitionInterval(
          start: start,
          end: start.add(const Duration(seconds: 25)),
          confidence: .8,
        ),
      ],
    );
    expect(session.totalSmokingDuration, const Duration(seconds: 25));
    expect(session.intervals, hasLength(1));
  });
}
