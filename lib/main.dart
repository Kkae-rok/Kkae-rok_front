import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

// 전역 변수로 카메라 목록 저장
List<CameraDescription> _cameras = [];

Future<void> main() async {
  // 1. 플러터 엔진과 바인딩 확인 (비동기 실행 전 필수)
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 2. 기기에서 사용 가능한 카메라 목록 가져오기
    _cameras = await availableCameras();
  } on CameraException catch (e) {
    print('카메라를 찾을 수 없습니다: ${e.code}, ${e.description}');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CatchIt - 졸음 감지',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? controller;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // 카메라 초기화 로직
  void _initializeCamera() async {
    if (_cameras.isEmpty) return;

    // 3. 전면 카메라 찾기 (졸음 감지용)
    final frontCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    // 4. 컨트롤러 설정 (해상도는 적당히 High로 설정 - 너무 높으면 M3라도 발열 생길 수 있음)
    controller = CameraController(frontCamera, ResolutionPreset.high);

    try {
      await controller!.initialize();
      if (!mounted) return;
      setState(() {}); // 화면 갱신해서 카메라 띄우기
    } catch (e) {
      print('카메라 초기화 중 에러 발생: $e');
    }
  }

  @override
  void dispose() {
    // 5. 앱 종료 시 카메라 자원 해제 (중요!)
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 카메라가 준비되지 않았을 때 하얀 화면 대신 로딩 표시
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("카메라를 준비하고 있습니다..."),
            ],
          ),
        ),
      );
    }

    // 6. 카메라 미리보기 화면
    return Scaffold(
      appBar: AppBar(title: const Text("CatchIt 카메라 테스트")),
      body: Stack(
        children: [
          // 전체 화면으로 카메라 미리보기 출력
          SizedBox.expand(
            child: CameraPreview(controller!),
          ),
          // 화면 위에 텍스트 표시
          const Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "얼굴을 비춰주세요",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}