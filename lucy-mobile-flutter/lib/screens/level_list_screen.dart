import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'room_screen.dart';

class LevelListScreen extends StatefulWidget {
  final AuthService authService;
  final String javaApiUrl;

  const LevelListScreen({
    Key? key,
    required this.authService,
    required this.javaApiUrl,
  }) : super(key: key);

  @override
  State<LevelListScreen> createState() => _LevelListScreenState();
}

class _LevelListScreenState extends State<LevelListScreen> {
  List<dynamic> _languages = [];
  Map<String, List<dynamic>> _levelsByLang = {};
  bool _isLoading = true;
  String? _error;
  String _selectedLang = 'en';

  @override
  void initState() {
    super.initState();
    _fetchLanguages();
  }

  Future<void> _fetchLanguages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${widget.javaApiUrl}/api/languages'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _languages = data;
          _isLoading = false;
        });
        if (data.isNotEmpty) {
          _fetchLevels(data[0]['code']);
        }
      } else {
        setState(() {
          _error = 'Lỗi tải danh sách ngôn ngữ';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Không kết nối được Java Content Service';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLevels(String langCode) async {
    setState(() {
      _selectedLang = langCode;
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${widget.javaApiUrl}/api/languages/$langCode/levels'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _levelsByLang[langCode] = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Lỗi tải danh sách level';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Không kết nối được Java Content Service';
        _isLoading = false;
      });
    }
  }

  void _showCreateRoomDialog(int levelId, String langCode, int levelNumber) {
    final serverUrl = 'http://localhost:3000';
    final agoraAppId = 'YOUR_AGORA_APP_ID';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RoomScreen(
          roomId: '',
          serverUrl: serverUrl,
          agoraAppId: agoraAppId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn Level Học'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: Text(
                widget.authService.email ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              widget.authService.logout();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchLanguages,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Language tabs
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _languages.length,
                        itemBuilder: (context, idx) {
                          final lang = _languages[idx];
                          final code = lang['code'] as String;
                          final name = lang['name'] as String;
                          final isSelected = code == _selectedLang;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(name),
                              selected: isSelected,
                              selectedColor: const Color(0xFF0D9488),
                              onSelected: (_) => _fetchLevels(code),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Levels list
                    Expanded(
                      child: _levelsByLang[_selectedLang] == null
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _levelsByLang[_selectedLang]!.length,
                              itemBuilder: (context, idx) {
                                final level = _levelsByLang[_selectedLang]![idx];
                                final levelId = level['id'] as int;
                                final title = level['title'] as String? ?? 'Level ${level['levelNumber']}';
                                final levelNum = level['levelNumber'] as int? ?? (idx + 1);
                                final duration = level['durationMin'] as int? ?? 60;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: const Color(0xFF1E1E32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D9488),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$levelNum',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Thời lượng: $duration phút',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3B82F6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => _showCreateRoomDialog(
                                        levelId,
                                        _selectedLang,
                                        levelNum,
                                      ),
                                      child: const Text('Tạo phòng'),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
