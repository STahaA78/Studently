import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'signup_basic_page.dart';
import 'community_feed_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studently/utils/constants.dart';
import 'package:studently/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/providers/auth_provider.dart';
import 'package:studently/models/user.dart'; // Add this line!
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final FocusNode _emailFocusNode = FocusNode();

  bool _emailFieldTouched = false;
  String _emailError = "";
  String _passwordError = "";
  String _loginError = "";

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onEmailFocusChange);
  }
  
  void _onEmailFocusChange() {
    if (!_emailFocusNode.hasFocus) {
      setState(() => _emailFieldTouched = true);
      _forceValidateEmail(_emailController.text);
    }
  }

  @override
  void dispose() {
    _emailFocusNode.removeListener(_onEmailFocusChange);
    _emailFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  void _forceValidateEmail(String email) {
    if (!_emailFieldTouched) return;
    final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    setState(() {
      if (email.isEmpty) {
        _emailError = "Email is required";
      } else if (!emailRegex.hasMatch(email)) {
        _emailError = 'Enter a valid email address';
      } else if (!email.endsWith('@lhr.nu.edu.pk')) {
        _emailError = 'Email must be a valid NUCES Lahore email';
      } else {
        _emailError = "";
      }
    });
  }
  String _getFriendlyErrorMessage(Object error) {
    if (error is firebase_auth.FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return "Invalid email or password.";
        case 'invalid-email':
          return "The email address is badly formatted.";
        case 'user-disabled':
          return "This account has been disabled.";
        case 'too-many-requests':
          return "Too many attempts. Please try again later.";
        case 'network-request-failed':
          return "Network error. Check your internet connection.";
        default:
          return error.message ?? "An unexpected authentication error occurred.";
      }
    }
    // For backend/FastAPI errors, we strip the 'Exception: ' prefix
    return error.toString().replaceAll('Exception: ', '');
  }
  void _login()  {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    // Clear form level error
    setState(() {
      _passwordError = "";
      _loginError = "";
    });

    // Validate email (should already be done by onChanged, but check again)
    _forceValidateEmail(email);
    
    // Validate password
    bool hasError = false;
    if (password.isEmpty) {
      setState(() => _passwordError = "Password is required");
      hasError = true;
    }

    // If field validation failed, return early
    if (_emailError.isNotEmpty || _passwordError.isNotEmpty || hasError) return;

    ref.read(authProvider.notifier).login(email, password);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Watch the provider for changes (loading, data, or error)
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    // 2. Listen specifically for errors to update your UI's _loginError text
    ref.listen<AsyncValue<User?>>(authProvider, (previous, next) {
      // Use .whenOrNull to specifically target the error state
      next.whenOrNull(
        error: (error, stackTrace) {
          setState(() {
            _loginError = _getFriendlyErrorMessage(error);
          });
          // Log the full error for debugging!
          logger.e("Login Error: $error");
        },
      );
    });
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
                          SizedBox(
                            height: 50,
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              focusNode: _emailFocusNode,
                              decoration: const InputDecoration(
                                hintText: 'Email',
                              ),
                              onChanged: (_) {
                                if (_emailError.isNotEmpty) {
                                  setState(() => _emailError = "");
                                }
                              },
                            ),
                          ),
                          if (_emailError.isNotEmpty && _emailFieldTouched)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, left: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _emailError,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: AppStyle.verticalSpacingNormal),
                          SizedBox(
                            height: 50,
                            child: TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: 'Password',
                              ),
                            ),
                          ),
                          if (_passwordError.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, left: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _passwordError,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
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
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 45,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _login,
                              child: isLoading
                                  ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: AppStyle.smallFontSize,
                                        color: Colors.white,
                                        fontWeight: AppStyle.smallFontWeight,
                                      ),
                                    ),
                            ),
                          ),
                          if (_loginError.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, left: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _loginError,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: AppStyle.verticalSpacingSmall),
                          const SizedBox(height: AppStyle.verticalSpacingNormal),
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
                          const SizedBox(height: AppStyle.verticalSpacingNormal),
                          SizedBox(
                            height: 45,
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SignupBasicPage()),
                                ).then((_) {
                                  if (mounted) {
                                    setState(() {
                                      _emailError = "";
                                      _passwordError = "";
                                      _loginError = "";
                                    });
                                  }
                                });
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
        ],
      ),
    );
  }
}