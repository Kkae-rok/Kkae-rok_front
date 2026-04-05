import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

late List<CameraDescription> _cameras;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();

  // 1. 알림 초기화 및 iOS 권한 요청
  const initializationSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initializationSettings = InitializationSettings(iOS: initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const FaceDetectorPage(),
    );
  }
}

class FaceDetectorPage extends StatefulWidget {
  const FaceDetectorPage({super.key});
  @override
  State<FaceDetectorPage> createState() => _FaceDetectorPageState();
}

class _FaceDetectorPageState extends State<FaceDetectorPage> {
  CameraController? _controller;
  bool _isBusy = false;
  List<Face> _faces = [];
  String _currentStatus = "분석 대기 중...";
  
  double? _leftEye;
  double? _rightEye;
  double _pitch = 0.0;
  double _mouthDist = 0.0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlerting = false; 
  DateTime? _lastNotificationTime;

  // ML Kit 옵션: 반드시 Landmarks와 Contours가 켜져 있어야 합니다.
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
      enableContours: true,       
      enableClassification: true, 
      enableTracking: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    final frontCamera = _cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => _cameras.first);
    _controller = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);
    await _controller?.initialize();
    _controller?.startImageStream(_processCameraImage);
    if (mounted) setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage != null) {
      final faces = await _faceDetector.processImage(inputImage);
      
      if (mounted && faces.isNotEmpty) {
        final face = faces.first;
        _leftEye = face.leftEyeOpenProbability;
        _rightEye = face.rightEyeOpenProbability;
        _pitch = (face.headEulerAngleX ?? 0.0).toDouble(); 

        final upper = face.contours[FaceContourType.upperLipTop];
        final lower = face.contours[FaceContourType.lowerLipBottom];
        if (upper != null && lower != null && upper.points.isNotEmpty && lower.points.isNotEmpty) {
          final upperY = upper.points[upper.points.length ~/ 2].y;
          final lowerY = lower.points[lower.points.length ~/ 2].y;
          _mouthDist = (lowerY - upperY).abs().toDouble();
        }

        setState(() {
          _faces = faces;
          _currentStatus = _determineStatus(_leftEye, _rightEye, _pitch, _mouthDist);
        });
      }
    }
    _isBusy = false;
  }

  // 🍎 핵심: 고개 숙임 감지 및 경고 트리거
  String _determineStatus(double? left, double? right, double pitch, double mouth) {
    bool isEyeClosed = (left ?? 1.0) < 0.25 && (right ?? 1.0) < 0.25;
    bool isMouthOpen = mouth > 40.0;

    // [CASE 4] 진짜 졸음 (눈 감음 + 고개 숙임)
    // 숙임 각도를 -10에서 -8로 조금 더 예민하게 잡았습니다.
    if (isEyeClosed && pitch < -8.0) {
      _startAlert(); // 👈 여기서 소리/진동/알림이 터집니다!
      return "🔥 진짜 졸음 (위험!)";
    } 

    // [추가] 눈은 뜨고 있지만 고개를 심하게 떨굴 때도 경고 (CASE 2 확장)
    if (pitch < -15.0) {
      _startAlert(); 
      return "⚠️ 고개 떨굼 (위험!)";
    }

    // 정상 범위로 돌아오면 알림 즉시 정지
    _stopAlert(); 

    if (pitch > 25.0) return "⚠️ 고개 뒤로 (주의)";
    if (isMouthOpen) return "😮 하품 감지됨";
    if (isEyeClosed) return "👁️ 단순 눈 감음";

    return "✅ 정상 상태";
  }

  void _startAlert() async {
    if (_isAlerting) return;
    setState(() => _isAlerting = true);

    // 1. 푸시 알림
    final now = DateTime.now();
    if (_lastNotificationTime == null || now.difference(_lastNotificationTime!).inSeconds > 8) {
      const iosDetails = DarwinNotificationDetails(presentAlert: true, presentSound: true);
      await flutterLocalNotificationsPlugin.show(0, '🚨 졸음 위험!', ' 지금은 2795년 당신은 잠들었습니다.!', const NotificationDetails(iOS: iosDetails));
      _lastNotificationTime = now;
    }

    // 2. 소리 재생 (radar1.mp3)
    await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
    await _audioPlayer.play(AssetSource('radar1.mp3'));

    // 3. 진동 가동
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [500, 1000], repeat: 0); 
    }
  }

  void _stopAlert() {
    if (!_isAlerting) return; 
    setState(() => _isAlerting = false);
    _audioPlayer.stop();
    Vibration.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          // 상단 경고창 (빨간색 애니메이션 적용)
          Positioned(
            top: 60, left: 20, right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: _isAlerting ? Colors.red.withOpacity(0.9) : Colors.black87.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                boxShadow: _isAlerting ? [const BoxShadow(color: Colors.redAccent, blurRadius: 30, spreadRadius: 5)] : [],
              ),
              child: Text(_currentStatus, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
            ),
          ),
          // 하단 실시간 수치 데이터
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15)),
              child: Text("눈: ${(_leftEye ?? 0.0).toStringAsFixed(2)}| 고개각도: ${_pitch.toStringAsFixed(1)}° | 입: ${_mouthDist.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final sensorOrientation = _cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front).sensorOrientation;
    final inputImageMetadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation90deg,
      format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.bgra8888,
      bytesPerRow: image.planes[0].bytesPerRow,
    );
    return InputImage.fromBytes(bytes: image.planes[0].bytes, metadata: inputImageMetadata);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }
}