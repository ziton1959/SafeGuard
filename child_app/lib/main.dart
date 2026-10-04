import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

const String childId = 'bd6b71ef-8e6e-4dcc-9822-6a30ba587f24';
const String baseUrl = 'http://10.0.2.2:8000';
const platform = MethodChannel('safeguard/ocr');

// ---- Kid-friendly palette (green guardian theme) ----
const Color kGreen = Color(0xFF2EB872);
const Color kGreenDark = Color(0xFF1C9D5E);
const Color kMint = Color(0xFFDFF5EA);
const Color kSky = Color(0xFF4FC3E8);
const Color kSun = Color(0xFFFFC65C);
const Color kCoral = Color(0xFFFF6B6B);
const Color kBg = Color(0xFFF0FBF5);
const Color kCard = Colors.white;
const Color kInk = Color(0xFF243830);
const Color kInkSoft = Color(0xFF6B8378);

void main() => runApp(const SafeGuardApp());

class SafeGuardApp extends StatelessWidget {
  const SafeGuardApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kGreen,
          primary: kGreen,
          surface: kBg,
        ),
        fontFamily: 'Roboto',
      ),
      home: const RootNav(),
    );
  }
}

class RootNav extends StatefulWidget {
  const RootNav({super.key});
  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _index = 0;
  Timer? _monitorTimer;
  bool _monitoring = false;
  int _scanCount = 0;
  int _flagCount = 0;
  String _lastScanned = '';
  String _status = 'Resting';

  Future<void> _toggleMonitoring() async {
    if (_monitoring) {
      _monitorTimer?.cancel();
      await platform.invokeMethod('stopMonitoring');
      setState(() {
        _monitoring = false;
        _status = 'Resting';
      });
      return;
    }
    try {
      final res = await platform.invokeMethod('startMonitoring');
      if (res == 'monitoring_started') {
        setState(() {
          _monitoring = true;
          _scanCount = 0;
          _flagCount = 0;
          _status = 'Watching over you';
        });
        _monitorTimer = Timer.periodic(
          const Duration(seconds: 4),
          (_) => _scanOnce(),
        );
      } else {
        setState(() => _status = 'Could not start ($res)');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _scanOnce() async {
    try {
      final ocrText = await platform.invokeMethod('grabFrame');
      final text = ocrText?.toString() ?? '';
      if (text.isEmpty || text.startsWith('(')) return;
      if (text == _lastScanned) return;
      _lastScanned = text;
      _scanCount++;
      final response = await http.post(
        Uri.parse('$baseUrl/children/$childId/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'source': 'screen_ocr'}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final events = (data['events_created'] ?? []) as List;
        if (events.isNotEmpty) _flagCount++;
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(monitoring: _monitoring, status: _status),
      const ChatScreen(),
      MonitoringScreen(
        monitoring: _monitoring,
        scanCount: _scanCount,
        flagCount: _flagCount,
        status: _status,
        onToggle: _toggleMonitoring,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: kCard,
          boxShadow: [
            BoxShadow(
              color: kGreen.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          height: 68,
          backgroundColor: kCard,
          indicatorColor: kMint,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded, color: kInkSoft),
              selectedIcon: Icon(Icons.home_rounded, color: kGreen),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_rounded, color: kInkSoft),
              selectedIcon: Icon(Icons.forum_rounded, color: kGreen),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.shield_rounded, color: kInkSoft),
              selectedIcon: Icon(Icons.shield_rounded, color: kGreen),
              label: 'Guard',
            ),
          ],
        ),
      ),
    );
  }
}

class GuardianShield extends StatefulWidget {
  final bool active;
  final double size;
  const GuardianShield({super.key, required this.active, this.size = 150});
  @override
  State<GuardianShield> createState() => _GuardianShieldState();
}

class _GuardianShieldState extends State<GuardianShield>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? kGreen : kInkSoft;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final pulse = widget.active ? (0.95 + _c.value * 0.1) : 1.0;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: widget.active ? (1.0 + _c.value * 0.25) : 1.0,
                child: Container(
                  width: widget.size * 0.85,
                  height: widget.size * 0.85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(widget.active ? 0.12 : 0.08),
                  ),
                ),
              ),
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: widget.size * 0.6,
                  height: widget.size * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.active
                          ? [kGreen, kGreenDark]
                          : [kInkSoft, kInkSoft],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.active
                        ? Icons.shield_rounded
                        : Icons.shield_outlined,
                    color: Colors.white,
                    size: widget.size * 0.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  final bool monitoring;
  final String status;
  const HomeScreen({super.key, required this.monitoring, required this.status});

  Future<Position?> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
        if (p == LocationPermission.denied) return null;
      }
      if (p == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendSOS(BuildContext context) async {
    final pos = await _getLocation();
    final loc = pos != null
        ? 'Location: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)} '
              '(https://maps.google.com/?q=${pos.latitude},${pos.longitude})'
        : 'Location: unavailable';
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/events'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'child_id': childId,
          'type': 'sos',
          'content': 'SOS - child requested help. $loc',
          'severity': 'high',
        }),
      );
      if (r.statusCode == 200 && context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: const Icon(Icons.favorite_rounded, color: kGreen, size: 48),
            title: const Text('Help is coming!'),
            content: Text(
              pos != null
                  ? 'Your grown-up got your message and your location.'
                  : 'Your grown-up got your message.',
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kGreen),
                onPressed: () => Navigator.pop(context),
                child: const Text('Okay'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send. Try again.')),
        );
      }
    }
  }

  void _confirmSOS(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.emergency_rounded, color: kCoral, size: 44),
        title: const Text('Send an SOS?'),
        content: const Text(
          'This tells your grown-up you need help right now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kCoral),
            onPressed: () {
              Navigator.pop(context);
              _sendSOS(context);
            },
            child: const Text('Yes, help!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Hi there!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'SafeGuard is here with you',
                  style: TextStyle(fontSize: 15, color: kInkSoft),
                ),
              ],
            ),
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: kSun,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wb_sunny_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: monitoring
                  ? [kMint, const Color(0xFFCDEFFB)]
                  : [const Color(0xFFEDEFEE), const Color(0xFFF5F7F6)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              GuardianShield(active: monitoring, size: 150),
              const SizedBox(height: 12),
              Text(
                monitoring ? 'All good!' : 'Taking a break',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: const TextStyle(fontSize: 14, color: kInkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => _confirmSOS(context),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8A5C), kCoral],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: kCoral.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emergency_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Need help now?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tap to send an SOS to your grown-up',
                        style: TextStyle(fontSize: 13, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'How SafeGuard helps you',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: kInk,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _tile(
                Icons.chat_rounded,
                'Kind words',
                kSky,
                'Spots mean messages',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tile(
                Icons.visibility_rounded,
                'Safe screen',
                kGreen,
                'Watches for bad stuff',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _tile(
                Icons.favorite_rounded,
                'You matter',
                kCoral,
                'Help is one tap away',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tile(
                Icons.emoji_emotions_rounded,
                'Be you',
                kSun,
                'Play and learn safely',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tile(IconData icon, String title, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 12, color: kInkSoft)),
        ],
      ),
    );
  }
}

