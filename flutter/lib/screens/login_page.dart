import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'signup_basic_page.dart';
import 'community_feed_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late AnimationController _successController;
  late AnimationController _errorController;
  late Animation<Offset> _successOffset;
  late Animation<Offset> _errorOffset;

  bool _showSuccess = false;
  bool _showError = false;
  String _errorText = "Please fill in both Email and Password";

  @override
  void initState() {
    super.initState();

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _successOffset = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: const Offset(0, 0.1),
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.easeOutBack,
    ));

    _errorOffset = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: const Offset(0, 0.1),
    ).animate(CurvedAnimation(
      parent: _errorController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _successController.dispose();
    _errorController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login(BuildContext context) async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorNotification("Please fill in both Email and Password");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/users/login"), 
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      if (data["success"] == true) {
        // ✅ Success Notification
        setState(() => _showSuccess = true);
        _successController.forward();

        Future.delayed(const Duration(seconds: 2), () {
          _successController.reverse().then((_) {
            setState(() => _showSuccess = false);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const CommunityFeedPage()),
              (route) => false,
            );
          });
        });
      } else {
        // 🔴 Error Notification
        _showErrorNotification(data["detail"] ?? "Invalid email or password");
      }
    } catch (e) {
      _showErrorNotification("Server error. Please try again.");
    }
  }

  void _showErrorNotification(String message) {
    setState(() {
      _errorText = message;
      _showError = true;
    });

    _errorController.forward();

    Future.delayed(const Duration(seconds: 2), () {
      _errorController.reverse().then((_) {
        if (mounted) setState(() => _showError = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color blue = const Color(0xFF1976D2);
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final double formWidth =
        isLandscape ? screenSize.width * 0.6 : screenSize.width * 0.85;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ===== Logo + Title =====
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/studently_logo.png',
                          height: 80,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Studently',
                          style: TextStyle(
                            color: blue,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),

                    // ===== Login Form =====
                    SizedBox(
                      width: formWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'Email',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: Text('Forgot Password?',
                                  style: TextStyle(color: blue)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _login(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blue,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              const Expanded(child: Divider(thickness: 1)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('OR',
                                    style: TextStyle(color: Colors.grey[700])),
                              ),
                              const Expanded(child: Divider(thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                      SignupBasicPage(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: blue, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ✅ SUCCESS NOTIFICATION
          if (_showSuccess)
            SlideTransition(
              position: _successOffset,
              child: Container(
                margin: const EdgeInsets.only(top: 60),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: blue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: blue.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
            ),

          // 🔴 ERROR NOTIFICATION
          if (_showError)
            SlideTransition(
              position: _errorOffset,
              child: Container(
                margin: const EdgeInsets.only(top: 60),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  _errorText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
