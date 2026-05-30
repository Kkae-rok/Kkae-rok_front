import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:camera/camera.dart'; // 🍎 카메라 임포트 추가
import 'login_page.dart'; // 🍎 로그인 페이지 임포트 추가

class NotificationSettingsPage extends StatefulWidget {
  final List<CameraDescription> cameras; // 🍎 로그아웃 후 로그인 페이지로 돌아가기 위해 추가

  const NotificationSettingsPage({super.key, required this.cameras});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // 소리/진동분리
  bool _isSoundEnabled = true;
  bool _isVibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSoundEnabled = prefs.getBool('isSoundEnabled') ?? true;
      _isVibrationEnabled = prefs.getBool('isVibrationEnabled') ?? true;
    });
  }

  Future<void> _saveSettings(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // 🍎 하얀색 배경의 예쁜 로그아웃 로직 추가
  Future<void> _handleLogout(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, 
        surfaceTintColor: Colors.white, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "로그아웃", 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)
        ),
        content: const Text(
          "정말 로그아웃 하시겠습니까?", 
          style: TextStyle(color: Colors.black87)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "로그아웃", 
              style: TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();

        if (context.mounted) {
          // 🍎 로그아웃 시 이전 화면들의 기록을 싹 지우고 로그인 창으로 이동!
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => LoginPage(cameras: widget.cameras)),
            (route) => false, 
          );
        }
      } catch (e) {
        debugPrint("로그아웃 실패: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "시스템 설정", 
          style: TextStyle(
            color: Colors.black, 
            fontWeight: FontWeight.bold, 
            fontSize: 18
          )
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 소리 알림 설정
            _buildSettingRow("소리 알림", _isSoundEnabled, (value) {
              setState(() => _isSoundEnabled = value);
              _saveSettings('isSoundEnabled', value);
            }),
            const Divider(color: Color(0xFFEEEEEE)), 
            // 진동 알림 설정
            _buildSettingRow("진동 알림", _isVibrationEnabled, (value) {
              setState(() => _isVibrationEnabled = value);
              _saveSettings('isVibrationEnabled', value);
            }),
            
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFEEEEEE)), 
            const SizedBox(height: 10),

            // 🍎 로그아웃 버튼 UI 
            InkWell(
              onTap: () => _handleLogout(context),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
                child: Row(
                  children: const [
                    Icon(Icons.logout, color: Color(0xFFFF6B6B)),
                    SizedBox(width: 15),
                    Text(
                      "로그아웃", 
                      style: TextStyle(
                        fontSize: 17, 
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF6B6B), // 알림/경고 느낌을 주는 붉은색
                      )
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title, 
            style: const TextStyle(
              fontSize: 17, 
              fontWeight: FontWeight.w600,
              color: Colors.black,
            )
          ),
          Switch(
            value: value,
            activeTrackColor: const Color(0xFFFF6B6B),
            activeColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}