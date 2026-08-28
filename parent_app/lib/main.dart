import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://10.0.2.2:8000';

// ---- Design tokens (calm, trustworthy safety app) ----
const Color kIndigo = Color(0xFF2D3561);   // primary - trust/security
const Color kSlate = Color(0xFF4A5178);
const Color kCoral = Color(0xFFE86A5C);     // alerts only
const Color kAmber = Color(0xFFE9A23B);     // medium severity
const Color kSurface = Color(0xFFF7F6F3);   // soft off-white
const Color kCardBg = Colors.white;
const Color kTextDark = Color(0xFF1C1E2E);
const Color kTextMuted = Color(0xFF6B7089);

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
        scaffoldBackgroundColor: kSurface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kIndigo,
          primary: kIndigo,
          surface: kSurface,
        ),
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
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/parents/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _email.text.trim(), 'password': _password.text}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => DashboardScreen(
            parentId: data['id'],
            parentName: data['full_name'] ?? 'Parent',
          ),
        ));
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
                Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    color: kIndigo,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                const Text('SafeGuard',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: kTextDark, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                const Text('Keeping your children safe online',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: kTextMuted)),
                const SizedBox(height: 40),
                _field(_email, 'Email', Icons.mail_outline, false),
                const SizedBox(height: 16),
                _field(_password, 'Password', Icons.lock_outline, true),
                const SizedBox(height: 8),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error, style: const TextStyle(color: kCoral, fontSize: 13)),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _loading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: kIndigo,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, bool obscure) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: const TextStyle(color: kTextDark),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: kTextMuted, size: 20),
        filled: true,
        fillColor: kCardBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kIndigo, width: 1.6),
        ),
      ),
    );
  }
}

