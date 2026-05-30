import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'detector_page.dart'; 
import 'record_page.dart';   
import 'notification_settings_page.dart'; 
import 'statistics_page.dart';

class MainMenuPage extends StatelessWidget {
  final List<CameraDescription> cameras; 
  const MainMenuPage({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand, 
        children: [
          // 1층: 시계 모양 워터마크 배경
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
          
          // 2층: 반투명 메인 메뉴 버튼들
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
                          imagePath: 'assets/detect3.png', 
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
                          imagePath: 'assets/record3.png', 
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
                          imagePath: 'assets/stats3.png', 
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
                          imagePath: 'assets/alarm3.png', 
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NotificationSettingsPage(cameras: cameras),
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

  // 🍎 투명도를 0.5(50%)로 확 낮춰서 뒤가 잘 비치게 수정!
  Widget _buildMenuCard(BuildContext context, {required String imagePath, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 155, 
        height: 175, 
        decoration: BoxDecoration(
          // 👇 이 숫자가 0.5로 변경되었습니다! (필요하면 0.3 처럼 더 낮추셔도 됩니다)
          color: Colors.white.withOpacity(0.5), 
          borderRadius: BorderRadius.circular(30), 
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02), 
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20), 
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain, 
        ),
      ),
    );
  }
}