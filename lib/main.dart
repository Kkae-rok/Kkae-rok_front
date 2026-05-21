import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'detector_page.dart'; 
import 'login_page.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'firebase_options.dart'; 

late List<CameraDescription> _cameras;

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  
 
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

KakaoSdk.init(nativeAppKey: '8ab593a60ed2e8755f91f0af8f5b307d');

  
  _cameras = await availableCameras();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 3초 후 로그인 페이지로 이동
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage(cameras: _cameras)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            
            Image.asset('assets/꺠록3.png', width: 400), 
            const SizedBox(height: 20),
            const Text(
              "깨록 - 당신의 공부 파트너", 
              style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      ),
    );
  }
}