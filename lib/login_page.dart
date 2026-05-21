import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main_menu_page.dart';
import 'signup_page.dart'; 

class LoginPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const LoginPage({super.key, required this.cameras});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 구글 로그인 
  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) _navigateToMain();
    } catch (error) {
      _showError("구글 로그인 실패: $error");
    }
  }

  //이메일 로그인
  Future<void> _handleEmailLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("이메일과 비밀번호를 입력해주세요.");
      return;
    }
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) _navigateToMain();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showError("등록되지 않은 이메일입니다. 회원가입을 먼저 해주세요.");
      } else if (e.code == 'wrong-password') {
        _showError("비밀번호가 틀렸습니다.");
      } else {
        _showError("로그인 에러: ${e.message}");
      }
    }
  }

  void _navigateToMain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MainMenuPage(cameras: widget.cameras)),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 120),
              const Text(
                "흐트러진 순간을 깨우고,\n매일을 기록하다",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black, height: 1.4),
              ),
              const SizedBox(height: 50),

              _buildTextField("이메일", _emailController, false),
              const SizedBox(height: 15),
              _buildTextField("비밀번호", _passwordController, true),
              const SizedBox(height: 25),

              // 로그인 버튼
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _handleEmailLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text("로그인", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              
              // 회원가입 페이지로 이동하는 버튼
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignUpPage()),
                    );
                  },
                  child: const Text("처음이신가요? 이메일로 가입하기", style: TextStyle(color: Colors.black54, decoration: TextDecoration.underline)),
                ),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("또는", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 20),

              _googleLoginButton(() => _handleGoogleSignIn()),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, bool isPassword) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  Widget _googleLoginButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 55,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/google_login.png", width: 22, errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, size: 30, color: Colors.grey)),
            const SizedBox(width: 12),
            const Text("구글로 계속하기", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}