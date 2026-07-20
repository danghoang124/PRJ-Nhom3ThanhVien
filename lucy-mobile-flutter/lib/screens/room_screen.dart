import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../services/agora_service.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  final String serverUrl;
  final String agoraAppId;
  final String? authToken;

  const RoomScreen({
    Key? key,
    required this.roomId,
    this.serverUrl = 'http://localhost:3000',
    this.agoraAppId = 'YOUR_AGORA_APP_ID',
    this.authToken,
  }) : super(key: key);

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late SocketService _socketService;
  final AgoraService _agoraService = AgoraService();

  // Trạng thái phòng hiện tại nhận từ Server
  Map<String, dynamic>? _roomData;
  Map<String, dynamic>? _currentUser;
  List<dynamic> _usersList = [];
  bool _isConnected = false;
  String? _errorMessage;

  // Trạng thái bản thân
  bool _isMicOn = false;
  bool _isHandRaised = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  void _initServices() {
    // 1. Khởi tạo Socket.io Service
    _socketService = SocketService(serverUrl: widget.serverUrl, authToken: widget.authToken);

    // Đăng ký các callback xử lý sự kiện
    _socketService.onConnected = () {
      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _errorMessage = null;
      });
      // Join vào phòng sau khi socket đã kết nối
      _socketService.joinRoom(widget.roomId, 0);
    };

    _socketService.onDisconnected = () {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
      });
    };

    _socketService.onRoomJoined = (data) async {
      dev.log('room:joined callback triggered');
      if (!mounted) return;
      final room = data['room'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      final agoraTokenData = data['agoraToken'] as Map<String, dynamic>;

      setState(() {
        _roomData = room;
        _currentUser = user;
        _isMicOn = user['isMicOn'] ?? false;
        _isHandRaised = user['isHandRaised'] ?? false;
        _usersList = _parseUsersList(room);
      });

      // 2. Kết nối âm thanh Agora RTC
      final agoraToken = agoraTokenData['token'] as String;
      final channelName = agoraTokenData['channelName'] as String;
      final uid = agoraTokenData['uid'] as int;
      final isDevMode = agoraTokenData['isDev'] as bool? ?? false;

      if (isDevMode) {
        dev.log('ℹ️ Server is in Dev Mode. Bypassing actual Agora SDK connection.');
      } else {
        try {
          // Khởi tạo và tham gia kênh Agora thật
          await _agoraService.initAgora(widget.agoraAppId);
          await _agoraService.joinAudioChannel(
            token: agoraToken,
            channelName: channelName,
            uid: uid,
          );
          // Set trạng thái mic ban đầu của thiết bị
          await _agoraService.muteLocalAudio(!_isMicOn);
        } catch (e) {
          dev.log('🚨 Error connecting to Agora RTC: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Lỗi mic (Vẫn có thể xem bài học): ${e.toString()}'),
              backgroundColor: const Color(0xFFC2410C),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    };

    _socketService.onRoomUpdated = (data) {
      if (!mounted) return;
      final room = data['room'] as Map<String, dynamic>;
      setState(() {
        _roomData = room;
        _usersList = _parseUsersList(room);
      });
    };

    _socketService.onUserJoined = (data) {
      if (!mounted) return;
      final persona = data['persona'] as String;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('👤 $persona đã tham gia phòng học'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF1F2937),
        ),
      );
    };

    _socketService.onUserLeft = (persona) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🚪 $persona đã rời phòng'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF991B1B),
        ),
      );
    };

    _socketService.onMicChanged = (persona, isMicOn) {
      if (!mounted) return;
      // Cập nhật trạng thái hiển thị trong danh sách UI
      setState(() {
        for (var u in _usersList) {
          if (u['persona'] == persona) {
            u['isMicOn'] = isMicOn;
          }
        }
        if (_currentUser != null && _currentUser!['persona'] == persona) {
          _currentUser!['isMicOn'] = isMicOn;
          _isMicOn = isMicOn;
        }
      });
    };

    _socketService.onHandChanged = (persona, isHandRaised) {
      if (!mounted) return;
      setState(() {
        for (var u in _usersList) {
          if (u['persona'] == persona) {
            u['isHandRaised'] = isHandRaised;
          }
        }
        if (_currentUser != null && _currentUser!['persona'] == persona) {
          _currentUser!['isHandRaised'] = isHandRaised;
          _isHandRaised = isHandRaised;
        }
      });
    };

    _socketService.onSubLevelChanged = (data) {
      if (!mounted) return;
      final room = data['room'] as Map<String, dynamic>;
      setState(() {
        _roomData = room;
        _usersList = _parseUsersList(room);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏭️ Đã chuyển sang chặng học ${room["currentSubLevel"]}!'),
          backgroundColor: const Color(0xFF0D9488),
        ),
      );
    };

    _socketService.onRoomEnded = (message) {
      if (!mounted) return;
      _cleanup();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('🎉 Kết thúc', style: TextStyle(color: Colors.white)),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Đóng dialog
                Navigator.of(context).pop(); // Rời khỏi màn hình phòng học
              },
              child: const Text('Xác nhận', style: TextStyle(color: Color(0xFF0D9488))),
            ),
          ],
        ),
      );
    };

    _socketService.onErrorReceived = (msg) {
      if (!mounted) return;
      setState(() {
        _errorMessage = msg;
      });
    };

    // Kết nối đến Socket server
    _socketService.connect();
  }

  List<dynamic> _parseUsersList(Map<String, dynamic> room) {
    if (room['users'] == null) return [];
    // Convert Map users từ JSON thành List
    if (room['users'] is Map) {
      return (room['users'] as Map).values.toList();
    } else if (room['users'] is List) {
      return room['users'];
    }
    return [];
  }

  /// Toggle Mic
  void _handleMicToggle() async {
    final nextState = !_isMicOn;
    _socketService.toggleMic(nextState);
    await _agoraService.muteLocalAudio(!nextState);
    setState(() {
      _isMicOn = nextState;
    });
  }

  /// Toggle Giơ tay
  void _handleHandToggle() {
    if (_isHandRaised) {
      _socketService.lowerHand();
    } else {
      _socketService.raiseHand();
    }
    setState(() {
      _isHandRaised = !_isHandRaised;
    });
  }

  /// Rời phòng
  void _handleLeaveRoom() {
    _cleanup();
    Navigator.of(context).pop();
  }

  void _cleanup() {
    // Null out all callbacks FIRST to prevent setState after dispose
    _socketService.onConnected = null;
    _socketService.onDisconnected = null;
    _socketService.onRoomJoined = null;
    _socketService.onRoomUpdated = null;
    _socketService.onUserJoined = null;
    _socketService.onUserLeft = null;
    _socketService.onMicChanged = null;
    _socketService.onHandChanged = null;
    _socketService.onSubLevelChanged = null;
    _socketService.onRoomEnded = null;
    _socketService.onErrorReceived = null;
    _socketService.leaveRoom();
    _socketService.disconnect();
    _agoraService.leaveChannel();
    _agoraService.release();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.dark();
    final isMentor = _currentUser != null && _currentUser!['role'] == 'mentor';
    
    // Lấy thông tin nội dung chặng học hiện tại
    final currentSubLevelIndex = _roomData != null ? _roomData!['currentSubLevel'] - 1 : 0;
    Map<String, dynamic>? currentSubLevelData;
    if (_roomData != null && _roomData!['subLevels'] != null && _roomData!['subLevels'] is List) {
      final subLevels = _roomData!['subLevels'] as List;
      if (currentSubLevelIndex >= 0 && currentSubLevelIndex < subLevels.length) {
        currentSubLevelData = subLevels[currentSubLevelIndex] as Map<String, dynamic>;
      }
    }

    final currentSub = _roomData != null ? _roomData!['currentSubLevel'] as int : 1;
    final totalSubs = _roomData != null ? _roomData!['totalSubLevels'] as int : 6;

    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F1A),
          elevation: 0,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _roomData != null ? 'Phòng ${_roomData!['channelName']}' : 'Đang kết nối...',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (_roomData != null)
                Text(
                  'Ngôn ngữ: ${(_roomData!['languageCode'] ?? 'en').toString().toUpperCase()} • Level ${_roomData!['levelNumber']}',
                  style: const TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white70),
            onPressed: _handleLeaveRoom,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 18.0),
              child: Center(
                child: Row(
                  children: [
                    Text(
                      _isConnected ? 'Đã kết nối' : 'Đang kết nối',
                      style: TextStyle(fontSize: 11, color: _isConnected ? Colors.greenAccent : Colors.redAccent),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (_isConnected)
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: _errorMessage != null
            ? _buildErrorState()
            : _roomData == null
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
                : Stack(
                    children: [
                      Column(
                        children: [
                          // ── Phần 1: Giao diện Giáo trình Real-time (Sub-level Content) ──
                          _buildCurriculumSection(currentSubLevelData, isMentor, currentSub, totalSubs),
                          
                          // ── Phần 2: Danh sách học viên ẩn danh ──
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 100.0), // Chừa không gian cho floating controls bar ở dưới
                              child: _buildUsersGrid(),
                            ),
                          ),
                        ],
                      ),

                      // ── Phần 3: Bảng điều khiển bottom nổi (Floating Bar) ──
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 24,
                        child: _buildControlsBar(),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2F).withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF991B1B),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Quay lại',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurriculumSection(Map<String, dynamic>? subLevel, bool isMentor, int currentSub, int totalSubs) {
    if (subLevel == null) return const SizedBox.shrink();

    final topic = subLevel['topic'] as String? ?? 'Chủ đề thảo luận';
    final questions = subLevel['questions'] as List? ?? [];
    double progress = totalSubs > 0 ? currentSub / totalSubs : 0.0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14142B).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📚 Chặng $currentSub/$totalSubs: $topic',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gợi ý học tập tự động bởi LMS',
                        style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4)),
                      ),
                    ],
                  ),
                ),
                if (isMentor)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.tealAccent, size: 22),
                      tooltip: 'Chuyển chặng tiếp theo',
                      onPressed: () => _socketService.nextSubLevel(widget.roomId),
                    ),
                  ),
              ],
            ),
          ),
          
          // Progress bar hiển thị chặng học hiện tại
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.04),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (questions.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E38).withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_alt_outlined, size: 14, color: Colors.tealAccent),
                      const SizedBox(width: 6),
                      const Text(
                        'GỢI Ý THẢO LUẬN:',
                        style: TextStyle(fontSize: 10, color: Colors.tealAccent, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 90),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: questions.length,
                      itemBuilder: (context, idx) {
                        final q = questions[idx];
                        final questionText = q['questionText'] as String? ?? '';
                        final sampleAnswer = q['sampleAnswer'] as String? ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '❓ $questionText',
                                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                              if (sampleAnswer.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '💡 Gợi ý trả lời: $sampleAnswer',
                                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5), fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsersGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _usersList.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 cột
        crossAxisSpacing: 20,
        mainAxisSpacing: 24,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, idx) {
        final user = _usersList[idx];
        final persona = user['persona'] as String? ?? 'Ẩn danh';
        final isMic = user['isMicOn'] as bool? ?? false;
        final isHand = user['isHandRaised'] as bool? ?? false;
        final role = user['role'] as String? ?? 'user';
        final isSelf = _currentUser != null && _currentUser!['persona'] == persona;

        // Tạo màu Avatar Gradient dựa trên mã băm của tên persona
        final hash = persona.hashCode;
        final colorIndex1 = hash % 5;
        final colorIndex2 = (hash >> 2) % 5;
        
        final gradients = [
          [const Color(0xFFEC4899), const Color(0xFF8B5CF6)], // Hồng -> Tím
          [const Color(0xFF3B82F6), const Color(0xFF06B6D4)], // Xanh dương -> Cyan
          [const Color(0xFF10B981), const Color(0xFF3B82F6)], // Lục -> Lam
          [const Color(0xFFF59E0B), const Color(0xFFEF4444)], // Vàng -> Đỏ
          [const Color(0xFF8B5CF6), const Color(0xFF6366F1)], // Tím -> Indigo
        ];

        final avatarGradient = LinearGradient(
          colors: role == 'mentor'
              ? [const Color(0xFF0D9488), const Color(0xFF0F766E)] // Mentor cố định màu Teal sang trọng
              : gradients[colorIndex1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        final initial = persona.isNotEmpty ? persona[0].toUpperCase() : '👤';

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Hiệu ứng sóng âm thanh bao quanh khi đang nói (bật mic)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isMic ? const Color(0xFF2DD4BF) : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      if (isMic)
                        BoxShadow(
                          color: const Color(0xFF2DD4BF).withOpacity(0.35),
                          blurRadius: 12,
                          spreadRadius: 3,
                        ),
                    ],
                  ),
                ),
                
                // Avatar tròn Gradient
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: avatarGradient,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
                
                // Trạng thái Giơ tay (Góc trên bên phải)
                if (isHand)
                  Positioned(
                    top: 0,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B), // Màu hổ phách
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0F0F1A), width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.back_hand,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                // Trạng thái Mic (Góc dưới bên phải)
                Positioned(
                  bottom: 0,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4.5),
                    decoration: BoxDecoration(
                      color: isMic ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F0F1A), width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      isMic ? Icons.mic : Icons.mic_off,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Tên Persona ẩn danh
            Text(
              persona + (isSelf ? ' (Bạn)' : ''),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelf ? FontWeight.bold : FontWeight.w500,
                color: isSelf ? const Color(0xFF2DD4BF) : Colors.white.withOpacity(0.85),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF14142B).withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Nút Bật / Tắt Mic
          _buildControlButton(
            icon: _isMicOn ? Icons.mic_none_outlined : Icons.mic_off_outlined,
            label: _isMicOn ? 'Tắt Mic' : 'Bật Mic',
            backgroundColor: _isMicOn ? const Color(0xFF0D9488) : const Color(0xFF1E1E35),
            iconColor: Colors.white,
            onPressed: _handleMicToggle,
          ),
          
          // Nút Giơ tay / Hạ tay
          _buildControlButton(
            icon: Icons.back_hand_outlined,
            label: _isHandRaised ? 'Hạ Tay' : 'Giơ Tay',
            backgroundColor: _isHandRaised ? const Color(0xFFD97706) : const Color(0xFF1E1E35),
            iconColor: Colors.white,
            onPressed: _handleHandToggle,
          ),
          
          // Nút Rời phòng (Màu đỏ nổi bật)
          _buildControlButton(
            icon: Icons.call_end_outlined,
            label: 'Rời Phòng',
            backgroundColor: const Color(0xFFDC2626),
            iconColor: Colors.white,
            onPressed: _handleLeaveRoom,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(14),
            backgroundColor: backgroundColor,
            elevation: 4,
            shadowColor: Colors.black45,
          ),
          onPressed: onPressed,
          child: Icon(icon, color: iconColor, size: 26),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11, 
            color: Colors.white, // Cố định màu trắng nổi bật cho label để tránh mất chữ
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
