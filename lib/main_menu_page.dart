import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'detector_page.dart'; 
import 'record_page.dart';   
import 'notification_settings_page.dart'; 
import 'statistics_page.dart';
import 'login_page.dart';

class MainMenuPage extends StatelessWidget {
  final List<CameraDescription> cameras; 
  const MainMenuPage({super.key, required this.cameras});

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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage(cameras: cameras)),
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
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        leadingWidth: 100, 
        leading: TextButton(
          onPressed: () => _handleLogout(context),
          child: const Text(
            "로그아웃",
            style: TextStyle(
              color: Colors.black, 
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand, 
        children: [
         
          Container(
            color: const Color(0xFFF8F9FA), 
            alignment: Alignment.center, 
            child: Image.asset(
              'assets/background.png', 
              fit: BoxFit.contain, 
              width: MediaQuery.of(context).size.width * 0.85, 
              
              
              color: const Color(0xFFF8F9FA), 
              colorBlendMode: BlendMode.multiply, 
            ),
          ),
          
          // 메인 메뉴 버튼
          SafeArea( 
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMenuCard(
                          context,
                          imagePath: 'assets/detect.png', 
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FaceDetectorPage(cameras: cameras),
                              ),
                            );
                          },
                        ),
                        _buildMenuCard(
                          context,
                          imagePath: 'assets/record.png', 
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RecordPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 25), 
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMenuCard(
                          context,
                          imagePath: 'assets/stats.png', 
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StatisticsPage(),
                              ),
                            );
                          },
                        ),
                        _buildMenuCard(
                          context,
                          imagePath: 'assets/alarm.png', 
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationSettingsPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 60), 
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required String imagePath, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24), 
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04), 
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(15), 
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain, 
        ),
      ),
    );
  }
}