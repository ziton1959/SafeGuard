import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';

const String baseUrl = 'http://10.0.2.2:8000';
const int pageSize = 10;

// ---- Calm green theme ----
const Color kGreen = Color(0xFF2EB872);
const Color kGreenDark = Color(0xFF1C7A4F);
const Color kMint = Color(0xFFDFF5EA);
const Color kSky = Color(0xFF4FA3C7);
const Color kAmber = Color(0xFFE0A23B);
const Color kCoral = Color(0xFFE4604E);
const Color kBg = Color(0xFFF2F8F5);
const Color kCard = Colors.white;
const Color kInk = Color(0xFF1F2E29);
const Color kInkSoft = Color(0xFF647A72);

void main() => runApp(const ParentApp());

class ParentApp extends StatelessWidget {
  const ParentApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeGuard Parent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(
            seedColor: kGreen, primary: kGreen, surface: kBg),
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}

// ============================================================
// LOGIN
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String _error = '';

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/parents/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'email': _email.text.trim(), 'password': _password.text}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              parentId: data['id'],
              parentName: data['full_name'] ?? 'Parent',
            ),
          ),
        );
      } else {
        setState(() => _error = 'Wrong email or password.');
      }
    } catch (e) {
      setState(() => _error = 'Can\'t reach the server. Is it running?');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [kGreen, kGreenDark]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: kGreen.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: const Icon(Icons.shield_rounded,
                        color: Colors.white, size: 42),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('SafeGuard',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                        letterSpacing: -0.5)),
                const SizedBox(height: 6),
                const Text('Your family\'s safety, in one place',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: kInkSoft)),
                const SizedBox(height: 40),
                _field(_email, 'Email', Icons.mail_outline, false),
                const SizedBox(height: 16),
                _field(_password, 'Password', Icons.lock_outline, true),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error,
                        style: const TextStyle(color: kCoral, fontSize: 13)),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _loading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: kGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Sign in',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
      TextEditingController c, String hint, IconData icon, bool obscure) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: const TextStyle(color: kInk),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: kInkSoft, size: 20),
        filled: true,
        fillColor: kCard,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kGreen, width: 1.6),
        ),
      ),
    );
  }
}

