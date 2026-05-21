import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

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
          children: [
            // 소리 알림 설정
            _buildSettingRow("소리 알림", _isSoundEnabled, (value) {
              setState(() => _isSoundEnabled = value);
              _saveSettings('isSoundEnabled', value);
            }),
            const Divider(color: Color(0xFFEEEEEE)), // 구분선 색상도 살짝 연하게 조정
            // 진동 알림 설정
            _buildSettingRow("진동 알림", _isVibrationEnabled, (value) {
              setState(() => _isVibrationEnabled = value);
              _saveSettings('isVibrationEnabled', value);
            }),
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