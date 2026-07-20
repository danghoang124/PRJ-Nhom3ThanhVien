import 'dart:developer' as dev;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraService {
  RtcEngine? _engine;
  bool _isInitialized = false;

  /// Xin quyền truy cập Microphone của điện thoại
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      dev.log('🎙️ Microphone permission granted.');
      return true;
    } else {
      dev.log('⚠️ Microphone permission denied.');
      return false;
    }
  }

  /// Khởi tạo RtcEngine của Agora
  Future<void> initAgora(String appId) async {
    if (_isInitialized) return;

    dev.log('Initializing Agora RTC Engine with AppId: $appId');
    
    // Tạo instance
    _engine = createAgoraRtcEngine();
    
    // Khởi tạo context với cấu hình Live Broadcasting (Đàm thoại/Live)
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    // Lắng nghe các sự kiện âm thanh hệ thống Agora
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        dev.log('🔊 Agora: Đã vào kênh thành công! Channel: ${connection.channelId}, Uid: ${connection.localUid}');
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        dev.log('👥 Agora: Có người dùng mới vào luồng âm thanh: $remoteUid');
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        dev.log('👥 Agora: Người dùng offline luồng âm thanh: $remoteUid, Reason: $reason');
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        dev.log('🚪 Agora: Đã rời khỏi kênh âm thanh.');
      },
      onError: (ErrorCodeType err, String msg) {
        dev.log('🚨 Agora Error: [$err] $msg');
      },
    ));

    // Bật tính năng Audio
    await _engine!.enableAudio();
    
    // Thiết lập vai trò là Broadcaster (mặc định để có thể nói được)
    // Người dùng thông thường vào phòng ẩn danh có thể tắt mic, nhưng khi được nói sẽ truyền luồng đi.
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    
    _isInitialized = true;
    dev.log('Agora RTC Engine initialized successfully.');
  }

  /// Tham gia kênh âm thanh
  /// - [token]: Token nhận được từ server (sinh qua `agoraToken.js`)
  /// - [channelName]: Tên kênh (ví dụ: `lucy_en_1_abc123`)
  /// - [uid]: UID do Agora cấp hoặc server chỉ định
  Future<void> joinAudioChannel({
    required String token,
    required String channelName,
    required int uid,
  }) async {
    if (_engine == null) {
      throw Exception('Agora Engine chưa được khởi tạo. Hãy gọi initAgora() trước.');
    }

    // Xin quyền trước khi join
    final hasPermission = await requestMicrophonePermission();
    if (!hasPermission) {
      throw Exception('Quyền truy cập Microphone bị từ chối.');
    }

    dev.log('Agora: Joining channel $channelName with uid $uid...');
    
    // Join với cấu hình auto-subscribe audio từ người khác và publish mic của mình
    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  /// Bật / Tắt luồng mic vật lý của thiết bị
  /// - [isMuted]: true = Tắt mic điện thoại, false = Bật mic phát âm thanh đi
  Future<void> muteLocalAudio(bool isMuted) async {
    if (_engine == null) return;
    
    dev.log('Agora: Set mute state of local microphone to $isMuted');
    await _engine!.muteLocalAudioStream(isMuted);
  }

  /// Rời kênh âm thanh
  Future<void> leaveChannel() async {
    if (_engine == null) return;

    dev.log('Agora: Leaving channel...');
    await _engine!.leaveChannel();
  }

  /// Giải phóng tài nguyên engine khi huỷ màn hình
  Future<void> release() async {
    if (_engine == null) return;
    
    dev.log('Agora: Releasing RtcEngine resources...');
    await _engine!.release();
    _engine = null;
    _isInitialized = false;
  }
}
