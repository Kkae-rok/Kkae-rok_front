import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const FaceDetectorPage(),
    );
  }
}

class FaceDetectorPage extends StatefulWidget {
  const FaceDetectorPage({super.key});

  @override
  _FaceDetectorPageState createState() => _FaceDetectorPageState();
}

class _FaceDetectorPageState extends State<FaceDetectorPage> {
  CameraController? _controller;
  bool _isBusy = false;
  List<Face> _faces = [];
  String _currentStatus = "분석 대기 중...";
  
  // 분석용 데이터 변수
  double? _leftEye;
  double? _rightEye;
  double _pitch = 0.0;
  double _mouthDist = 0.0;
final FaceDetector _faceDetector = FaceDetector(
  options: FaceDetectorOptions(
    // 1. performanceMode: accurate (정확성 우선)
    performanceMode: FaceDetectorMode.accurate,
    
    // 2. landmarkMode: all (눈, 입 위치 등 특징 감지)
    enableLandmarks: true,
    
    // 3. contourMode: all (입술 윤곽선 감지)
    enableContours: true,
    
    // 4. classificationMode: all (눈 뜨고 있는지 분류)
    enableClassification: true,
    
    // 5. isTrackingEnabled: true (얼굴 추적 활성화)
    enableTracking: true,
    
    // 6. minFaceSize: 기본값 0.1
    minFaceSize: 0.1,
  ),
);
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    final frontCamera = _cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
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
        
        // 1. 눈 감음 수치 추출
        _leftEye = face.leftEyeOpenProbability;
        _rightEye = face.rightEyeOpenProbability;
        
        // 2. 고개 숙임 각도 (Pitch)
        _pitch = face.headEulerAngleX ?? 0.0; 

       // 3. 입 벌어짐 계산 (윤곽선 활용)
final upperLipContour = face.contours[FaceContourType.upperLipTop];
final lowerLipContour = face.contours[FaceContourType.lowerLipBottom];

if (upperLipContour != null && lowerLipContour != null && 
    upperLipContour.points.isNotEmpty && lowerLipContour.points.isNotEmpty) {
  
  // 입술 윤곽선의 중앙점 부근 좌표를 사용하여 거리를 측정합니다.
  final upperY = upperLipContour.points.first.y;
  final lowerY = lowerLipContour.points.first.y;
  
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

  
  String _determineStatus(double? left, double? right, double pitch, double mouth) {
    bool isEyeClosed = (left ?? 1.0) < 0.3 && (right ?? 1.0) < 0.3; //
    bool isMouthOpen = mouth > 5.0; // 하품 임계값 (조정 가능)

    // CASE 3: 눈 감음 + 고개 숙임 (진짜 졸음)
    if (isEyeClosed && pitch < -10.0) {
      return "🔥 진짜 졸음 (위험!)";
    }
    // CASE 2: 고개 떨굼 (눈은 뜨고 있음)
    if (pitch < -15.0 && !isEyeClosed) {
      return "⚠️ 고개 떨굼 (주의)";
    }
    // CASE 1: 단순 눈 감음 (정면 응시 중)
    if (isEyeClosed && pitch > -5.0) {
      return "👁️ 단순 눈 감음";
    }
    // 하품 감지
    if (isMouthOpen) {
      return "😮 하품 감지됨";
    }

    return "✅ 정상 상태";
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
          
          // 실시간 상태 알림창
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _currentStatus.contains("위험") ? Colors.red.withOpacity(0.8) : Colors.black87,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                _currentStatus,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // 하단 상세 수치 표시
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Text(
                "눈: ${(_leftEye ?? 0).toStringAsFixed(2)} | Pitch: ${_pitch.toStringAsFixed(1)}° | 입: ${_mouthDist.toStringAsFixed(1)}",
                style: const TextStyle(color: Colors.white),
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
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.0..color = Colors.greenAccent;
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
  bool shouldRepaint(FacePainter oldDelegate) => true;
}