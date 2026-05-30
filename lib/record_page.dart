import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'timer_edit_list_page.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class TimerData {
  String docId;
  String title;
  Color color;
  int baseSeconds; 
  DateTime? startTime; 
  DateTime? dailyStartTime; 
  bool isRunning;

  TimerData({
    required this.docId,
    required this.title,
    required this.color,
    required this.baseSeconds,
    this.startTime,
    this.dailyStartTime,
    this.isRunning = false,
  });

  int get currentSeconds {
    if (isRunning && startTime != null) {
      final elapsed = DateTime.now().difference(startTime!).inSeconds;
      return baseSeconds + elapsed;
    }
    return baseSeconds;
  }
}

class _RecordPageState extends State<RecordPage> with WidgetsBindingObserver {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  List<TimerData> timers = [];
  bool isLoading = true;
  Timer? _globalTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTimersFromDB();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _globalTimer?.cancel();
    super.dispose();
  }

  // 🍎 앱 라이프사이클 감지 (백그라운드 이동 및 종료 대응 수정)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱으로 다시 돌아왔을 때 날짜 체크 및 최신 데이터 로드
      _loadTimersFromDB(); 
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // 🚨 [핵심 추가] 사용자가 홈 화면으로 나가거나 앱을 완전히 종료(킬)할 때 타이머를 강제로 멈추고 DB에 저장합니다.
      _stopAndSaveAllRunningTimers();
    }
  }

  // 🚨 [새로 추가] 현재 작동 중인 모든 타이머를 중지하고 DB에 최종 시간을 즉시 저장하는 함수
  Future<void> _stopAndSaveAllRunningTimers() async {
    bool isUpdated = false;
    for (var t in timers) {
      if (t.isRunning) {
        t.baseSeconds = t.currentSeconds; // 지나간 시간 합산
        t.isRunning = false;
        t.startTime = null;
        await _saveTimerToDB(t); // DB에 즉시 업데이트 완료할 때까지 대기(await)
        isUpdated = true;
      }
    }
    if (isUpdated && mounted) {
      setState(() {});
      _manageGlobalTimer(); // 화면 UI 및 글로벌 초시계 타이머 정지
    }
  }

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTimersFromDB() async {
    if (currentUser == null) return;

    setState(() => isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('timers')
          .where('uid', isEqualTo: currentUser!.uid)
          .get();

      List<TimerData> loadedTimers = [];
      String today = _getTodayString(); 

      for (var doc in snapshot.docs) {
        var data = doc.data();
        
        int seconds = data['seconds'] ?? 0;
        String lastUpdatedDate = data['lastUpdatedDate'] ?? data['date'] ?? '';
        
        bool isRunning = data['isRunning'] ?? false;
        DateTime? startTime;
        if (data['startTime'] != null) {
          startTime = DateTime.parse(data['startTime']);
        }
        
        DateTime? dailyStartTime;
        if (data['dailyStartTime'] != null) {
          dailyStartTime = DateTime.parse(data['dailyStartTime']);
        }

        if (lastUpdatedDate.isNotEmpty && lastUpdatedDate != today && seconds > 0) {
          await FirebaseFirestore.instance.collection('study_history').add({
            'uid': currentUser!.uid,
            'title': data['title'] ?? '이름 없음',
            'seconds': seconds,
            'date': lastUpdatedDate, 
            'dailyStartTime': data['dailyStartTime'], 
            'color': data['color'],
            'createdAt': FieldValue.serverTimestamp(),
          });

          seconds = 0; 
          isRunning = false;
          startTime = null;
          dailyStartTime = null; 
          await FirebaseFirestore.instance.collection('timers').doc(doc.id).update({
            'seconds': 0,
            'isRunning': false,
            'startTime': null,
            'dailyStartTime': null,
            'lastUpdatedDate': today,
            'date': today,
          });
        }

        loadedTimers.add(TimerData(
          docId: doc.id,
          title: data['title'] ?? '이름 없음',
          color: Color(data['color'] ?? Colors.grey.value),
          baseSeconds: seconds,
          isRunning: isRunning,
          startTime: startTime,
          dailyStartTime: dailyStartTime,
        ));
      }

      setState(() {
        timers = loadedTimers;
        isLoading = false;
      });
      _manageGlobalTimer(); 
    } catch (e) {
      print("데이터 불러오기 에러: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveTimerToDB(TimerData timer) async {
    try {
      final todayStr = _getTodayString();
      final docRef = FirebaseFirestore.instance.collection('timers').doc(timer.docId);
      final docSnap = await docRef.get();
      
      if (docSnap.exists) {
        final data = docSnap.data();
        String dbLastDate = data?['lastUpdatedDate'] ?? data?['date'] ?? '';
        int dbSeconds = (data?['seconds'] ?? 0).toInt();

        if (dbLastDate.isNotEmpty && dbLastDate != todayStr && dbSeconds > 0) {
          await FirebaseFirestore.instance.collection('study_history').add({
            'uid': currentUser!.uid,
            'title': data?['title'] ?? timer.title,
            'seconds': dbSeconds,
            'date': dbLastDate, 
            'dailyStartTime': data?['dailyStartTime'],
            'color': data?['color'],
            'createdAt': FieldValue.serverTimestamp(),
          });

          dbSeconds = 0;
          timer.baseSeconds = 0;
          if (timer.isRunning) {
            timer.startTime = DateTime.now(); 
          }
          if (mounted) setState(() {});
        }
      }

      await docRef.update({
        'seconds': timer.baseSeconds, 
        'isRunning': timer.isRunning,
        'startTime': timer.startTime?.toIso8601String(), 
        'dailyStartTime': timer.dailyStartTime?.toIso8601String(), 
        'lastUpdatedDate': todayStr,
        'date': todayStr,
      });
    } catch (e) {
      print("DB 저장 에러: $e");
    }
  }

  void _toggleTimer(int index) {
    setState(() {
      if (timers[index].isRunning) {
        timers[index].baseSeconds = timers[index].currentSeconds;
        timers[index].isRunning = false;
        timers[index].startTime = null;
        _saveTimerToDB(timers[index]); 
      } else {
        for (var t in timers) {
          if (t.isRunning) {
            t.baseSeconds = t.currentSeconds;
            t.isRunning = false;
            t.startTime = null;
            _saveTimerToDB(t); 
          }
        }
        timers[index].isRunning = true;
        timers[index].startTime = DateTime.now(); 
        
        if (timers[index].dailyStartTime == null) {
          timers[index].dailyStartTime = DateTime.now();
        }
        _saveTimerToDB(timers[index]); 
      }
      _manageGlobalTimer();
    });
  }

  void _manageGlobalTimer() {
    bool isAnyRunning = timers.any((t) => t.isRunning);

    if (isAnyRunning && (_globalTimer == null || !_globalTimer!.isActive)) {
      _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {}); 
      });
    } else if (!isAnyRunning) {
      _globalTimer?.cancel();
    }
  }

  String _formatTime(int totalSeconds) {
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    int s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get _totalSeconds => timers.fold(0, (sum, item) => sum + item.currentSeconds);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("기록", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator()) 
          : Column(
              children: [
                const SizedBox(height: 10),
                _buildCalendar(),
                const SizedBox(height: 30),
                _buildTotalTime(),
                const SizedBox(height: 30),
                Expanded(child: _buildTimerList()),
                _buildBottomButton(),
              ],
            ),
    );
  }

  Widget _buildCalendar() {
    DateTime today = DateTime.now();
    DateTime monday = today.subtract(Duration(days: today.weekday - 1));
    List<String> weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              DateTime date = monday.add(Duration(days: index));
              bool isToday = date.day == today.day;
              return Column(
                children: [
                  Text(weekdays[index], style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(color: isToday ? const Color(0xFFE57373) : Colors.transparent, shape: BoxShape.circle),
                    child: Center(
                      child: Text('${date.day}', style: TextStyle(color: isToday ? Colors.white : const Color(0xFFE57373), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 15),
          Divider(color: Colors.grey.shade100, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildTotalTime() {
    final int targetSeconds = 28800; 

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_formatTime(_totalSeconds), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          
          LayoutBuilder(
            builder: (context, constraints) {
              final double maxWidth = constraints.maxWidth; 
              double progress = _totalSeconds / targetSeconds; 
              
              if (progress > 1.0) progress = 1.0; 

              double barWidth = 0.0;
              if (_totalSeconds > 0) {
                barWidth = maxWidth * progress;
                if (barWidth < maxWidth * 0.05) {
                  barWidth = maxWidth * 0.05; 
                }
              }

              return Container(
                height: 10,
                width: maxWidth,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(5)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer( 
                    duration: const Duration(seconds: 1), 
                    curve: Curves.easeInOut,
                    width: barWidth,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE57373), 
                      borderRadius: BorderRadius.circular(5)
                    ),
                  ),
                ),
              );
            }
          )
        ],
      ),
    );
  }

  Widget _buildTimerList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("TIMERS", style: TextStyle(color: Color(0xFFE57373), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
            ],
          ),
          const SizedBox(height: 10),
          if (timers.isEmpty)
            const Expanded(child: Center(child: Text("타이머를 추가해주세요!", style: TextStyle(color: Colors.grey))))
          else
            Expanded(
              child: ListView.builder(
                itemCount: timers.length,
                itemBuilder: (context, index) => _timerItem(index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timerItem(int index) {
    TimerData data = timers[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleTimer(index),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: data.isRunning ? data.color.withOpacity(0.15) : Colors.grey.shade100,
                shape: BoxShape.circle
              ),
              child: Icon(
                data.isRunning ? Icons.pause : Icons.play_arrow, 
                size: 20, 
                color: data.isRunning ? data.color : Colors.grey.shade400
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              data.title, 
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            )
          ),
          Text(
            _formatTime(data.currentSeconds), 
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black)
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40, left: 30, right: 30),
      child: InkWell(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const TimerEditListPage()));
          _loadTimersFromDB(); 
        },
        child: Container(
          width: 160,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(25), 
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
            ]
          ),
          child: const Center(
            child: Text("타이머 추가/편집", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black54))
          ),
        ),
      ),
    );
  }
}