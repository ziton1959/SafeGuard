import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

// ⚠️ TEMPORARY: hardcoded child ID for demo.
// LATER: replace with a pairing screen that stores the ID after linking.
const String childId = 'bd6b71ef-8e6e-4dcc-9822-6a30ba587f24';

// The emulator reaches your PC via 10.0.2.2
const String baseUrl = 'http://10.0.2.2:8000';

void main() {
  runApp(const SafeGuardApp());
}

class SafeGuardApp extends StatelessWidget {
  const SafeGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeGuard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class Message {
  final String text;
  final bool isOffensive;
  final bool isBullying;
  final String? reason;

  Message({
    required this.text,
    this.isOffensive = false,
    this.isBullying = false,
    this.reason,
  });
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
  // Stage 1: the bridge to native Kotlin
  static const platform = MethodChannel('safeguard/ocr');
  String _nativeReply = '';

  Future<void> _testPing() async {
    try {
      final reply = await platform.invokeMethod('ping');
      setState(() => _nativeReply = reply);
    } catch (e) {
      setState(() => _nativeReply = 'Bridge error: $e');
    }
  }

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

      bool offensive = false;
      bool bullying = false;
      String? reason;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'] ?? {};
        offensive = result['is_offensive'] ?? false;
        bullying = result['is_bullying'] ?? false;
        reason = result['layer2_reason'];
      }

      setState(() {
        _messages.add(
          Message(
            text: text,
            isOffensive: offensive,
            isBullying: bullying,
            reason: reason,
          ),
        );
        _controller.clear();
      });
    } catch (e) {
      setState(() {
        _messages.add(Message(text: '$text  (connection failed)'));
        _controller.clear();
      });
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeGuard Chat'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: _testPing,
            tooltip: 'Test native bridge',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_nativeReply.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(8),
              child: Text('Native says: $_nativeReply'),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final flagged = m.isOffensive || m.isBullying;
                return Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: flagged
                          ? Colors.red.shade100
                          : Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: flagged
                          ? Border.all(color: Colors.red, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.text, style: const TextStyle(fontSize: 15)),
                        if (flagged) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.warning,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                m.isBullying
                                    ? 'Bullying detected'
                                    : 'Offensive detected',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (m.reason != null && m.reason!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                m.reason!,
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
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
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton.filled(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
