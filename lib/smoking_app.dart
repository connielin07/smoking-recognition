import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';
import 'services.dart';

const _orange = Color(0xfffe7b45),
    _ink = Color(0xff272331),
    _cream = Color(0xfffff8f5);

class SmokingRecognitionApp extends StatefulWidget {
  const SmokingRecognitionApp({super.key});
  @override
  State<SmokingRecognitionApp> createState() => _SmokingRecognitionAppState();
}

class _SmokingRecognitionAppState extends State<SmokingRecognitionApp> {
  final repository = LocalSessionRepository();
  final gateway = SimulatedSensorGateway();
  String? guestName;
  List<SmokingSession> sessions = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await repository.loadGuestName();
    final loaded = await repository.loadSessions();
    if (mounted) {
      setState(() {
        guestName = name;
        sessions = loaded;
        loading = false;
      });
    }
  }

  Future<void> _setName(String name) async {
    await repository.saveGuestName(name);
    setState(() => guestName = name);
  }

  Future<void> _save(SmokingSession session) async {
    await repository.saveSession(session);
    setState(() => sessions = [session, ...sessions]);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '戒菸動作辨識',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _cream,
      colorScheme: ColorScheme.fromSeed(seedColor: _orange),
    ),
    home: loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : guestName == null
        ? GuestScreen(onSubmit: _setName)
        : DashboardScreen(
            name: guestName!,
            sessions: sessions,
            gateway: gateway,
            onSave: _save,
          ),
  );
}

