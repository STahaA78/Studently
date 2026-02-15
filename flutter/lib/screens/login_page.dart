import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for exception handling
import 'signup_basic_page.dart';
import 'community_feed_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studently/utils/constants.dart';
import 'package:studently/auth_service.dart'; // Import your AuthService

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

  /// UPDATED: Now uses authService.value.signIn (Firebase)
  void _login(BuildContext context) async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorNotification("Please fill in both Email and Password");
      return;
    }

    try {
      // 1. Call your central AuthService
      final user = await authService.value.signIn(
        email: email,
        password: password,
      );

      if (user != null) {
        // 2. ✅ Success UI Feedback
        setState(() => _showSuccess = true);
        _successController.forward();

        Future.delayed(const Duration(seconds: 2), () {
          _successController.reverse().then((_) {
            if (mounted) {
              setState(() => _showSuccess = false);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const CommunityFeedPage()),
                (route) => false,
              );
            }
          });
        });
      }
    } on FirebaseAuthException catch (e) {
      // 3. 🔴 Handle specific Firebase errors
      String message = "Login Failed";
      if (e.code == 'user-not-found') {
        message = "No account exists for this email.";
      } else if (e.code == 'wrong-password') {
        message = "Incorrect password.";
      } else if (e.code == 'invalid-email') {
        message = "Badly formatted email.";
      }
      _showErrorNotification(message);
    } catch (e) {
      _showErrorNotification("An unexpected error occurred.");
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
    final double formWidth = isLandscape ? screenSize.width * 0.6 : screenSize.width * 0.85;

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
                    // Logo + Title
                    Padding(
                      padding: const EdgeInsets.only(right: AppStyle.logoSize - AppStyle.titleFontSize),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/images/logo.svg',
                            height: AppStyle.logoSize,
                          ),
                          Text(
                            'Studently',
                            style: GoogleFonts.poppins(
                              color: blue,
                              fontSize: AppStyle.titleFontSize,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),

                    // Login Form
                    SizedBox(
                      width: formWidth,
                      child: Column(
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(hintText: 'Email'),
                          ),
                          const SizedBox(height: AppStyle.verticalSpacingNormal),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(hintText: 'Password'),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // Add forgot password logic here
                              },
                              child: Text('Forgot Password?', style: TextStyle(color: blue)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _login(context),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: AppStyle.smallFontSize,
                                  color: Colors.white,
                                  fontWeight: AppStyle.smallFontWeight,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppStyle.verticalSpacingLarge),
                          const Row(
                            children: [
                              Expanded(child: Divider(thickness: 1)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('OR', style: TextStyle(color: Colors.grey)),
                              ),
                              Expanded(child: Divider(thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: AppStyle.verticalSpacingLarge),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SignupBasicPage()),
                                );
                              },
                              child: Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontSize: AppStyle.smallFontSize,
                                  color: blue,
                                  fontWeight: AppStyle.smallFontWeight,
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

          // Notification Widgets
          if (_showSuccess)
            SlideTransition(
              position: _successOffset,
              child: _buildSuccessNotification(blue),
            ),

          if (_showError)
            SlideTransition(
              position: _errorOffset,
              child: _buildErrorNotification(),
            ),
        ],
      ),
    );
  }

  Widget _buildSuccessNotification(Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, spreadRadius: 2),
        ],
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 40),
    );
  }

  Widget _buildErrorNotification() {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Text(
        _errorText,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }
}