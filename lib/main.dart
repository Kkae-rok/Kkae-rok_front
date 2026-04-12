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
  bool _isVibrating = false;
  DateTime? _lastNotificationTime;

  // 🍎 5초 타이머 변수
  Timer? _eyeCloseTimer;

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
          final upperCenter = upper.points[upper.points.length ~/ 2];
          final lowerCenter = lower.points[lower.points.length ~/ 2];
          _mouthDist = (lowerCenter.y - upperCenter.y).abs().toDouble();
        }

        setState(() {
          _faces = faces;
          _currentStatus = _determineStatus(_leftEye, _rightEye, _pitch, _mouthDist);
        });
      }
    }
    _isBusy = false;
  }

  // 🍎 5초 지연 로직이 포함된 상태 판단 함수
  String _determineStatus(double? left, double? right, double pitch, double mouth) {
    bool isEyeClosed = (left ?? 1.0) < 0.25 && (right ?? 1.0) < 0.25;
    bool isMouthOpen = mouth > 40.0;

    // [CASE 4] 진짜 졸음 (눈 감음 + 고개 숙임) -> 즉시 풀 알림!
    if (isEyeClosed && pitch < -8.0) {
      _eyeCloseTimer?.cancel(); // 지연 타이머가 돌고 있다면 취소
      _startAlert(fullAlert: true); 
      return "🔥 진짜 졸음!! 일어나요!";
    } 

    // [CASE 2] 고개 떨굼 -> 즉시 풀 알림!
    if (pitch < -15.0) {
      _eyeCloseTimer?.cancel();
      _startAlert(fullAlert: true); 
      return "⚠️ 고개 떨구면 목 아파요!";
    }

    // [CASE 1] 단순 눈 감음 (5초 대기 로직)
    if (isEyeClosed && pitch > -5.0) {
      // 이미 알림 중이 아니고, 타이머가 돌고 있지 않을 때만 타이머 시작
      if (!_isAlerting && (_eyeCloseTimer == null || !_eyeCloseTimer!.isActive)) {
        _eyeCloseTimer = Timer(const Duration(seconds: 5), () {
          _startAlert(fullAlert: false); // 5초 경과 시 진동 시작
        });
      }
      return "👁️ 눈을 감았어요! ";
    }

    // [정상 상태] 모든 타이머와 알림 정지
    _eyeCloseTimer?.cancel(); 
    _stopAlert(); 

    if (pitch > 25.0) return "⚠️ 고개 뒤로하면 목아파요!";
    if (isMouthOpen) return "😮 하품 하지마세요!";

    return "✅ 공부 잘하고있어요!";
  }

  void _startAlert({required bool fullAlert}) async {
    if (_isVibrating && fullAlert == (_audioPlayer.state == PlayerState.playing)) return;
    
    _isVibrating = true;
    setState(() => _isAlerting = true);

    if (fullAlert) {
      // 사이렌 + 푸시
      final now = DateTime.now();
      if (_lastNotificationTime == null || now.difference(_lastNotificationTime!).inSeconds > 8) {
        const iosDetails = DarwinNotificationDetails(presentAlert: true, presentSound: true);
        await flutterLocalNotificationsPlugin.show(
          0, '🚨 졸음 위험!', '지금은 2795년 당신은 잠들었습니다.!', 
          const NotificationDetails(iOS: iosDetails)
        );
        _lastNotificationTime = now;
      }
      await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
      await _audioPlayer.play(AssetSource('radar1.mp3'));
    } else {
      await _audioPlayer.stop(); // 단순 진동 모드에선 소리 끔
    }

    // 진동 패턴 (직접 설정 가능)
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 1000, 500], repeat: -1); 
    }
  }

  void _stopAlert() {
    if (!_isAlerting && !_isVibrating) return; 
    
    setState(() {
      _isAlerting = false;
      _isVibrating = false;
    });
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
          Positioned(
            top: 60, left: 20, right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: _isAlerting ? Colors.red.withOpacity(0.9) : Colors.black87.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                boxShadow: _isAlerting ? [const BoxShadow(color: Colors.redAccent, blurRadius: 30)] : [],
              ),
              child: Text(_currentStatus, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
            ),
          ),
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15)),
              child: Text(
                "눈: ${(_leftEye ?? 0.0).toStringAsFixed(2)} | 고개: ${_pitch.toStringAsFixed(1)}° | 입: ${_mouthDist.toStringAsFixed(1)}", 
                style: const TextStyle(color: Colors.white, fontSize: 14), 
                textAlign: TextAlign.center
              ),
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
    _eyeCloseTimer?.cancel();
    _audioPlayer.dispose();
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }
}