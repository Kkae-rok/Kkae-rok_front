import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class DailyRecord {
  int totalSeconds = 0;
  DateTime? startTime;
  DateTime? endTime;
}

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int _selectedTab = 0; // 0: 일간, 1: 주간, 2: 월간
  DateTime _focusedDate = DateTime.now(); 
  DateTime _selectedDate = DateTime.now(); 

  final PageController _pageController = PageController();
  int _currentPage = 0; 

  Map<String, DailyRecord> _dailyRecords = {};
  bool _isLoading = true;


  int _chartPeriod = 6; 

  final List<int> _periodOptions = [1, 2, 3, 6, 12]; 
  DateTime _chartEndMonth = DateTime.now(); 

  @override
  void initState() {
    super.initState();
    _fetchStatisticsFromDB(); 
  }

  Future<void> _fetchStatisticsFromDB() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('timers')
          .where('uid', isEqualTo: user.uid)
          .get();

      Map<String, DailyRecord> loadedData = {};
      
      for (var doc in snapshot.docs) {
        var data = doc.data();
        String dateKey = data['lastUpdatedDate'] ?? ''; 
        int seconds = data['seconds'] ?? 0;             
        
        DateTime? createdAt;
        if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        }

        if (dateKey.isNotEmpty) {
          if (!loadedData.containsKey(dateKey)) {
            loadedData[dateKey] = DailyRecord();
          }
          loadedData[dateKey]!.totalSeconds += seconds;

          if (createdAt != null) {
            if (loadedData[dateKey]!.startTime == null || createdAt.isBefore(loadedData[dateKey]!.startTime!)) {
              loadedData[dateKey]!.startTime = createdAt;
            }
            DateTime calculatedEndTime = createdAt.add(Duration(seconds: seconds));
            if (loadedData[dateKey]!.endTime == null || calculatedEndTime.isAfter(loadedData[dateKey]!.endTime!)) {
              loadedData[dateKey]!.endTime = calculatedEndTime;
            }
          }
        }
      }

      setState(() {
        _dailyRecords = loadedData; 
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("통계 데이터 불러오기 에러: $e");
      setState(() => _isLoading = false);
    }
  }


  Future<void> _showPeriodPicker(BuildContext context) async {
    int tempIndex = _periodOptions.indexOf(_chartPeriod);
    if (tempIndex == -1) tempIndex = 0;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context), 
                      child: const Text("취소", style: TextStyle(color: Colors.grey, fontSize: 16))
                    ),
                    const Text("통계 기간 선택", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                    TextButton(
                      onPressed: () {
                        setState(() => _chartPeriod = _periodOptions[tempIndex]);
                        Navigator.pop(context);
                      },
                      child: const Text("완료", style: TextStyle(color: Color(0xFFE57373), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: tempIndex),
                  itemExtent: 40,
                  onSelectedItemChanged: (int index) {
                    tempIndex = index;
                  },
                  children: _periodOptions.map((period) {
                    return Center(
                      child: Text(
                        period == 12 ? "1년" : "$period개월", 
                        style: const TextStyle(fontSize: 18, color: Colors.black87)
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatAMPM(DateTime? dt) {
    if (dt == null) return "-";
    String ampm = dt.hour < 12 ? "오전" : "오후";
    int hour = dt.hour % 12;
    if (hour == 0) hour = 12;
    String minute = dt.minute.toString().padLeft(2, '0');
    return "$ampm $hour:$minute";
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("타이머 통계", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE57373)))
          : Column(
              children: [
                if (_currentPage == 0) ...[
                  const SizedBox(height: 10),
                  _buildTabs(),
                  const SizedBox(height: 30),
                ] else ...[
                  const SizedBox(height: 20),
                ],
                
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() => _currentPage = index);
                            },
                            children: [
                              _buildCalendarPage(),       
                              _buildDetailedStatsPage(),  
                              _buildMonthlyLineChartPage(), 
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _buildDot(index),
                          )),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? const Color(0xFFE57373) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  
  Widget _buildCalendarPage() {
    return Column(
      children: [
        _buildDateSelector(), 
        const SizedBox(height: 20),
        if (_selectedTab != 2) _buildWeekdaysHeader(),
        if (_selectedTab != 2) const SizedBox(height: 10),
        Expanded(
          child: _selectedTab == 2 
              ? _buildMonthlyGrid() 
              : _buildCalendarBody(), 
        ), 
        const SizedBox(height: 10),
        _buildLegend(), 
      ],
    );
  }

  Widget _buildDetailedStatsPage() {
    List<String> weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    String korWeekday = weekdays[_selectedDate.weekday % 7];
    String formattedDate = '${_selectedDate.month}월 ${_selectedDate.day}일 ($korWeekday)';

    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    DailyRecord? record = _dailyRecords[dateKey];
    
    int totalSec = record?.totalSeconds ?? 0;
    int h = totalSec ~/ 3600;
    int m = (totalSec % 3600) ~/ 60;
    int s = totalSec % 60;
    String totalTimeStr = '${h.toString()}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    
    DateTime? startTime = record?.startTime;
    DateTime? calculatedEndTime = startTime != null ? startTime.add(Duration(seconds: totalSec)) : null;

    String startTimeStr = _formatAMPM(startTime);
    String endTimeStr = _formatAMPM(calculatedEndTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20), 
        Center(child: Text(formattedDate, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
        const SizedBox(height: 50),
        Row(
          children: [
            Expanded(child: _buildInfoItem("총 공부 시간", totalTimeStr)),
            Expanded(child: _buildInfoItem("시작 시간", startTimeStr)), 
          ],
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(child: const SizedBox()), 
            Expanded(child: _buildInfoItem("종료 시간", endTimeStr)), 
          ],
        ),
      ],
    );
  }

  Widget _buildInfoItem(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFFE57373), fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontSize: 24, color: Colors.black, fontWeight: FontWeight.bold)), 
      ],
    );
  }

  
  Widget _buildMonthlyLineChartPage() {
    List<int> chartMinutes = [];
    List<String> chartLabels = [];
    
    if (_chartPeriod == 1) {
      int daysInMonth = DateTime(_chartEndMonth.year, _chartEndMonth.month + 1, 0).day;
      for (int i = 1; i <= daysInMonth; i++) {
        DateTime dDate = DateTime(_chartEndMonth.year, _chartEndMonth.month, i);
        String dayKey = DateFormat('yyyy-MM-dd').format(dDate);

        int dayTotalSec = _dailyRecords[dayKey]?.totalSeconds ?? 0;
        chartMinutes.add(dayTotalSec ~/ 60);

        if (i == 1 || i == 7 || i == 14 || i == 21 || i == daysInMonth) {
          chartLabels.add('${i}일');
        } else {
          chartLabels.add('');
        }
      }
    } 
    else {
      for (int i = _chartPeriod - 1; i >= 0; i--) {
        DateTime mDate = DateTime(_chartEndMonth.year, _chartEndMonth.month - i, 1);
        chartLabels.add('${mDate.month}월');

        int monthTotalSec = 0;
        String monthPrefix = DateFormat('yyyy-MM').format(mDate);
        
        _dailyRecords.forEach((key, record) {
          if (key.startsWith(monthPrefix)) monthTotalSec += record.totalSeconds;
        });
        chartMinutes.add(monthTotalSec ~/ 60); 
      }
    }

    Widget topTextWidget;
    Widget highlightTextWidget;

    if (_chartPeriod == 1) {
      int totalMin = chartMinutes.isNotEmpty ? chartMinutes.reduce((a, b) => a + b) : 0;
      int h = totalMin ~/ 60;
      int m = totalMin % 60;
      
      topTextWidget = Text("${_chartEndMonth.month}월 집중 시간은", style: const TextStyle(fontSize: 15, color: Colors.black54, fontWeight: FontWeight.w500));
      highlightTextWidget = RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$h', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFFE57373))),
            const TextSpan(text: ' 시간 ', style: TextStyle(fontSize: 16, color: Color(0xFFE57373), fontWeight: FontWeight.w500)),
            TextSpan(text: '$m', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFFE57373))),
            const TextSpan(text: ' 분 ', style: TextStyle(fontSize: 16, color: Color(0xFFE57373), fontWeight: FontWeight.w500)),
            const TextSpan(text: '입니다!', style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    } else if (_chartPeriod == 2) {
      int thisMonthMin = chartMinutes.isNotEmpty ? chartMinutes.last : 0;
      int lastMonthMin = chartMinutes.length > 1 ? chartMinutes.first : 0;
      int diffMin = thisMonthMin - lastMonthMin;
      
      String verb = diffMin >= 0 ? "늘었어요!" : "줄었어요!";
      int absDiff = diffMin.abs();
      int diffH = absDiff ~/ 60;
      int diffM = absDiff % 60;
      
      topTextWidget = const Text("집중 시간이 지난달보다", style: TextStyle(fontSize: 15, color: Colors.black54, fontWeight: FontWeight.w500));
      highlightTextWidget = RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$diffH', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFFE57373))),
            const TextSpan(text: ' 시간 ', style: TextStyle(fontSize: 16, color: Color(0xFFE57373), fontWeight: FontWeight.w500)),
            TextSpan(text: '$diffM', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFFE57373))),
            const TextSpan(text: ' 분 ', style: TextStyle(fontSize: 16, color: Color(0xFFE57373), fontWeight: FontWeight.w500)),
            TextSpan(text: verb, style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    } else {
      int totalMin = chartMinutes.isNotEmpty ? chartMinutes.reduce((a, b) => a + b) : 0;
      int avgMin = chartMinutes.isNotEmpty ? (totalMin / chartMinutes.length).round() : 0;
      int avgH = avgMin ~/ 60;
      int avgM = avgMin % 60;
      
      String periodStr = _chartPeriod == 12 ? "1년" : "$_chartPeriod개월";
      
      topTextWidget = Text("최근 $periodStr 평균 집중 시간은", style: const TextStyle(fontSize: 15, color: Colors.black54, fontWeight: FontWeight.w500));
      highlightTextWidget = RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$avgH', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFFE57373))),
            const TextSpan(text: ' 시간 ', style: TextStyle(fontSize: 16, color: Color(0xFFE57373), fontWeight: FontWeight.w500)),
            TextSpan(text: '$avgM', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFFE57373))),
            const TextSpan(text: ' 분 ', style: TextStyle(fontSize: 16, color: Color(0xFFE57373), fontWeight: FontWeight.w500)),
            const TextSpan(text: '이에요!', style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    String buttonLabel = _chartPeriod == 12 ? "최근 1년" : "최근 $_chartPeriod개월";

    return Column(
      children: [
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _showPeriodPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE57373)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_drop_down_circle, size: 16, color: Color(0xFFE57373)),
                const SizedBox(width: 8),
                Text(
                  buttonLabel, 
                  style: const TextStyle(color: Color(0xFFE57373), fontWeight: FontWeight.bold, fontSize: 13)
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 25),
        topTextWidget,
        const SizedBox(height: 5),
        highlightTextWidget,
        const SizedBox(height: 35),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: CustomPaint(
              painter: LineChartPainter(chartMinutes, chartLabels),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  
  Widget _buildTabs() {
    List<String> tabs = ['일간', '주간', '월간'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(tabs.length, (index) {
        bool isSelected = _selectedTab == index;
        return GestureDetector(
          onTap: () => setState(() => _selectedTab = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text(tabs[index], style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? const Color(0xFFE57373) : Colors.grey.shade400)),
                const SizedBox(height: 5),
                if (isSelected) Container(width: 30, height: 2, color: const Color(0xFFE57373))
                else const SizedBox(height: 2)
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDateSelector() {
    bool isMonthly = _selectedTab == 2;
    String titleText = isMonthly ? "${_focusedDate.year % 100}년" : "${_focusedDate.year}년 ${_focusedDate.month}월"; 
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircleButton(Icons.chevron_left, () => setState(() => _focusedDate = isMonthly ? DateTime(_focusedDate.year - 1, 1) : DateTime(_focusedDate.year, _focusedDate.month - 1))),
        const SizedBox(width: 15),
        Text(titleText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 15),
        _buildCircleButton(Icons.chevron_right, () => setState(() => _focusedDate = isMonthly ? DateTime(_focusedDate.year + 1, 1) : DateTime(_focusedDate.year, _focusedDate.month + 1))),
      ],
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)), child: Icon(icon, color: Colors.grey, size: 18)));
  }

  Widget _buildWeekdaysHeader() {
    List<String> weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: weekdays.map((day) => Text(day, style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600, fontSize: 13))).toList());
  }

  Widget _buildCalendarBody() {
    DateTime firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    int daysInMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
    int firstWeekday = firstDayOfMonth.weekday; 
    List<DateTime> days = [];
    for (int i = firstWeekday - 1; i >= 1; i--) days.add(firstDayOfMonth.subtract(Duration(days: i)));
    for (int i = 0; i < daysInMonth; i++) days.add(firstDayOfMonth.add(Duration(days: i)));
    int remaining = (7 - (days.length % 7)) % 7;
    DateTime lastDay = days.last;
    for (int i = 1; i <= remaining; i++) days.add(lastDay.add(Duration(days: i)));
    List<List<DateTime>> weeks = [];
    for (int i = 0; i < days.length; i += 7) weeks.add(days.sublist(i, i + 7));
    return SingleChildScrollView(
      child: Column(children: weeks.map((week) => _buildWeekRow(week)).toList()),
    );
  }

  Widget _buildWeekRow(List<DateTime> week) {
    bool isWeekSelected = _selectedTab == 1 && week.any((date) => _isSameDay(date, _selectedDate));
    int weeklyTotalSec = 0;
    if (_selectedTab == 1) {
      for (var d in week) {
        weeklyTotalSec += _dailyRecords[DateFormat('yyyy-MM-dd').format(d)]?.totalSeconds ?? 0;
      }
    }

    return GestureDetector(
      onTap: () { if (_selectedTab == 1) setState(() => _selectedDate = week.first); },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: isWeekSelected ? BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE57373), width: 1.5)) : const BoxDecoration(color: Colors.transparent),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: week.map((date) {
                bool isCurrentMonth = date.month == _focusedDate.month;
                bool isDaySelected = _selectedTab == 0 && _isSameDay(date, _selectedDate); 
                int studySec = _dailyRecords[DateFormat('yyyy-MM-dd').format(date)]?.totalSeconds ?? 0;
                int studyMinutes = studySec ~/ 60;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_selectedTab == 0 || _selectedTab == 1) setState(() => _selectedDate = date); 
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4), height: 40,
                      decoration: isDaySelected ? BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE57373), width: 1.5))
                          : BoxDecoration(color: isCurrentMonth && !isWeekSelected ? _getHeatmapColor(studyMinutes) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${date.day}', style: TextStyle(fontSize: 14, fontWeight: (isDaySelected || isWeekSelected) ? FontWeight.bold : FontWeight.w500, color: (isDaySelected || isWeekSelected) ? const Color(0xFFE57373) : isCurrentMonth ? Colors.black87 : Colors.grey.shade300)),
                          if (_selectedTab == 0 && studyMinutes > 0) 
                            Text('${studyMinutes ~/ 60}:${(studyMinutes % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 9, color: Color(0xFFE57373))),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_selectedTab == 1 && weeklyTotalSec > 0) ...[
              const SizedBox(height: 4),
              Text('주간 누적: ${weeklyTotalSec ~/ 3600}H ${((weeklyTotalSec % 3600) ~/ 60).toString().padLeft(2, '0')}M', style: const TextStyle(fontSize: 10, color: Color(0xFFE57373), fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, 
        childAspectRatio: 1.0, 
        crossAxisSpacing: 10, 
        mainAxisSpacing: 20
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        int month = index + 1;
        bool isSelected = _selectedDate.year == _focusedDate.year && _selectedDate.month == month;
        int monthTotalSec = 0;
        String monthPrefix = DateFormat('yyyy-MM').format(DateTime(_focusedDate.year, month, 1));
        
        _dailyRecords.forEach((key, record) {
          if (key.startsWith(monthPrefix)) monthTotalSec += record.totalSeconds;
        });

        int monthTotalMin = monthTotalSec ~/ 60;
        Color heatmapColor = _getHeatmapColor(monthTotalMin);
        
        Color bgColor = isSelected 
            ? (heatmapColor == Colors.transparent ? const Color(0xFFFFEBEE) : heatmapColor) 
            : heatmapColor;

        return GestureDetector(
          onTap: () => setState(() => _selectedDate = DateTime(_focusedDate.year, month, 1)),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: isSelected ? Border.all(color: const Color(0xFFE57373), width: 1.5) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$month월', 
                  style: TextStyle(
                    fontSize: 15, 
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, 
                    color: monthTotalMin >= 360 ? Colors.white : (isSelected ? const Color(0xFFE57373) : Colors.black87)
                  )
                ),
                if (monthTotalSec > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${monthTotalSec ~/ 3600}H ${((monthTotalSec % 3600) ~/ 60).toString().padLeft(2, '0')}M', 
                    style: TextStyle(
                      fontSize: 10, 
                      color: monthTotalMin >= 360 ? Colors.white : const Color(0xFFE57373), 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendItem(1, "0+"), 
            _legendItem(180, "3+"), 
            _legendItem(360, "6+"), 
            _legendItem(540, "9+"), 
            _legendItem(720, "12+"),
          ]
        ),
      ],
    );
  }

  Widget _legendItem(int minutes, String label) {
    return Container(margin: const EdgeInsets.only(right: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _getHeatmapColor(minutes), borderRadius: BorderRadius.circular(4)), child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)));
  }

  Color _getHeatmapColor(int minutes) {
    if (minutes == 0) return Colors.transparent;
    if (minutes < 180) return const Color(0xFFFFCDD2); 
    if (minutes < 360) return const Color(0xFFEF9A9A); 
    if (minutes < 540) return const Color(0xFFE57373); 
    if (minutes < 720) return const Color(0xFFEF5350); 
    return const Color(0xFFE53935); 
  }

  bool _isSameDay(DateTime d1, DateTime d2) { return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day; }
}


