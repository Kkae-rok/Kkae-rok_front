import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class FaceDetectorPage extends StatefulWidget {
  final List<CameraDescription> cameras; 
  const FaceDetectorPage({super.key, required this.cameras});

  @override
  State<FaceDetectorPage> createState() => _FaceDetectorPageState();
}

class _FaceDetectorPageState extends State<FaceDetectorPage> {
  CameraController? _controller;
  bool _isBusy = false;
  String _currentStatus = "분석 대기 중...";
  
  double? _leftEye;
  double? _rightEye;
  double _pitch = 0.0;
  double _mouthDist = 0.0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  bool _isAlerting = false; 
  bool _isVibrating = false;
  
  bool _isSoundSettingOn = true;
  bool _isVibrationSettingOn = true;

  DateTime? _lastNotificationTime;
  Timer? _eyeCloseTimer;     // 일반 눈감기용 (5초)
  Timer? _realDrowsyTimer;   // 숙임/졸음 체크용 (3초)

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
    _loadAlertSettings();
    _initNotifications(); 
    _initializeCamera();
  }

  Future<void> _loadAlertSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSoundSettingOn = prefs.getBool('isSoundEnabled') ?? true;
      _isVibrationSettingOn = prefs.getBool('isVibrationEnabled') ?? true;
    });
  }

  Future<void> _initNotifications() async {
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(iOS: iosInit);
    await _notifications.initialize(initSettings);
  }

  void _initializeCamera() async {
    if (widget.cameras.isEmpty) return;
    final frontCamera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front, 
      orElse: () => widget.cameras.first
    );
    _controller = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: ImageFormatGroup.bgra8888);
    try {
      await _controller?.initialize();
      _controller?.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint("카메라 에러: $e");
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
        _pitch = (face.headEulerAngleX ?? 0.0).toDouble(); 
        final upper = face.contours[FaceContourType.upperLipTop];
        final lower = face.contours[FaceContourType.lowerLipBottom];
        if (upper != null && lower != null && upper.points.isNotEmpty && lower.points.isNotEmpty) {
          final upperCenter = upper.points[upper.points.length ~/ 2];
          final lowerCenter = lower.points[lower.points.length ~/ 2];
          _mouthDist = (lowerCenter.y - upperCenter.y).abs().toDouble();
        }
        setState(() {
          _currentStatus = _determineStatus(_leftEye, _rightEye, _pitch, _mouthDist);
        });
      }
    }
    _isBusy = false;
  }

  String _determineStatus(double? left, double? right, double pitch, double mouth) {
    bool isEyeClosed = (left ?? 1.0) < 0.25 && (right ?? 1.0) < 0.25;
    bool isMouthOpen = mouth > 40.0;

    // 고개 떨구기 상황 통합 (그냥 숙이든, 눈 감고 숙이든 3초 카운트)
    // 눈을 감았으면서 고개를 약간 숙였거나, 고개를 아주 깊게 떨군 경우
    if ((isEyeClosed && pitch < -8.0) || pitch < -15.0) {
      _eyeCloseTimer?.cancel(); // 일반 눈감기 타이머는 취소
      
      // 타이머가 돌고 있지 않다면 시작
      if (!_isAlerting && (_realDrowsyTimer == null || !_realDrowsyTimer!.isActive)) {
        _realDrowsyTimer = Timer(const Duration(seconds: 3), () {
          _startAlert(fullAlert: true); // 3초 뒤에 알람 울림
        });
      }
      return "🔥 고개 숙임/졸음 감지 중 (3초)...";
    } 

    // 그냥 눈만 감은 경우 - 5초 카운트
    if (isEyeClosed && pitch > -5.0) {
      _realDrowsyTimer?.cancel(); // 고개 숙임 타이머는 취소
      if (!_isAlerting && (_eyeCloseTimer == null || !_eyeCloseTimer!.isActive)) {
        _eyeCloseTimer = Timer(const Duration(seconds: 5), () {
          _startAlert(fullAlert: false);
        });
      }
      return "👁️ 눈을 감았어요!";
    }

    // 정상 상태로 돌아오면 모든 타이머와 알람 중지
    _realDrowsyTimer?.cancel(); 
    _eyeCloseTimer?.cancel(); 
    _stopAlert(); 

    if (pitch > 25.0) return "⚠️ 고개 뒤로하면 목아파요!";
    if (isMouthOpen) return "😮 하품 하지마세요!";

    return "✅ 공부 잘하고있어요!";
  }

  void _startAlert({required bool fullAlert}) async {
    setState(() => _isAlerting = true);

    if (_isSoundSettingOn) {
      if (_audioPlayer.state != PlayerState.playing) {
        final now = DateTime.now();
        if (_lastNotificationTime == null || now.difference(_lastNotificationTime!).inSeconds > 8) {
          const iosDetails = DarwinNotificationDetails(presentAlert: true, presentSound: true);
          await _notifications.show(0, '🚨 졸음 위험!', '잠깐! 졸고 계신 것 같아요. 일어나세요!', const NotificationDetails(iOS: iosDetails));
          _lastNotificationTime = now;
        }
        await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
        await _audioPlayer.play(AssetSource('radar1.mp3'));
      }
    }

    if (_isVibrationSettingOn && !_isVibrating) {
      if (await Vibration.hasVibrator() ?? false) {
        _isVibrating = true;
        Vibration.vibrate(pattern: [0, 500, 1000, 500], repeat: -1); 
      }
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
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          Positioned(
            top: 100, left: 20, right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: _isAlerting ? Colors.red.withOpacity(0.85) : Colors.black87.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                boxShadow: _isAlerting ? [const BoxShadow(color: Colors.redAccent, blurRadius: 30)] : [],
              ),
              child: Text(_currentStatus, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
            ),
          ),
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)),
              child: Text("눈: ${(_leftEye ?? 0.0).toStringAsFixed(2)} | 고개: ${_pitch.toStringAsFixed(1)}° | 입: ${_mouthDist.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final sensorOrientation = widget.cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front).sensorOrientation;
    final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;
    final inputImageMetadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation90deg,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );
    return InputImage.fromBytes(bytes: image.planes[0].bytes, metadata: inputImageMetadata);
  }

  @override
  void dispose() {
    _eyeCloseTimer?.cancel();
    _realDrowsyTimer?.cancel(); 
    _audioPlayer.dispose();
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }
}