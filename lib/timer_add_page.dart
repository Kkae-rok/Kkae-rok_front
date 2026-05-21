import 'dart:math';
import 'package:flutter/material.dart';

class TimerAddPage extends StatefulWidget {
  const TimerAddPage({super.key});

  @override
  State<TimerAddPage> createState() => _TimerAddPageState();
}

class _TimerAddPageState extends State<TimerAddPage> {
  Color _selectedColor = Colors.purpleAccent;
  final TextEditingController _nameController = TextEditingController();

  final double _wheelSize = 250.0;
  Offset _pickerOffset = const Offset(125, 180);

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _updateColor(Offset localPosition) {
    double radius = _wheelSize / 2;
    double dx = localPosition.dx - radius;
    double dy = localPosition.dy - radius;
    double distance = sqrt(dx * dx + dy * dy);

    if (distance > radius) {
      dx = dx * radius / distance;
      dy = dy * radius / distance;
      distance = radius;
    }

    setState(() {
      _pickerOffset = Offset(dx + radius, dy + radius);
      double angle = atan2(dy, dx);
      double degree = angle * 180 / pi;
      if (degree < 0) degree += 360;
      double saturation = distance / radius;
      _selectedColor = HSVColor.fromAHSV(1.0, degree, saturation, 1.0).toColor();
    });
  }

  @override
  Widget build(BuildContext context) {
    String previewName = _nameController.text.isEmpty ? "타이머" : _nameController.text;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85, 
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)), 
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black, size: 28),
                    onPressed: () => Navigator.pop(context), 
                  ),
                  const Text("타이머 추가", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                  TextButton(
                    onPressed: () {
                      
                      if (_nameController.text.isNotEmpty) {
                        Navigator.pop(context, {
                          'title': _nameController.text,
                          'color': _selectedColor,
                        });
                      } else {
                      
                        Navigator.pop(context);
                      }
                    },
                    child: const Text("저장", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
           
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            hintText: "타이머 이름",
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Icon(Icons.play_arrow, color: _selectedColor, size: 30),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              previewName,
                              style: TextStyle(fontSize: 16, color: _selectedColor, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text(
                            "00:00:00",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 50),
                      _buildInteractiveColorWheel(),
                      const SizedBox(height: 50),
                      Container(
                        height: 35,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [_selectedColor, Colors.white],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                          ]
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveColorWheel() {
    return Center(
      child: GestureDetector(
        onPanDown: (details) => _updateColor(details.localPosition),
        onPanUpdate: (details) => _updateColor(details.localPosition),
        child: SizedBox(
          width: _wheelSize,
          height: _wheelSize,
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Colors.red, Colors.pink, Colors.purple, Colors.indigo,
                      Colors.blue, Colors.cyan, Colors.green, Colors.yellow,
                      Colors.orange, Colors.red,
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.white, Colors.white.withOpacity(0.0)],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: _pickerOffset.dx - 12,
                top: _pickerOffset.dy - 12,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)
                    ]
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}