// ============================================================
// DASHBOARD (list of children)
// ============================================================
class DashboardScreen extends StatefulWidget {
  final String parentId;
  final String parentName;
  const DashboardScreen({super.key, required this.parentId, required this.parentName});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _children = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/parents/${widget.parentId}/children'));
      if (res.statusCode == 200) {
        setState(() => _children = jsonDecode(res.body));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadChildren,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, ${widget.parentName}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: kTextDark, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      const Text('Here are the children you\'re protecting',
                        style: TextStyle(fontSize: 15, color: kTextMuted)),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kIndigo)))
              else if (_children.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.child_care_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('No children linked yet',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextDark)),
                          const SizedBox(height: 6),
                          const Text('Add a child from the setup to start monitoring.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: kTextMuted)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _childCard(_children[i]),
                      childCount: _children.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _childCard(dynamic child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => AlertsScreen(childId: child['id'], childName: child['name'] ?? 'Child'),
          )),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: kIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: Center(child: Text(
                    (child['name'] ?? '?').toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: kIndigo, fontSize: 22, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(child['name'] ?? 'Child',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextDark)),
                      const SizedBox(height: 3),
                      Text(child['age'] != null ? 'Age ${child['age']}' : 'Tap to view alerts',
                        style: const TextStyle(fontSize: 13, color: kTextMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: kTextMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ALERTS (events for a child)
// ============================================================
class AlertsScreen extends StatefulWidget {
  final String childId;
  final String childName;
  const AlertsScreen({super.key, required this.childId, required this.childName});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/children/${widget.childId}/events'));
      if (res.statusCode == 200) setState(() => _events = jsonDecode(res.body));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color _sevColor(String? s) {
    switch (s) {
      case 'high': return kCoral;
      case 'medium': return kAmber;
      default: return kSlate;
    }
  }

  IconData _typeIcon(String? t) {
    switch (t) {
      case 'language': return Icons.record_voice_over_outlined;
      case 'bullying': return Icons.sentiment_very_dissatisfied_outlined;
      case 'sos': return Icons.emergency_outlined;
      case 'duration': return Icons.timer_outlined;
      default: return Icons.warning_amber_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        foregroundColor: kTextDark,
        title: Text('${widget.childName}\'s alerts',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Monitoring settings',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => SettingsScreen(childId: widget.childId, childName: widget.childName),
            )),
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: kIndigo))
        : _events.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, size: 64, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  const Text('All clear', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kTextDark)),
                  const SizedBox(height: 6),
                  const Text('No alerts for this child yet.', style: TextStyle(color: kTextMuted)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _events.length,
                itemBuilder: (context, i) => _alertCard(_events[i]),
              ),
            ),
    );
  }

  Widget _alertCard(dynamic e) {
    final sev = e['severity'] as String?;
    final type = e['type'] as String?;
    final color = _sevColor(sev);
    final content = (e['content'] ?? '').toString();
    final when = (e['created_at'] ?? '').toString().replaceFirst('T', '  ').split('.').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(_typeIcon(type), color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text((type ?? 'alert').toUpperCase(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
                      const Spacer(),
                      if (sev != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text(sev, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(content,
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: kTextDark, height: 1.3)),
                  const SizedBox(height: 6),
                  Text(when, style: const TextStyle(fontSize: 12, color: kTextMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ============================================================
// SETTINGS (feature toggles per child)
// ============================================================
class SettingsScreen extends StatefulWidget {
  final String childId;
  final String childName;
  const SettingsScreen({super.key, required this.childId, required this.childName});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> _settings = {};
  bool _loading = true;

  final _features = const [
    {'key': 'language_enabled', 'title': 'Bad language detection', 'desc': 'Flag offensive words, incl. Derja & Arabizi', 'icon': Icons.record_voice_over_outlined},
    {'key': 'bullying_enabled', 'title': 'Cyberbullying detection', 'desc': 'Detect harassment and hurtful messages', 'icon': Icons.sentiment_very_dissatisfied_outlined},
    {'key': 'image_enabled', 'title': 'Image moderation', 'desc': 'Check pictures for explicit content', 'icon': Icons.image_outlined},
    {'key': 'website_enabled', 'title': 'Website filtering', 'desc': 'Block unsafe or adult websites', 'icon': Icons.public_outlined},
    {'key': 'duration_enabled', 'title': 'Screen time limits', 'desc': 'Alert when usage runs too long', 'icon': Icons.timer_outlined},
    {'key': 'stranger_enabled', 'title': 'Stranger contact alerts', 'desc': 'Warn about unknown people messaging', 'icon': Icons.person_off_outlined},
    {'key': 'mental_health_enabled', 'title': 'Wellbeing signals', 'desc': 'Notice distress and offer support', 'icon': Icons.favorite_outline},
    {'key': 'sos_enabled', 'title': 'Emergency SOS', 'desc': 'Let your child send an urgent alert', 'icon': Icons.emergency_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/children/${widget.childId}/settings'));
      if (res.statusCode == 200) setState(() => _settings = jsonDecode(res.body));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _settings[key] = value); // optimistic
    try {
      await http.patch(
        Uri.parse('$baseUrl/children/${widget.childId}/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({key: value}),
      );
    } catch (_) {
      setState(() => _settings[key] = !value); // revert on failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t save. Check your connection.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        foregroundColor: kTextDark,
        title: Text('${widget.childName}\'s protection',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19)),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: kIndigo))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Choose what SafeGuard watches for. Changes save automatically.',
                style: TextStyle(color: kTextMuted, fontSize: 14)),
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
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: on ? kIndigo.withOpacity(0.12) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(f['icon'] as IconData, color: on ? kIndigo : kTextMuted, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f['title'] as String,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextDark)),
                  const SizedBox(height: 3),
                  Text(f['desc'] as String,
                    style: const TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.25)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: on,
              activeColor: Colors.white,
              activeTrackColor: kIndigo,
              onChanged: (v) => _toggle(key, v),
            ),
          ],
        ),
      ),
    );
  }
}