class GuestScreen extends StatefulWidget {
  const GuestScreen({super.key, required this.onSubmit});
  final ValueChanged<String> onSubmit;
  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            const Icon(
              Icons.health_and_safety_outlined,
              color: _orange,
              size: 54,
            ),
            const SizedBox(height: 24),
            const Text(
              '吸菸動作辨識',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '以腕部動作感測，協助你回顧每日的吸菸習慣。',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 34),
            TextField(
              controller: controller,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '訪客暱稱',
                hintText: '例如：小安',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) widget.onSubmit(name);
                },
                child: const Text('開始使用'),
              ),
            ),
            const Spacer(),
            const Text(
              '此為示範原型，結果不作為醫療建議。',
              style: TextStyle(fontSize: 12, color: Colors.black38),
            ),
          ],
        ),
      ),
    ),
  );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.name,
    required this.sessions,
    required this.gateway,
    required this.onSave,
  });
  final String name;
  final List<SmokingSession> sessions;
  final SensorGateway gateway;
  final ValueChanged<SmokingSession> onSave;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<void> _start() async {
    if (!widget.gateway.isConnected) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeviceScreen(gateway: widget.gateway),
        ),
      );
      if (!widget.gateway.isConnected || !mounted) return;
    }
    final result = await Navigator.push<SmokingSession>(
      context,
      MaterialPageRoute(builder: (_) => LiveScreen(gateway: widget.gateway)),
    );
    if (result != null && mounted) {
      widget.onSave(result);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReportScreen(session: result)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.sessions.fold(
      Duration.zero,
      (sum, session) => sum + session.totalSmokingDuration,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日概況'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeviceScreen(gateway: widget.gateway),
              ),
            ).then((_) => setState(() {})),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '你好，${widget.name}',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.gateway.isConnected
                ? '腕部感測器已連線，可以開始辨識。'
                : '請先連接 SmokeSense 腕部感測器。',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          _HeroCard(connected: widget.gateway.isConnected, onStart: _start),
          const SizedBox(height: 18),
          Row(
            children: [
              _Metric(
                label: '累計吸菸次數',
                value:
                    '${widget.sessions.fold(0, (n, s) => n + s.intervals.length)} 次',
              ),
              const SizedBox(width: 12),
              _Metric(label: '累計辨識時間', value: _duration(total)),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '近期紀錄',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistoryScreen(sessions: widget.sessions),
                  ),
                ),
                child: const Text('查看全部'),
              ),
            ],
          ),
          ...widget.sessions
              .take(3)
              .map(
                (s) => _SessionTile(
                  session: s,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReportScreen(session: s)),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.connected, required this.onStart});
  final bool connected;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [_orange, Color(0xffffa36e)]),
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.waving_hand_outlined, color: Colors.white, size: 34),
        const SizedBox(height: 20),
        const Text(
          '開始一次動作辨識',
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          connected ? '感測器已就緒' : '需要先連接腕部感測器',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 18),
        FilledButton.tonal(
          onPressed: onStart,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _orange,
          ),
          child: Text(connected ? '開始辨識' : '管理裝置'),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key, required this.gateway});
  final SensorGateway gateway;
  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  List<SensorDevice> devices = [];
  bool scanning = false;
  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => scanning = true);
    final found = await widget.gateway.scan();
    if (mounted) {
      setState(() {
        devices = found;
        scanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('感測器管理')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.watch_outlined, color: _orange, size: 40),
              SizedBox(height: 12),
              Text(
                '配戴位置：慣用手手腕',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 6),
              Text(
                '將感測器固定於手腕外側，開始前保持靜止 3 秒。',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '附近裝置',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: scanning ? null : _scan,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (scanning)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else
          ...devices.map(
            (d) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xffffede6),
                  child: Icon(Icons.bluetooth, color: _orange),
                ),
                title: Text(d.name),
                subtitle: Text(
                  widget.gateway.isConnected
                      ? '已連線 · 電量 86%'
                      : 'SmokeSense · 可連線',
                ),
                trailing: FilledButton(
                  onPressed: () async {
                    if (widget.gateway.isConnected) {
                      await widget.gateway.disconnect();
                    } else {
                      await widget.gateway.connect(d.id);
                    }
                    if (mounted) setState(() {});
                  },
                  child: Text(widget.gateway.isConnected ? '中斷連線' : '連線'),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key, required this.gateway});
  final SensorGateway gateway;
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final recognizer = SmokingRecognizer();
  final samples = <SensorSample>[];
  StreamSubscription<SensorSample>? subscription;
  late DateTime started;
  Timer? ticker;
  @override
  void initState() {
    super.initState();
    started = DateTime.now();
    subscription = widget.gateway.samples().listen((sample) {
      recognizer.add(sample);
      if (mounted) {
        setState(() {
          samples.add(sample);
          if (samples.length > 90) samples.removeAt(0);
        });
      }
    });
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    ticker?.cancel();
    super.dispose();
  }

  void _finish() {
    final end = DateTime.now();
    final session = SmokingSession(
      id: end.microsecondsSinceEpoch.toString(),
      startedAt: started,
      endedAt: end,
      intervals: recognizer.finish(end),
    );
    Navigator.pop(context, session);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('即時吸菸辨識')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              _clock(DateTime.now().difference(started)),
              style: const TextStyle(
                fontSize: 54,
                color: _orange,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  recognizer.isSmoking
                      ? Icons.smoking_rooms
                      : Icons.accessibility_new,
                  color: recognizer.isSmoking ? _orange : Colors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  recognizer.isSmoking ? '偵測到吸菸動作' : '目前未偵測到吸菸',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            Text(
              '信心度 ${(recognizer.confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '腕部動作訊號',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: CustomPaint(
                        painter: _SignalPainter(samples),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    const Text(
                      '加速度 · X / Y / Z 軸',
                      style: TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _Metric(
              label: '本次偵測事件',
              value:
                  '${recognizer.intervals.length + (recognizer.isSmoking ? 1 : 0)} 次',
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _finish,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('停止並分析'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key, required this.session});
  final SmokingSession session;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('辨識分析報告')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 31,
            backgroundColor: Color(0xffeaf6e9),
            child: Icon(Icons.check, color: Colors.green, size: 36),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            '分析完成！',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text('本次偵測到的吸菸動作'),
              Text(
                '${session.intervals.length} 次',
                style: const TextStyle(
                  fontSize: 42,
                  color: _orange,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Divider(height: 30),
              Text(
                '累計吸菸時間 ${_duration(session.totalSmokingDuration)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '事件明細',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (session.intervals.isEmpty)
          const _EmptyEvents()
        else
          ...session.intervals.asMap().entries.map(
            (entry) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xffffede6),
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(color: _orange),
                  ),
                ),
                title: Text(
                  '${_time(entry.value.start)} - ${_time(entry.value.end)}',
                ),
                subtitle: Text(
                  '信心度 ${(entry.value.confidence * 100).toStringAsFixed(0)}%',
                ),
                trailing: Text(
                  _duration(entry.value.duration),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成並返回'),
          ),
        ),
      ],
    ),
  );
}

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Text('這次沒有偵測到完整的吸菸動作。', textAlign: TextAlign.center),
    ),
  );
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.sessions});
  final List<SmokingSession> sessions;
  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      30,
      (i) => DateTime.now().subtract(Duration(days: 29 - i)),
    );
    final byDay = <String, Duration>{};
    for (final s in sessions) {
      final key = '${s.startedAt.year}-${s.startedAt.month}-${s.startedAt.day}';
      byDay[key] = (byDay[key] ?? Duration.zero) + s.totalSmokingDuration;
    }
    final maxSeconds = max(
      1,
      byDay.values.fold(0, (m, d) => max(m, d.inSeconds)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('歷史趨勢分析')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '近 30 日累計吸菸時間',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 175,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: days.map((day) {
                        final d =
                            byDay['${day.year}-${day.month}-${day.day}'] ??
                            Duration.zero;
                        final h = 10 + 115 * d.inSeconds / maxSeconds;
                        return SizedBox(
                          width: 38,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${d.inSeconds}s',
                                style: const TextStyle(fontSize: 10),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: h,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _orange.withValues(alpha: .75),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '${day.month}/${day.day}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            '近期辨識',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          ...sessions.map(
            (session) => _SessionTile(
              session: session,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportScreen(session: session),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onTap});
  final SmokingSession session;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: const CircleAvatar(
        backgroundColor: Color(0xffffede6),
        child: Icon(Icons.smoking_rooms, color: _orange),
      ),
      title: Text(
        '${session.startedAt.year}/${session.startedAt.month}/${session.startedAt.day} 吸菸辨識',
      ),
      subtitle: Text(
        '${session.intervals.length} 次 · ${_duration(session.totalSmokingDuration)}',
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _SignalPainter extends CustomPainter {
  const _SignalPainter(this.samples);
  final List<SensorSample> samples;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xffeeeeee)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 4),
        Offset(size.width, size.height * i / 4),
        grid,
      );
    }
    if (samples.length < 2) return;
    final lines = [
      const Color(0xfffe7b45),
      const Color(0xff5a9bd5),
      const Color(0xff6fb272),
    ];
    for (var axis = 0; axis < 3; axis++) {
      final path = Path();
      for (var i = 0; i < samples.length; i++) {
        final value = axis == 0
            ? samples[i].ax
            : axis == 1
            ? samples[i].ay
            : samples[i].az - 9.8;
        final x = size.width * i / (samples.length - 1);
        final y = size.height / 2 - value * size.height / 25;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = lines[axis]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SignalPainter old) => old.samples != samples;
}

String _duration(Duration d) => d.inMinutes > 0
    ? '${d.inMinutes} 分 ${d.inSeconds.remainder(60)} 秒'
    : '${d.inSeconds} 秒';
String _clock(Duration d) =>
    '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
