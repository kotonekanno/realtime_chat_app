import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/websocket_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final WebSocketService _wsService = WebSocketService();
  final TextEditingController _textController = TextEditingController();
  final Map<String, String> _userTexts = {};
  final Map<String, UserInfo> _userInfo = {};
  final List<Color> _userColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];
  
  String? _myUserId;
  int _userCount = 0;
  bool _isConnecting = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _connectToServer();
  }

  Future<void> _connectToServer() async {
    // Connect to local server (Replace URL according to envioronment)
    const serverUrl = 'ws://localhost:8080';
    
    await _wsService.connect(serverUrl);

    _wsService.initStream.listen((data) {
      setState(() {
        _myUserId = data['userId'];
        _userCount = data['userCount'];
        _isConnecting = false;
        
        // Add own user info
        _userInfo[_myUserId!] = UserInfo(
          userId: _myUserId!,
          displayName: 'You',
          colorIndex: 0,
        );
      });
    });

    _wsService.messageStream.listen((message) {
      setState(() {
        _userTexts[message.userId] = message.text;
        
        // Add new user's info
        if (!_userInfo.containsKey(message.userId)) {
          final colorIndex = _userInfo.length % _userColors.length;
          _userInfo[message.userId] = UserInfo(
            userId: message.userId,
            displayName: 'User${_userInfo.length}',
            colorIndex: colorIndex,
          );
        }
      });
    });

    _wsService.userJoinedStream.listen((data) {
      setState(() {
        _userCount = data['userCount'];
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New user entered'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });

    _wsService.userLeftStream.listen((data) {
      setState(() {
        _userCount = data['userCount'];
        final userId = data['userId'];
        _userTexts.remove(userId);
        _userInfo.remove(userId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User exited'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });

    _wsService.errorStream.listen((error) {
      setState(() {
        _errorMessage = error;
        _isConnecting = false;
      });
    });

    _textController.addListener(() {
      _wsService.sendTyping(_textController.text);
    });
  }

  @override
  void dispose() {
    _wsService.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to server...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isConnecting = true;
                  });
                  _connectToServer();
                },
                child: const Text('Reconnect'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Real Time Chat'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Connecting: $_userCount',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Own texiting area
                _buildUserInputCard(
                  userInfo: _userInfo[_myUserId]!,
                  text: _textController.text,
                  isMe: true,
                ),
                const SizedBox(height: 16),
                
                // Other's texting area
                ..._userTexts.entries
                    .where((entry) => entry.key != _myUserId)
                    .map((entry) {
                  final userInfo = _userInfo[entry.key];
                  if (userInfo == null) return const SizedBox.shrink();
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildUserInputCard(
                      userInfo: userInfo,
                      text: entry.value,
                      isMe: false,
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Your text will be shown here...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInputCard({
    required UserInfo userInfo,
    required String text,
    required bool isMe,
  }) {
    final color = _userColors[userInfo.colorIndex % _userColors.length];
    
    return Card(
      elevation: isMe ? 4 : 2,
      color: isMe ? color.withOpacity(0.1) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  radius: 16,
                  child: Text(
                    userInfo.displayName[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  userInfo.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'YOU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: text.isEmpty
                  ? Text(
                      isMe ? 'Text here...' : 'Waiting texting...',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}