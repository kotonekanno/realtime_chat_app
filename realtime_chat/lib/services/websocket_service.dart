import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/chat_message.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _userJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _userLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _initController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  
  String? _myUserId;
  bool _isConnected = false;

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get userJoinedStream => _userJoinedController.stream;
  Stream<Map<String, dynamic>> get userLeftStream => _userLeftController.stream;
  Stream<Map<String, dynamic>> get initStream => _initController.stream;
  Stream<String> get errorStream => _errorController.stream;
  
  String? get myUserId => _myUserId;
  bool get isConnected => _isConnected;

  Future<void> connect(String url) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () {
          _isConnected = false;
          print('WebSocket disconnected');
        },
        onError: (error) {
          _isConnected = false;
          _errorController.add('Connection error: $error');
          print('WebSocket error: $error');
        },
      );
    } catch (e) {
      _isConnected = false;
      _errorController.add('Connection failed: $e');
      print('Connection error: $e');
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      
      switch (data['type']) {
        case 'init':
          _myUserId = data['userId'];
          _initController.add(data);
          break;
          
        case 'typing':
          final chatMessage = ChatMessage.fromJson(data);
          _messageController.add(chatMessage);
          break;
          
        case 'user_joined':
          _userJoinedController.add(data);
          break;
          
        case 'user_left':
          _userLeftController.add(data);
          break;
          
        case 'error':
          _errorController.add(data['message']);
          break;
      }
    } catch (e) {
      print('Message process error: $e');
    }
  }

  void sendTyping(String text) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({
        'type': 'typing',
        'text': text,
      }));
    }
  }

  void dispose() {
    _channel?.sink.close();
    _messageController.close();
    _userJoinedController.close();
    _userLeftController.close();
    _initController.close();
    _errorController.close();
    _isConnected = false;
  }
}