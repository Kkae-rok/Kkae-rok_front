import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'timer_add_page.dart';

class TimerEditListPage extends StatefulWidget {
  const TimerEditListPage({super.key});

  @override
  State<TimerEditListPage> createState() => _TimerEditListPageState();
}

class _TimerEditListPageState extends State<TimerEditListPage> {
 
  final User? currentUser = FirebaseAuth.instance.currentUser;

  
  void _deleteTimer(String docId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("삭제 확인"),
        content: Text("'$title' 타이머를 삭제할까요?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
          TextButton(
            onPressed: () async {
              // 파이어베이스에서 해당 문서 삭제!
              await FirebaseFirestore.instance.collection('timers').doc(docId).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editTimerName(String docId, String currentTitle) {
    TextEditingController controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("타이머 이름 수정"),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "과목 이름")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
              
                await FirebaseFirestore.instance.collection('timers').doc(docId).update({
                  'title': controller.text,
                });
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text("수정"),
          ),
        ],
      ),
    );
  }

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
        title: const Text("타이머 추가 / 편집", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildCalendarHeader(),
          const SizedBox(height: 20),
        
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('timers')
                  .where('uid', isEqualTo: currentUser?.uid) // 로그인한 내 데이터만 가져오기!
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("오른쪽 아래 + 버튼을 눌러 과목을 추가해보세요!", style: TextStyle(color: Colors.grey)));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    
                    String docId = doc.id; // DB 문서 고유 ID
                    String title = data['title'] ?? '이름 없음';
                    Color color = Color(data['color'] ?? Colors.grey.value); // 정수형 숫자를 다시 Color로 변환

                    return _buildEditItem(docId, title, color);
                  },
                );
              },
            ),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE57373),
        onPressed: () async {
          final result = await showModalBottomSheet<Map<String, dynamic>>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const TimerAddPage(),
          );

          
          if (result != null && currentUser != null) {
            Color selectedColor = result['color'];
            
            
            await FirebaseFirestore.instance.collection('timers').add({
              'uid': currentUser!.uid,           // 내 번호
              'title': result['title'],          // 과목 
              'color': selectedColor.value,      // 색상 
              'seconds': 0,                      // 누적시간
              'createdAt': FieldValue.serverTimestamp(), // 생성 시간
            });
          }
        },
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
    );
  }

  Widget _buildCalendarHeader() {
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
                  Text(weekdays[index], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    '${date.day}',
                    style: TextStyle(color: isToday ? const Color(0xFFE57373) : Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
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

 
  Widget _buildEditItem(String docId, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.play_arrow, color: color, size: 28), // 저장한 색상 반영
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _editTimerName(docId, title),
                child: const Text("수정", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: Text("|", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              GestureDetector(
                onTap: () => _deleteTimer(docId, title),
                child: const Text("삭제", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}