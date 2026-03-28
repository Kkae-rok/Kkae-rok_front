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
    return MaterialApp(home: FaceDetectorPage());
  }
}

class FaceDetectorPage extends StatefulWidget {
  @override
  _FaceDetectorPageState createState() => _FaceDetectorPageState();
}

class _FaceDetectorPageState extends State<FaceDetectorPage> {
  CameraController? _controller;
  bool _isBusy = false;
  List<Face> _faces = [];
  
  //  이미지 로직 반영: 실시간 수치 저장용 변수
  double? _leftEyeProb;
  double? _rightEyeProb;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // 눈 개폐 확률 계산을 위해 필수!
      performanceMode: FaceDetectorMode.accurate,
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
      
      if (mounted) {
        setState(() {
          _faces = faces;
          if (faces.isNotEmpty) {
            // 예제코드인용
            _leftEyeProb = faces.first.leftEyeOpenProbability;
            _rightEyeProb = faces.first.rightEyeOpenProbability;
          }
        });
      }
    }
    _isBusy = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("kkaerok - 졸음 감지")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          CustomPaint(painter: FacePainter(_faces, _controller!.value.previewSize!)),
          
          // 📊 수치 표시 UI 레이어
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                _buildStatusCard("왼쪽 눈", _leftEyeProb),
                const SizedBox(height: 10),
                _buildStatusCard("오른쪽 눈", _rightEyeProb),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 수치를 예쁘게 보여주는 위젯
  Widget _buildStatusCard(String title, double? value) {
    if (value == null) return Container();
    
    //  0~ 1 사이 수치 중 0.1보다 작으면 눈 감음으로 판단
    bool isClosed = value < 0.1; 
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isClosed ? Colors.red.withOpacity(0.8) : Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$title: ${value.toStringAsFixed(2)} (${isClosed ? "감았음 ⚠️" : "뜸"})",
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  // (이전과 동일한 변환 로직 및 Painter 생략 - 실제 코드에는 포함됨)
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
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  FacePainter(this.faces, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 3.0..color = Colors.greenAccent;
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