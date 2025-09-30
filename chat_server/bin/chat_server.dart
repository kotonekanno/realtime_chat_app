import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  final chatRoom = ChatRoom();

  final handler = webSocketHandler((WebSocketChannel webSocket) {
    chatRoom.addClient(webSocket);
  });

  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('WebSocket started: ws://${server.address.host}:${server.port}');
}

class ChatRoom {
  final Map<String, ClientConnection> _clients = {};
  static const int maxClients = 4;

  void addClient(WebSocketChannel webSocket) {
    if (_clients.length >= maxClients) {
      webSocket.sink.add(jsonEncode({
        'type': 'error',
        'message': 'Chat room is full (max ${maxClients} clients)',
      }));
      webSocket.sink.close();
      return;
    }

    final clientId = DateTime.now().millisecondsSinceEpoch.toString();
    final client = ClientConnection(clientId, webSocket);
    _clients[clientId] = client;

    print('Client connection: $clientId (${_clients.length} now)');

    // Receive message
    webSocket.stream.listen(
      (message) {
        _handleMessage(clientId, message);
      },
      onDone: () {
        _removeClient(clientId);
      },
      onError: (error) {
        print('Error: $error');
        _removeClient(clientId);
      },
    );
  }

  void _handleMessage(String clientId, dynamic message) {
    try {
      final data = jsonDecode(message);
      
      if (data['type'] == 'register') {
        // Register user name
        final username = data['username'];
        _clients[clientId]?.username = username;
        print('Register user name: $clientId -> $username');
        
        // Send connection message
        _broadcastMessage({
          'type': 'user_joined',
          'userId': clientId,
          'username': username,
          'userCount': _clients.length,
          'timestamp': DateTime.now().toIso8601String(),
        });

        // Send current user list to new client
        final userList = _clients.entries.map((e) => {
          'userId': e.key,
          'username': e.value.username,
        }).toList();
        
        _clients[clientId]?.webSocket.sink.add(jsonEncode({
          'type': 'init',
          'userId': clientId,
          'users': userList,
          'userCount': _clients.length,
        }));
        
      } else if (data['type'] == 'typing') {
        // Broadcast typing message to others
        _broadcastMessage({
          'type': 'typing',
          'userId': clientId,
          'username': _clients[clientId]?.username,
          'text': data['text'],
          'timestamp': DateTime.now().toIso8601String(),
        }, excludeClientId: clientId);
      }
    } catch (e) {
      print('Message decoding error: $e');
    }
  }

  void _broadcastMessage(Map<String, dynamic> message, {String? excludeClientId}) {
    final messageJson = jsonEncode(message);
    
    for (final entry in _clients.entries) {
      if (entry.key != excludeClientId) {
        try {
          entry.value.webSocket.sink.add(messageJson);
        } catch (e) {
          print('Message sending error (${entry.key}): $e');
        }
      }
    }
  }

  void _removeClient(String clientId) {
    final client = _clients.remove(clientId);
    if (client != null) {
      print('Client disconnection: $clientId (${_clients.length} clients now)');
      
      // Send disconnection message
      _broadcastMessage({
        'type': 'user_left',
        'userId': clientId,
        'username': client.username,
        'userCount': _clients.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }
}

class ClientConnection {
  final String id;
  final WebSocketChannel webSocket;
  String? username;

  ClientConnection(this.id, this.webSocket);
}