class LineChartPainter extends CustomPainter {
  final List<int> minutes;
  final List<String> xLabels;

  LineChartPainter(this.minutes, this.xLabels);

  @override
  void paint(Canvas canvas, Size size) {
    if (minutes.isEmpty) return;
    int maxMin = minutes.reduce(max);
    if (maxMin == 0) maxMin = 1; 

    final double topPadding = 40.0; 
    final double bottomPadding = 30.0; 
    final double chartHeight = size.height - topPadding - bottomPadding;
    
    final Paint linePaint = Paint()..color = const Color(0xFFE57373)..strokeWidth = 2.0..style = PaintingStyle.stroke;
    final Paint dottedLinePaint = Paint()..color = Colors.grey.shade300..strokeWidth = 1.0;

    for (int i = 0; i <= 2; i++) {
      double y = topPadding + (chartHeight / 2) * i;
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), dottedLinePaint);
    }

    List<Offset> points = [];
    double xStep = size.width / (minutes.length > 1 ? minutes.length - 1 : 1);
    for (int i = 0; i < minutes.length; i++) {
      double x = i * xStep;
      double y = topPadding + chartHeight - (minutes[i] / maxMin * chartHeight);
      points.add(Offset(x, y));
    }

    Path path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) path.lineTo(points[i].dx, points[i].dy);
    canvas.drawPath(path, linePaint);

    bool isDaily = minutes.length > 12;

    for (int i = 0; i < points.length; i++) {
      bool isLast = i == points.length - 1; 
      
      double radius = isDaily ? (xLabels[i].isNotEmpty ? 4.0 : 2.0) : 5.0;

      if (isLast) {
        canvas.drawCircle(points[i], radius + 1, Paint()..color = const Color(0xFFE57373)..style = PaintingStyle.fill);
      } else {
        canvas.drawCircle(points[i], radius, Paint()..color = Colors.white..style = PaintingStyle.fill);
        canvas.drawCircle(points[i], radius, linePaint);
      }
      
      bool shouldDrawValue = isDaily ? xLabels[i].isNotEmpty : (minutes.length <= 6 || i % 2 == 0 || isLast);
      
      if (shouldDrawValue) {
        int h = minutes[i] ~/ 60;
        int m = minutes[i] % 60;
        String timeStr = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
        
        if (!(isDaily && minutes[i] == 0 && !isLast)) {
          _drawText(canvas, timeStr, points[i].dx, points[i].dy - 25, isLast ? const Color(0xFFE57373) : Colors.black87, isLast, 11);
        }
      }
      
      if (xLabels[i].isNotEmpty) {
        _drawText(canvas, xLabels[i], points[i].dx, size.height - 10, isLast ? const Color(0xFFE57373) : Colors.grey.shade400, isLast, 12);
      }
    }
  }

  void _drawText(Canvas canvas, String text, double x, double y, Color color, bool isBold, double fontSize) {
    TextSpan span = TextSpan(style: TextStyle(color: color, fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w500), text: text);
    TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(x - (tp.width / 2), y - (tp.height / 2)));
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const int dashWidth = 5;
    const int dashSpace = 5;
    double startX = p1.dx;
    while (startX < p2.dx) {
      canvas.drawLine(Offset(startX, p1.dy), Offset(startX + dashWidth, p1.dy), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}