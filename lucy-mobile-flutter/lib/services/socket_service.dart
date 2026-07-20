import 'dart:developer' as dev;
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket socket;
  final String serverUrl;
  final String? authToken;

  // Callbacks để UI đăng ký lắng nghe sự kiện
  Function(Map<String, dynamic>)? onRoomJoined;
  Function(Map<String, dynamic>)? onRoomUpdated;
  Function(Map<String, dynamic>)? onUserJoined;
  Function(String)? onUserLeft;
  Function(String, bool)? onMicChanged;
  Function(String, bool)? onHandChanged;
  Function(Map<String, dynamic>)? onSubLevelChanged;
  Function(String)? onRoomEnded;
  Function(String)? onErrorReceived;
  Function()? onConnected;
  Function()? onDisconnected;

  SocketService({required this.serverUrl, this.authToken});

  /// Khởi tạo kết nối Socket.io
  void connect() {
    dev.log('Connecting to realtime service: $serverUrl');
    
    socket = IO.io(serverUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .setAuth({'token': authToken})
      .build());

    // Các sự kiện kết nối hệ thống
    socket.onConnect((_) {
      dev.log('🔌 Socket.io connected to $serverUrl');
      if (onConnected != null) onConnected!();
    });

    socket.onDisconnect((_) {
      dev.log('❌ Socket.io disconnected');
      if (onDisconnected != null) onDisconnected!();
    });

    socket.onConnectError((err) {
      dev.log('⚠️ Socket.io Connection Error: $err');
      if (onErrorReceived != null) onErrorReceived!('Không thể kết nối đến máy chủ.');
    });

    // ── Lắng nghe các event nghiệp vụ phòng học (Server -> Client) ──

    // Khi bản thân vào phòng thành công
    socket.on('room:joined', (data) {
      dev.log('Joined room info received: $data');
      if (onRoomJoined != null) {
        onRoomJoined!(Map<String, dynamic>.from(data));
      }
    });

    // Khi phòng được cập nhật trạng thái chung
    socket.on('room:updated', (data) {
      if (onRoomUpdated != null) {
        onRoomUpdated!(Map<String, dynamic>.from(data));
      }
    });

    // Khi có thành viên khác tham gia phòng
    socket.on('user:joined', (data) {
      dev.log('Another user joined: $data');
      if (onUserJoined != null) {
        onUserJoined!(Map<String, dynamic>.from(data));
      }
    });

    // Khi có thành viên rời phòng
    socket.on('user:left', (data) {
      final persona = data['persona'] as String? ?? 'Unknown';
      dev.log('$persona left room');
      if (onUserLeft != null) {
        onUserLeft!(persona);
      }
    });

    // Khi ai đó bật/tắt mic
    socket.on('mic:changed', (data) {
      final persona = data['persona'] as String? ?? 'Unknown';
      final isMicOn = data['isMicOn'] as bool? ?? false;
      if (onMicChanged != null) {
        onMicChanged!(persona, isMicOn);
      }
    });

    // Khi ai đó giơ/hạ tay
    socket.on('hand:changed', (data) {
      final persona = data['persona'] as String? ?? 'Unknown';
      final isHandRaised = data['isHandRaised'] as bool? ?? false;
      if (onHandChanged != null) {
        onHandChanged!(persona, isHandRaised);
      }
    });

    // Khi chuyển chặng học (Sub-level)
    socket.on('sublevel:changed', (data) {
      dev.log('Sublevel transitioned: $data');
      if (onSubLevelChanged != null) {
        onSubLevelChanged!(Map<String, dynamic>.from(data));
      }
    });

    // Khi phòng học kết thúc
    socket.on('room:ended', (data) {
      final message = data['message'] as String? ?? 'Buổi học đã kết thúc.';
      if (onRoomEnded != null) {
        onRoomEnded!(message);
      }
    });

    // Khi có lỗi từ server
    socket.on('error', (data) {
      final message = data['message'] as String? ?? 'Đã xảy ra lỗi không xác định.';
      dev.log('Error from socket: $message');
      if (onErrorReceived != null) {
        onErrorReceived!(message);
      }
    });

    socket.connect();
  }

  /// ── Gửi event từ Client lên Server ──

  /// Tham gia phòng
  void joinRoom(String roomId, int agoraUid) {
    dev.log('Sending room:join for room: $roomId');
    socket.emit('room:join', {
      'roomId': roomId,
      'agoraUid': agoraUid,
    });
  }

  /// Rời phòng
  void leaveRoom() {
    dev.log('Sending room:leave');
    socket.emit('room:leave');
  }

  /// Bật / Tắt mic
  void toggleMic(bool isMicOn) {
    dev.log('Sending mic:toggle: $isMicOn');
    socket.emit('mic:toggle', {
      'isMicOn': isMicOn,
    });
  }

  /// Giơ tay phát biểu
  void raiseHand() {
    dev.log('Sending hand:raise');
    socket.emit('hand:raise');
  }

  /// Hạ tay xuống
  void lowerHand() {
    dev.log('Sending hand:lower');
    socket.emit('hand:lower');
  }

  /// Yêu cầu chuyển Sub-level (chỉ Mentor có quyền)
  void nextSubLevel(String roomId) {
    dev.log('Sending sublevel:next for room: $roomId');
    socket.emit('sublevel:next', {
      'roomId': roomId,
    });
  }

  /// Ngắt kết nối socket hoàn toàn
  void disconnect() {
    socket.disconnect();
  }
}
