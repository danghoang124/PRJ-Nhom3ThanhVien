import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/level_list_screen.dart';
import 'screens/room_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LUCY Real-time Audio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        colorScheme: const ColorScheme.dark().copyWith(
          primary: const Color(0xFF0D9488),
          secondary: const Color(0xFF3B82F6),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService(
    authServerUrl: 'http://localhost:5197',
  );

  @override
  Widget build(BuildContext context) {
    if (_authService.isLoggedIn) {
      return HomeScreen(authService: _authService);
    }
    return LoginScreen(
      authService: _authService,
      onLoginSuccess: () => setState(() {}),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final AuthService authService;

  const HomeScreen({super.key, required this.authService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _serverUrlController =
      TextEditingController(text: 'http://localhost:3000');
  
  final TextEditingController _agoraAppIdController =
      TextEditingController(text: 'YOUR_AGORA_APP_ID');

  List<dynamic> _rooms = [];
  bool _isLoading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    final serverUrl = _serverUrlController.text.trim();
    try {
      final response = await http.get(Uri.parse('$serverUrl/api/rooms'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _rooms = data['rooms'] as List? ?? [];
        });
      } else {
        setState(() {
          _message = 'Lỗi server: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Không kết nối được server Node.js. Hãy bật server cổng 3000.';
      });
      dev.log('Error fetching rooms: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Bản đồ levelId theo ngôn ngữ: en=1-57, zh=58-154, ja=155-198
  static const Map<String, Map<String, dynamic>> _langConfig = {
    'en': {'name': '🇬🇧 Tiếng Anh (English)', 'code': 'en', 'levelStart': 1, 'levelEnd': 30},
    'zh': {'name': '🇨🇳 Tiếng Trung (Chinese)', 'code': 'zh', 'levelStart': 58, 'levelEnd': 87},
    'ja': {'name': '🇯🇵 Tiếng Nhật (Japanese)', 'code': 'ja', 'levelStart': 155, 'levelEnd': 184},
  };

  Future<void> _createNewRoom() async {
    final serverUrl = _serverUrlController.text.trim();
    final javaUrl = 'http://localhost:8085';

    // Map<String, dynamic>? = {levelId, languageCode, levelNumber}
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        String selectedLang = 'en';
        int selectedLevelNum = 1;
        List<Map<String, dynamic>> levels = [];
        bool loadingLevels = false;
        String? levelError;

        return StatefulBuilder(builder: (ctx, setDlgState) {
          Future<void> loadLevels(String lang) async {
            setDlgState(() { loadingLevels = true; levelError = null; levels = []; });
            try {
              final r = await http.get(
                Uri.parse('$javaUrl/api/languages/$lang/levels'),
              ).timeout(const Duration(seconds: 5));
              if (r.statusCode == 200) {
                final data = json.decode(r.body) as List;
                setDlgState(() {
                  levels = data.map((l) => {
                    'id': l['id'] as int,
                    'levelNumber': l['levelNumber'] as int,
                    'title': l['title'] as String? ?? 'Level ${l['levelNumber']}',
                  }).toList();
                  if (levels.isNotEmpty) selectedLevelNum = levels[0]['id'] as int;
                  loadingLevels = false;
                });
              } else {
                setDlgState(() { levelError = 'Không lấy được danh sách level (Java API)'; loadingLevels = false; });
              }
            } catch (e) {
              setDlgState(() { levelError = 'Java API chưa khởi động'; loadingLevels = false; });
            }
          }

          if (levels.isEmpty && !loadingLevels && levelError == null) {
            // Tải lần đầu
            Future.microtask(() => loadLevels(selectedLang));
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Text('🏫 Tạo Phòng Học', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ngôn ngữ:', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF252540),
                    value: selectedLang,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF14142B),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    items: _langConfig.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value['name'] as String),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null && val != selectedLang) {
                        selectedLang = val;
                        loadLevels(val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Level:', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 6),
                  if (loadingLevels)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(color: Color(0xFF0D9488), strokeWidth: 2),
                    ))
                  else if (levelError != null)
                    Text(levelError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))
                  else if (levels.isNotEmpty)
                    DropdownButtonFormField<int>(
                      dropdownColor: const Color(0xFF252540),
                      value: selectedLevelNum,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF14142B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      items: levels.map((l) => DropdownMenuItem<int>(
                        value: l['id'] as int,
                        child: Text('Lv.${l['levelNumber']} — ${l['title']}', overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) { if (val != null) setDlgState(() => selectedLevelNum = val); },
                    )
                  else
                    const Text('Không có level nào', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Huỷ', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: levels.isEmpty ? null : () => Navigator.of(ctx).pop({
                  'levelId': selectedLevelNum,
                  'languageCode': selectedLang,
                  'levelNumber': levels.firstWhere((l) => l['id'] == selectedLevelNum, orElse: () => {'levelNumber': 1})['levelNumber'],
                }),
                child: const Text('Tạo Phòng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
      },
    );

    if (result == null) return;

    setState(() { _isLoading = true; });
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/rooms'),
        headers: {'Content-Type': 'application/json', ...widget.authService.authHeaders},
        body: json.encode({
          'levelId': result['levelId'],
          'languageCode': result['languageCode'],
          'levelNumber': result['levelNumber'],
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final newRoom = json.decode(response.body);
        _showSnackbar('✅ Tạo thành công: ${newRoom['room']?['channelName'] ?? ''}');
        _fetchRooms();
      } else {
        final err = json.decode(response.body);
        _showSnackbar('Tạo phòng thất bại: ${err['error'] ?? err['message'] ?? response.statusCode}', isError: true);
      }
    } catch (e) {
      _showSnackbar('Lỗi kết nối khi tạo phòng.', isError: true);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _deleteRoom(String roomId) async {
    final serverUrl = _serverUrlController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('⚠️ Xác nhận xóa phòng', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn có chắc muốn xóa phòng này không? Hành động này không thể hoàn tác.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF991B1B)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final response = await http.delete(
        Uri.parse('$serverUrl/api/rooms/$roomId'),
        headers: widget.authService.authHeaders,
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        _showSnackbar('Đã xóa phòng thành công.');
        _fetchRooms();
      } else {
        final err = json.decode(response.body);
        _showSnackbar(err['error'] ?? 'Xóa thất bại', isError: true);
      }
    } catch (e) {
      _showSnackbar('Lỗi kết nối khi xóa phòng.', isError: true);
    }
  }

  void _showSnackbar(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? const Color(0xFF991B1B) : const Color(0xFF0D9488),
      ),
    );
  }

  void _navigateToLevels() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LevelListScreen(
          authService: widget.authService,
          javaApiUrl: 'http://localhost:8085',
        ),
      ),
    ).then((_) => _fetchRooms());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.forum_outlined, color: Color(0xFF0D9488), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'LUCY Live Rooms',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 0.5),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF0F0F1A),
        actions: [
          IconButton(
            icon: const Icon(Icons.list, color: Colors.white70),
            tooltip: 'Danh sách Level',
            onPressed: _navigateToLevels,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Tải lại danh sách',
            onPressed: _fetchRooms,
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Colors.redAccent),
            tooltip: 'Đăng xuất',
            onPressed: () {
              widget.authService.logout();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0F1A), Color(0xFF14142B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Column(
            children: [
              // Cấu hình URL (Dạng thu gọn mượt mà)
              _buildConfigCard(),
              const SizedBox(height: 16),
              
              // Tiêu đề danh sách và Nút tạo phòng
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Phòng Live Hiện Có',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D9488).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18, color: Colors.white),
                      label: const Text(
                        'Tạo Phòng',
                        style: TextStyle(
                          color: Colors.white, // Cố định màu chữ trắng nổi bật
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _createNewRoom,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Body
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0D9488),
                        ),
                      )
                    : _message != null
                        ? _buildNoServerState()
                        : _rooms.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                itemCount: _rooms.length,
                                itemBuilder: (context, idx) {
                                  final room = _rooms[idx];
                                  return _buildRoomCard(room);
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigCard() {
    return Card(
      color: const Color(0xFF14142B).withOpacity(0.7),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.settings_outlined, size: 16, color: Colors.tealAccent),
            const SizedBox(width: 8),
            Text(
              'Cấu hình kết nối (${widget.authService.email})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.tealAccent),
            ),
          ],
        ),
        iconColor: Colors.tealAccent,
        collapsedIconColor: Colors.white54,
        childrenPadding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: _serverUrlController,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Node.js Service Server URL',
              labelStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.link, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF0F0F1E),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0D9488)),
              ),
              helperText: 'iOS/Web: http://localhost:3000 | Android: http://10.0.2.2:3000',
              helperStyle: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _agoraAppIdController,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Agora App ID',
              labelStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF0F0F1E),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0D9488)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoServerState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2F).withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _fetchRooms,
              child: const Text(
                'Thử Kết Nối Lại',
                style: TextStyle(
                  color: Colors.white, // Cố định màu chữ trắng
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF14142B).withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_outlined, size: 48, color: Colors.white30),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có phòng học nào đang mở.',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hãy nhấn nút "Tạo Phòng" ở góc trên\nhoặc chọn Level ở thực đơn hành động để bắt đầu.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final roomId = room['id'] as String;
    final channelName = room['channelName'] as String? ?? 'Chủ đề ẩn danh';
    final langCode = (room['languageCode'] as String? ?? 'en').toLowerCase();
    final level = room['levelNumber'] as int? ?? 1;
    final usersCount = room['userCount'] as int? ?? 0;
    final currentSub = room['currentSubLevel'] ?? 1;
    final totalSubs = room['totalSubLevels'] ?? 1;
    final creatorEmail = room['creatorEmail'] as String? ?? '';

    // Tạo theme gradient badge & flag dựa trên ngôn ngữ
    LinearGradient badgeGradient;
    String flag;
    String langName;
    if (langCode == 'zh') {
      badgeGradient = const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFDC2626)]);
      flag = '🇨🇳';
      langName = 'ZH';
    } else if (langCode == 'ja') {
      badgeGradient = const LinearGradient(colors: [Color(0xFFDB2777), Color(0xFFBE185D)]);
      flag = '🇯🇵';
      langName = 'JA';
    } else {
      badgeGradient = const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF0D9488)]);
      flag = '🇬🇧';
      langName = 'EN';
    }

    final double progress = totalSubs > 0 ? currentSub / totalSubs : 0.0;
    final userEmail = widget.authService.email ?? '';
    final userRole = widget.authService.role ?? 'user';
    final bool canDelete = userRole == 'admin' || creatorEmail == userEmail;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: const Color(0xFF14142B).withOpacity(0.85),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: badge + name + stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: badgeGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$flag $langName • Lvl $level',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (canDelete)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF991B1B).withOpacity(0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF991B1B).withOpacity(0.5)),
                              ),
                              child: Text(
                                userRole == 'admin' ? 'Admin' : 'Của bạn',
                                style: const TextStyle(fontSize: 9, color: Colors.redAccent, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        channelName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.people_alt_outlined, size: 13, color: Colors.tealAccent),
                          const SizedBox(width: 5),
                          Text('$usersCount người', style: const TextStyle(fontSize: 12, color: Colors.tealAccent)),
                          const SizedBox(width: 14),
                          const Icon(Icons.run_circle_outlined, size: 13, color: Colors.white38),
                          const SizedBox(width: 5),
                          Text('Chặng $currentSub/$totalSubs', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Right: actions
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Nút Tham gia
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => RoomScreen(
                                roomId: roomId,
                                serverUrl: _serverUrlController.text.trim(),
                                agoraAppId: _agoraAppIdController.text.trim(),
                                authToken: widget.authService.token,
                              ),
                            ),
                          ).then((_) => _fetchRooms());
                        },
                        child: const Text('Tham gia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    // Nút Xóa (chỉ hiện với creator hoặc admin)
                    if (canDelete) ...
                      [
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                            label: const Text('Xóa', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              side: const BorderSide(color: Color(0xFF991B1B)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _deleteRoom(roomId),
                          ),
                        ),
                      ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.03),
              valueColor: AlwaysStoppedAnimation<Color>(
                langCode == 'zh'
                    ? const Color(0xFFEA580C)
                    : langCode == 'ja'
                        ? const Color(0xFFDB2777)
                        : const Color(0xFF0D9488),
              ),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
