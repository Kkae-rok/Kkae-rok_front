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

  // 1. 시스템 알림 초기화
  const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettingsIOS = DarwinInitializationSettings();
  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  
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
  DateTime? _lastNotificationTime; // 알림 쿨타임용 변수

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    final frontCamera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front, 
      orElse: () => _cameras.first
    );
    _controller = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);
    
    try {
      await _controller?.initialize();
      _controller?.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint("카메라 초기화 실패: $e");
    }
    
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
        _pitch = face.headEulerAngleX ?? 0.0; 

        final upperLip = face.contours[FaceContourType.upperLipTop];
        final lowerLip = face.contours[FaceContourType.lowerLipBottom];
        if (upperLip != null && lowerLip != null && upperLip.points.isNotEmpty && lowerLip.points.isNotEmpty) {
          _mouthDist = (lowerLip.points.first.y - upperLip.points.first.y).abs().toDouble();
        }

        setState(() {
          _faces = faces;
          _currentStatus = _determineStatus(_leftEye, _rightEye, _pitch, _mouthDist);
        });
      }
    }
    _isBusy = false;
  }

  String _determineStatus(double? left, double? right, double pitch, double mouth) {
    bool isEyeClosed = (left ?? 1.0) < 0.25 && (right ?? 1.0) < 0.25;
    bool isMouthOpen = mouth > 45.0;

    if (isEyeClosed && pitch < -10.0) {
      _startAlert(); 
      return "🔥 진짜 졸음 (위험!)";
    } else {
      _stopAlert(); 
      if (pitch < -18.0) return "⚠️ 고개 떨굼 (주의)";
      if (pitch > 30) return "⚠️ 고개 wjwcla (주의)";
      if (isMouthOpen) return "😮 하품 감지됨";
      if (isEyeClosed) return "👁️ 눈 감음";
      return "✅ 정상 상태";
    }
  }

  Future<void> _showSystemNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'drowsy_id', '졸음알림', 
      importance: Importance.max, 
      priority: Priority.high
    );
    const iosDetails = DarwinNotificationDetails(presentAlert: true, presentSound: true);
    const platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await flutterLocalNotificationsPlugin.show(
      0, 
      '🚨 졸음 감지!', 
      '지금은 2795년 입니다. 일어나세요!', 
      platformDetails
    );
  }

  // --- 핵심: 안정적인 알림 및 소리 재생 로직 ---
  void _startAlert() async {
    if (_isAlerting) return; // 이미 알림 중이면 중단
    _isAlerting = true;

    // 1. 시스템 알림 쿨타임 (10초에 한 번만 뜨게 설정)
    final now = DateTime.now();
    if (_lastNotificationTime == null || now.difference(_lastNotificationTime!).inSeconds > 10) {
      _showSystemNotification();
      _lastNotificationTime = now;
    }

    // 2. 오디오 버퍼 초기화 후 재생 (소리 끊김 방지)
    await _audioPlayer.stop(); // 이전 상태가 있다면 정지
    await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
    await _audioPlayer.play(AssetSource('radar1.mp3'), volume: 1.0);

    // 3. 진동 시작
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [500, 1000], repeat: 0); 
    }
  }

  void _stopAlert() async {
    if (!_isAlerting) return; 
    _isAlerting = false;

    await _audioPlayer.stop(); // 소리 즉시 중단
    Vibration.cancel(); // 진동 즉시 중단
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          CustomPaint(painter: FacePainter(_faces, _controller!.value.previewSize!)),
          
          // 상단 상태 안내 바
          Positioned(
            top: 60, left: 20, right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isAlerting 
                    ? Colors.red.withValues(alpha: 0.9) 
                    : Colors.black87.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                boxShadow: _isAlerting ? [const BoxShadow(color: Colors.redAccent, blurRadius: 15)] : [],
              ),
              child: Text(
                _currentStatus, 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), 
                textAlign: TextAlign.center
              ),
            ),
          ),

          // 하단 세부 수치 정보
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)),
              child: Text(
                "눈 감음: ${(_leftEye ?? 0).toStringAsFixed(2)} | 고개: ${_pitch.toStringAsFixed(1)}°",
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
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
    _audioPlayer.dispose();
    _controller?.stopImageStream();
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  FacePainter(this.faces, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    for (var face in faces) {
      final double scaleX = size.width / imageSize.height;
      final double scaleY = size.height / imageSize.width;
      
      final rect = Rect.fromLTRB(
        size.width - (face.boundingBox.right * scaleX),
        face.boundingBox.top * scaleY,
        size.width - (face.boundingBox.left * scaleX),
        face.boundingBox.bottom * scaleY,
      );
      canvas.drawRect(rect, paint);
    }
  }
  @override
  bool shouldRepaint(FacePainter oldDelegate) => oldDelegate.faces != faces;
}