class Message {
  final String text;
  final bool flagged;
  final String? reason;
  Message({required this.text, this.flagged = false, this.reason});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final List<Message> _messages = [];
  bool _sending = false;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/children/$childId/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'source': 'chat'}),
      );
      bool flagged = false;
      String? reason;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final events = (data['events_created'] ?? []) as List;
        flagged = events.isNotEmpty;
        reason = (data['result'] ?? {})['layer2_reason'];
      }
      setState(() {
        _messages.add(Message(text: text, flagged: flagged, reason: reason));
        _controller.clear();
      });
    } catch (_) {
      setState(() {
        _messages.add(Message(text: '$text  (not sent)'));
        _controller.clear();
      });
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kSky.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.forum_rounded, color: kSky, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Messages',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: const BoxDecoration(
                          color: kMint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.waving_hand_rounded,
                          color: kGreen,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Say hi to start!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kInk,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final m = _messages[i];
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(13),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: m.flagged ? const Color(0xFFFFE9E9) : kGreen,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(4),
                          ),
                          border: m.flagged
                              ? Border.all(color: kCoral, width: 1.4)
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.text,
                              style: TextStyle(
                                fontSize: 15,
                                color: m.flagged ? kInk : Colors.white,
                              ),
                            ),
                            if (m.flagged) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: const [
                                  Icon(
                                    Icons.favorite_border_rounded,
                                    color: kCoral,
                                    size: 15,
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Let\'s use kinder words',
                                      style: TextStyle(
                                        color: kCoral,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: kInk),
                  decoration: InputDecoration(
                    hintText: 'Write something nice...',
                    filled: true,
                    fillColor: kCard,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: kGreen, width: 1.6),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: kGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class MonitoringScreen extends StatelessWidget {
  final bool monitoring;
  final int scanCount;
  final int flagCount;
  final String status;
  final VoidCallback onToggle;
  const MonitoringScreen({
    super.key,
    required this.monitoring,
    required this.scanCount,
    required this.flagCount,
    required this.status,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        const Text(
          'Screen Guard',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: kInk,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'I keep an eye on your screen to keep it friendly.',
          style: TextStyle(fontSize: 14, color: kInkSoft),
        ),
        const SizedBox(height: 20),
        Center(child: GuardianShield(active: monitoring, size: 160)),
        const SizedBox(height: 8),
        Center(
          child: Text(
            monitoring ? 'Watching over you' : 'Resting',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: monitoring ? kGreen : kInkSoft,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _stat('Checks', '$scanCount', kSky)),
            const SizedBox(width: 12),
            Expanded(child: _stat('Caught', '$flagCount', kCoral)),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 58,
          child: FilledButton.icon(
            onPressed: onToggle,
            style: FilledButton.styleFrom(
              backgroundColor: monitoring ? kCoral : kGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: Icon(
              monitoring ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 26,
            ),
            label: Text(
              monitoring ? 'Take a break' : 'Start guarding',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: kInkSoft)),
        ],
      ),
    );
  }
}