// ============================================================
// HOME
// ============================================================
class HomeScreen extends StatefulWidget {
  final String parentId;
  final String parentName;
  const HomeScreen(
      {super.key, required this.parentId, required this.parentName});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _children = [];
  Map<String, int> _alertCounts = {};
  int _totalAlerts = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _alertCounts = {};
    _totalAlerts = 0;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/parents/${widget.parentId}/children'));
      if (res.statusCode == 200) {
        final kids = jsonDecode(res.body) as List;
        _children = kids;
        for (final c in kids) {
          try {
            final er = await http.get(Uri.parse(
                '$baseUrl/children/${c['id']}/events?limit=1000&offset=0'));
            if (er.statusCode == 200) {
              final n = (jsonDecode(er.body) as List).length;
              _alertCounts[c['id']] = n;
              _totalAlerts += n;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _logout() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, ${widget.parentName}',
                            style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                color: kInk,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 3),
                        const Text('Here\'s how your family is doing today',
                            style: TextStyle(fontSize: 15, color: kInkSoft)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, color: kInkSoft),
                    tooltip: 'Sign out',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child:
                      Center(child: CircularProgressIndicator(color: kGreen)),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kGreen, kGreenDark]),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                          color: kGreen.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: Row(
                    children: [
                      _overviewStat(
                          '${_children.length}',
                          _children.length == 1 ? 'child' : 'children',
                          Icons.people_rounded),
                      Container(
                          width: 1,
                          height: 46,
                          color: Colors.white.withOpacity(0.25)),
                      _overviewStat('$_totalAlerts',
                          _totalAlerts == 1 ? 'alert' : 'alerts',
                          Icons.notifications_rounded),
                      Container(
                          width: 1,
                          height: 46,
                          color: Colors.white.withOpacity(0.25)),
                      _overviewStat(
                          '24/7', 'watching', Icons.visibility_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('What SafeGuard protects',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: kInk)),
                const SizedBox(height: 12),
                _protectRow(Icons.record_voice_over_rounded, kSky,
                    'Hurtful language',
                    'Catches offensive words, incl. Tunisian Derja & Arabizi'),
                _protectRow(Icons.sentiment_very_dissatisfied_rounded, kAmber,
                    'Cyberbullying',
                    'Detects harassment and hurtful patterns in messages'),
                _protectRow(Icons.screenshot_monitor_rounded, kGreen,
                    'Screen content',
                    'Scans what\'s on screen for harmful content'),
                _protectRow(Icons.emergency_rounded, kCoral, 'Emergency SOS',
                    'Your child can send an instant alert with their location'),
                const SizedBox(height: 24),
                const Text('Your children',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: kInk)),
                const SizedBox(height: 12),
                if (_children.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      children: [
                        Icon(Icons.family_restroom_rounded,
                            size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No children linked yet',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: kInk)),
                      ],
                    ),
                  )
                else
                  ..._children.map((c) => _childCard(c)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _overviewStat(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.0)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _protectRow(IconData icon, Color color, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: kInk)),
                const SizedBox(height: 2),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 12, color: kInkSoft, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _childCard(dynamic child) {
    final count = _alertCounts[child['id']] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AlertsScreen(
                  childId: child['id'], childName: child['name'] ?? 'Child'),
            ),
          ).then((_) => _load()),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                      color: kMint, borderRadius: BorderRadius.circular(16)),
                  child: Center(
                    child: Text(
                      (child['name'] ?? '?')
                          .toString()
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                          color: kGreenDark,
                          fontSize: 23,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(child['name'] ?? 'Child',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: kInk)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                              count > 0
                                  ? Icons.notifications_active_rounded
                                  : Icons.check_circle_rounded,
                              size: 15,
                              color: count > 0 ? kCoral : kGreen),
                          const SizedBox(width: 5),
                          Text(
                            count > 0
                                ? '$count alert${count == 1 ? '' : 's'}'
                                : 'All clear',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: count > 0 ? kCoral : kGreen),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: kInkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ALERTS + SUMMARY + FILTER + PAGINATION
// ============================================================
class AlertsScreen extends StatefulWidget {
  final String childId;
  final String childName;
  const AlertsScreen(
      {super.key, required this.childId, required this.childName});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> _all = [];
  final List<dynamic> _visible = [];
  int _offset = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _filter = 'all';

  final _filters = const [
    {'key': 'all', 'label': 'All'},
    {'key': 'language', 'label': 'Language'},
    {'key': 'bullying', 'label': 'Bullying'},
    {'key': 'sos', 'label': 'SOS'},
    {'key': 'screen', 'label': 'Screen'},
  ];

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    setState(() => _loading = true);
    _all = [];
    _visible.clear();
    _offset = 0;
    _hasMore = true;
    try {
      final res = await http.get(Uri.parse(
          '$baseUrl/children/${widget.childId}/events?limit=1000&offset=0'));
      if (res.statusCode == 200) _all = jsonDecode(res.body);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await http.get(Uri.parse(
          '$baseUrl/children/${widget.childId}/events?limit=$pageSize&offset=$_offset'));
      if (res.statusCode == 200) {
        final page = jsonDecode(res.body) as List;
        _visible.addAll(page);
        _offset += page.length;
        if (page.length < pageSize) _hasMore = false;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingMore = false);
  }

  int _countOf(String type) => _all.where((e) => e['type'] == type).length;

  List<dynamic> get _filteredVisible {
    if (_filter == 'all') return _visible;
    if (_filter == 'screen') {
      return _visible
          .where((e) =>
              (e['content'] ?? '').toString().contains('[screen_ocr]'))
          .toList();
    }
    return _visible.where((e) => e['type'] == _filter).toList();
  }

  Color _sevColor(String? s) {
    switch (s) {
      case 'high':
        return kCoral;
      case 'medium':
        return kAmber;
      default:
        return kSky;
    }
  }

  IconData _typeIcon(String? t) {
    switch (t) {
      case 'language':
        return Icons.record_voice_over_rounded;
      case 'bullying':
        return Icons.sentiment_very_dissatisfied_rounded;
      case 'sos':
        return Icons.emergency_rounded;
      case 'duration':
        return Icons.timer_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  String? _mapUrl(String content) {
    final urlMatch = RegExp(r'https?://[^\s)]+').firstMatch(content);
    if (urlMatch != null) return urlMatch.group(0);
    final coordMatch =
        RegExp(r'(-?\d+\.\d+),\s*(-?\d+\.\d+)').firstMatch(content);
    if (coordMatch != null) {
      return 'https://maps.google.com/?q=${coordMatch.group(1)},${coordMatch.group(2)}';
    }
    return null;
  }

  Future<void> _openMap(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the map.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredVisible;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        foregroundColor: kInk,
        title: Text(widget.childName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Screen time',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScreenTimeScreen(
                    childId: widget.childId, childName: widget.childName),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Monitoring settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                    childId: widget.childId, childName: widget.childName),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : RefreshIndicator(
              onRefresh: _initialLoad,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _summaryCard(),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _filters.map((f) {
                        final sel = _filter == f['key'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f['label'] as String),
                            selected: sel,
                            onSelected: (_) =>
                                setState(() => _filter = f['key'] as String),
                            selectedColor: kGreen,
                            backgroundColor: kCard,
                            labelStyle: TextStyle(
                                color: sel ? Colors.white : kInkSoft,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                    color:
                                        sel ? kGreen : Colors.grey.shade200)),
                            showCheckmark: false,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(
                        children: [
                          Icon(Icons.verified_user_rounded,
                              size: 56, color: kGreen.withOpacity(0.4)),
                          const SizedBox(height: 14),
                          Text(
                              _filter == 'all'
                                  ? 'All clear'
                                  : 'Nothing in this category yet',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: kInk)),
                        ],
                      ),
                    )
                  else ...[
                    ...list.map((e) => _alertCard(e)),
                    if (_hasMore && _filter == 'all')
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator(color: kGreen)
                              : OutlinedButton.icon(
                                  onPressed: _loadMore,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kGreen,
                                    side: const BorderSide(color: kGreen),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(Icons.expand_more_rounded),
                                  label: const Text('Load more'),
                                ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kGreen, kGreenDark]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: kGreen.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_all.length}',
              style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.0)),
          const SizedBox(height: 2),
          const Text('alerts recorded',
              style: TextStyle(fontSize: 14, color: Colors.white)),
          const SizedBox(height: 18),
          Row(
            children: [
              _summaryStat('Bad language', _countOf('language')),
              _divider(),
              _summaryStat('Bullying', _countOf('bullying')),
              _divider(),
              _summaryStat('SOS', _countOf('sos')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 34, color: Colors.white.withOpacity(0.25));

  Widget _alertCard(dynamic e) {
    final sev = e['severity'] as String?;
    final type = e['type'] as String?;
    final color = _sevColor(sev);
    final content = (e['content'] ?? '').toString();
    final when = (e['created_at'] ?? '')
        .toString()
        .replaceFirst('T', '  ')
        .split('.')
        .first;
    final isSos = type == 'sos';
    final mapUrl = isSos ? _mapUrl(content) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(_typeIcon(type), color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text((type ?? 'alert').replaceAll('_', ' '),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                          const Spacer(),
                          if (sev != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(sev,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: color)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, color: kInk, height: 1.3)),
                      const SizedBox(height: 6),
                      Text(when,
                          style:
                              const TextStyle(fontSize: 12, color: kInkSoft)),
                    ],
                  ),
                ),
              ],
            ),
            if (mapUrl != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openMap(mapUrl),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kCoral,
                    side: const BorderSide(color: kCoral),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.location_on_rounded, size: 18),
                  label: const Text('View location on map'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SCREEN TIME (donut chart + clean legend)
// ============================================================
class ScreenTimeScreen extends StatefulWidget {
  final String childId;
  final String childName;
  const ScreenTimeScreen(
      {super.key, required this.childId, required this.childName});
  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen> {
  List<dynamic> _apps = [];
  int _totalSeconds = 0;
  bool _loading = true;
  int _touched = -1;

  final _palette = const [
    Color(0xFF2EB872),
    Color(0xFF4FA3C7),
    Color(0xFFE0A23B),
    Color(0xFFE4604E),
    Color(0xFF7C6FD6),
    Color(0xFF3FA372),
    Color(0xFFB07FD6),
    Color(0xFF9A8C7A),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/children/${widget.childId}/usage/top'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _apps = data['apps'] ?? [];
        _totalSeconds = data['total_seconds'] ?? 0;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _fmt(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rm = m % 60;
    return rm == 0 ? '${h}h' : '${h}h ${rm}m';
  }

  int _pct(int secs) =>
      _totalSeconds == 0 ? 0 : ((secs / _totalSeconds) * 100).round();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        foregroundColor: kInk,
        title: Text('${widget.childName}\'s screen time',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : RefreshIndicator(
              onRefresh: _load,
              child: _apps.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Icon(Icons.phone_android_rounded,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text('No usage recorded yet',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: kInk)),
                        ),
                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                              'Usage appears once the child device syncs.',
                              style: TextStyle(color: kInkSoft)),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Donut card
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: kCard,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5))
                            ],
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 220,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    PieChart(
                                      PieChartData(
                                        sectionsSpace: 3,
                                        centerSpaceRadius: 68,
                                        startDegreeOffset: -90,
                                        pieTouchData: PieTouchData(
                                          touchCallback: (event, resp) {
                                            setState(() {
                                              if (!event
                                                      .isInterestedForInteractions ||
                                                  resp == null ||
                                                  resp.touchedSection ==
                                                      null) {
                                                _touched = -1;
                                                return;
                                              }
                                              _touched = resp.touchedSection!
                                                  .touchedSectionIndex;
                                            });
                                          },
                                        ),
                                        sections: _buildSections(),
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_fmt(_totalSeconds),
                                            style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w800,
                                                color: kInk,
                                                height: 1.0)),
                                        const SizedBox(height: 2),
                                        const Text('today',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: kInkSoft)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Most used apps',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: kInk)),
                        const SizedBox(height: 14),
                        ...List.generate(_apps.length, (i) {
                          final a = _apps[i];
                          final secs = (a['seconds'] ?? 0) as int;
                          final color = _palette[i % _palette.length];
                          final name = (a['app'] ?? 'Unknown').toString();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Center(
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: kInk)),
                                      const SizedBox(height: 2),
                                      Text('${_pct(secs)}% of screen time',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: kInkSoft)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(_fmt(secs),
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: color)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
            ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    return List.generate(_apps.length, (i) {
      final a = _apps[i];
      final secs = (a['seconds'] ?? 0) as int;
      final color = _palette[i % _palette.length];
      final isTouched = i == _touched;
      final radius = isTouched ? 34.0 : 26.0;
      final value = math.max(secs.toDouble(), 0.0001);
      return PieChartSectionData(
        color: color,
        value: value,
        radius: radius,
        showTitle: isTouched,
        title: '${_pct(secs)}%',
        titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white),
        titlePositionPercentageOffset: 0.6,
      );
    });
  }
}

// ============================================================
// SETTINGS
// ============================================================
class SettingsScreen extends StatefulWidget {
  final String childId;
  final String childName;
  const SettingsScreen(
      {super.key, required this.childId, required this.childName});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> _settings = {};
  bool _loading = true;

