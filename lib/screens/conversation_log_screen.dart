import 'dart:async';
import 'package:flutter/material.dart';

class ConversationLogScreen extends StatefulWidget {
  final List<Map<String, String>> conversation;
  final VoidCallback? onShowDialer;
  const ConversationLogScreen({Key? key, required this.conversation, this.onShowDialer}) : super(key: key);

  @override
  State<ConversationLogScreen> createState() => _ConversationLogScreenState();
}

class _ConversationLogScreenState extends State<ConversationLogScreen> {
  late Timer _timer;
  int _secondsLeft = 300; // 5 minutes
  List<Map<String, String>> _log = [];

  @override
  void initState() {
    super.initState();
    _log = List<Map<String, String>>.from(widget.conversation);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsLeft--;
      });
      if (_secondsLeft <= 0) {
        _log.clear();
        _timer.cancel();
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation Log'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This log will be deleted in ${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            if (widget.onShowDialer != null)
              ElevatedButton(
                onPressed: widget.onShowDialer,
                child: const Text('Show Dialer'),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (context, index) {
                  final entry = _log[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry['speaker']}: ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(child: Text(entry['text'] ?? '')),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 