class _CallingScreenState extends State<CallingScreen> {
  int _currentIndex = 0;
  bool _isCalling = false;
  String _log = '';
  List<Map<String, String>> _conversation = [];
  bool _callConnected = false;
  bool _conversationActive = false;
  String _currentStatus = "Initializing...";

  late FlutterTts _tts;
  late SpeechToText _stt;
  StreamSubscription<PhoneState>? _phoneStateSubscription;
  late AudioService _audioService;

  bool _walletLoaded = false;
  int _freeCallsLeft = 0;

  @override
  void initState() {
    super.initState();
    _audioService = AudioService.instance;
    _tts = _audioService.tts;
    _stt = _audioService.stt;

    platform.setMethodCallHandler(_handleMethod);
  }

  void _processNextCall() async {
    await _loadWallet();
    if (_currentIndex >= widget.contacts.length) {
      setState(() {
        _currentStatus = "All calls completed!";
      });
      return;
    }
    // Check if selected API key is available
    bool apiKeyAvailable = await _checkApiKeyAvailable();
    if (!apiKeyAvailable) {
      await _showMissingApiKeyDialog();
      return;
    }
    // Check if enough credits
    if (_freeCallsLeft <= 0 && _paidCallsLeft <= 0 && _walletBalance < _selectedPrice) {
      await _showAddMoneyDialog();
      // Re-check after adding money
      await _loadWallet();
      if (_freeCallsLeft <= 0 && _paidCallsLeft <= 0 && _walletBalance < _selectedPrice) {
        setState(() { _currentStatus = "Insufficient funds."; });
        return;
      }
    }

    final contact = widget.contacts[_currentIndex];
    final phoneNumber = contact['phone']!;
    final contactName = contact['name'] ?? 'Contact';
    _conversation = [];
    _callConnected = false;
    _conversationActive = false;

    setState(() {
      _currentStatus = "Calling $contactName ($phoneNumber)...";
      _log += 'Calling $contactName ($phoneNumber)...\n';
    });

    try {
      await _audioService.stopListening();
      final callStarted = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      if (callStarted == true) {
        setState(() { _isCalling = true; });
      } else {
        _log += 'Failed to start call.\n';
        _processNextCall();
      }
    } catch (e) {
      _log += 'Error making call: $e\n';
      _processNextCall();
    }
  }

  Future<void> _startConversation(String contactName) async {
    setState(() {
      _currentStatus = 'In conversation with $contactName';
      _conversationActive = true;
    });

    try {
      final openingLine = await FirebaseService.generateOpeningLine(widget.prompt);
      _conversation.add({'speaker': 'AI', 'text': openingLine});
      await _audioService.speak(openingLine);
      await _audioService.startListening();
    } catch (e) {
      print("Error in conversation: $e");
    }
  }

  Future<void> _endCall() async {
    if (!_isCalling) return;

    await _audioService.endCall();

    setState(() {
      _isCalling = false;
      _callConnected = false;
      _conversationActive = false;
      _currentStatus = "Call ended.";
      _currentIndex++;
    });

    await Future.delayed(const Duration(seconds: 2));
    _processNextCall();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Calling Screen')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_currentStatus, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (_isCalling)
              ElevatedButton(
                onPressed: _endCall,
                child: const Text('End Call & Move to Next'),
              ),
            if (_audioService.isListening)
              const Text("Listening...", style: TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
} 