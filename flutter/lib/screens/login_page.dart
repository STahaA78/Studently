import 'package:flutter/material.dart';
import 'signup_basic_page.dart';
import 'community_feed_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studently/utils/constants.dart';

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

  void _login(BuildContext context) {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorNotification();
      return;
    }

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
  }

  void _showErrorNotification() {
    setState(() => _showError = true);
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
                        SvgPicture.asset(
                          'assets/images/logo.svg',
                          height: 50,
                        ),
                        Text(
                          'Studently',
                          style: GoogleFonts.poppins(
                            color: blue,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
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
                            decoration: const InputDecoration(
                              hintText: 'Email',
                            ),
                          ),
                          const SizedBox(height: AppStyle.verticalSpacingNormal),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Password',
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                padding: AppStyle.normalVerticalHorizontalPadding,
                              ),
                              child: Text('Forgot Password?',
                                  style: TextStyle(color: AppStyle.blue)),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _login(context),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: AppStyle.smallFontSize,
                                  color: AppStyle.white,
                                  fontWeight: AppStyle.smallFontWeight,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppStyle.verticalSpacingLarge),
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
                          const SizedBox(height: AppStyle.verticalSpacingLarge),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SignupBasicPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontSize: AppStyle.smallFontSize,
                                  color: AppStyle.blue,
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
                child: const Text(
                  "Please fill in both Email and Password",
                  style: TextStyle(
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