    final _features = const [
    {
      'key': 'language_enabled',
      'title': 'Bad language detection',
      'desc': 'Flag offensive words, incl. Derja & Arabizi',
      'icon': Icons.record_voice_over_rounded
    },
    {
      'key': 'bullying_enabled',
      'title': 'Cyberbullying detection',
      'desc': 'Detect harassment and hurtful messages',
      'icon': Icons.sentiment_very_dissatisfied_rounded
    },
    {
      'key': 'duration_enabled',
      'title': 'Screen time tracking',
      'desc': 'Track most-used apps and total screen time',
      'icon': Icons.timer_rounded
    },
    {
      'key': 'sos_enabled',
      'title': 'Emergency SOS',
      'desc': 'Let your child send an urgent alert with location',
      'icon': Icons.emergency_rounded
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/children/${widget.childId}/settings'));
      if (res.statusCode == 200) {
        setState(() => _settings = jsonDecode(res.body));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _settings[key] = value);
    try {
      await http.patch(
        Uri.parse('$baseUrl/children/${widget.childId}/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({key: value}),
      );
    } catch (_) {
      setState(() => _settings[key] = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn\'t save. Check your connection.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        foregroundColor: kInk,
        title: Text('${widget.childName}\'s protection',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                    'Choose what SafeGuard watches for. Changes save automatically.',
                    style: TextStyle(color: kInkSoft, fontSize: 14)),
                const SizedBox(height: 20),
                ..._features.map((f) => _toggleCard(f)),
              ],
            ),
    );
  }

  Widget _toggleCard(Map f) {
    final key = f['key'] as String;
    final on = _settings[key] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: on
                      ? kGreen.withOpacity(0.12)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(f['icon'] as IconData,
                  color: on ? kGreen : kInkSoft, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f['title'] as String,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kInk)),
                  const SizedBox(height: 3),
                  Text(f['desc'] as String,
                      style: const TextStyle(
                          fontSize: 12.5, color: kInkSoft, height: 1.25)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: on,
              activeColor: Colors.white,
              activeTrackColor: kGreen,
              onChanged: (v) => _toggle(key, v),
            ),
          ],
        ),
      ),
    );
  }
}