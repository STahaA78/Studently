import 'package:flutter/material.dart';
import 'community_feed_page.dart';
import 'package:email_otp/email_otp.dart';
import 'package:studently/auth_service.dart';
import 'package:studently/logger.dart';
import 'package:studently/models.dart';
import 'package:pinput/pinput.dart';
import 'dart:async';

class SignupEmailVerificationPage extends StatefulWidget {
  final User user;
  const SignupEmailVerificationPage({super.key, required this.user});

  @override
  State<SignupEmailVerificationPage> createState() => _SignupEmailVerificationPageState();
}

class _SignupEmailVerificationPageState extends State<SignupEmailVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  
  String? _otpError;
  //Timer code
  Timer? _resendTimer;
  int _secondsRemaining = 0;
  bool get _canResend => _secondsRemaining == 0;

  final defaultPinTheme = PinTheme(
    width: 45,
    height: 55,
    textStyle: const TextStyle(fontSize: 22, color: Colors.black, fontWeight: FontWeight.bold),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
    ),
  );

  // Timer Helper
  void _startResendTimer() {
    setState(() { 
      _secondsRemaining = 30; // 30 seconds cooldown
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        _resendTimer?.cancel();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }
  //Signup Logic
  Future<void> register() async {
    logger.i("[$runtimeType] Firebase Registration Started");
    try {
      await authService.value.createAccount(
        email: widget.user.email, password: widget.user.password,
      );
      logger.i("[$runtimeType] Firebase Registration Successful");
    } catch (e) {
      logger.e("[$runtimeType] Firebase Registration Failed" , error: e);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    
    // 1. Check Length
    if (code.length != 6) {
      setState(() {
        _otpError = 'Enter all 6 digits';
      });
      return;
    }

    // 2. Check Validity
    final isValid = EmailOTP.verifyOTP(otp: code);
    if (!isValid) {
      setState(() {
        _otpError = 'Invalid code. Please try again.';
      });
      // Clear the field so they can type again easily
      return;
    }

    // 3. Success
    setState(() {
      _otpError = null; // Clear any previous errors
    });

    await register();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const CommunityFeedPage()),
      (route) => false,
    );
  }

  void _resendCode() {
    // 1. Send the email again
    EmailOTP.sendOTP(email: widget.user.email); 

    // 2. Start the visual countdown
    _startResendTimer();
  }

  @override
    Widget build(BuildContext context) {
      final Color blue = const Color(0xFF1976D2);
      final Size screenSize = MediaQuery.of(context).size;
      final double contentWidth = screenSize.width * 0.85;

      // Define the style for the FOCUSED box (Blue border)
      final focusedPinTheme = defaultPinTheme.copyDecorationWith(
            border: Border.all(color: blue, width: 2),
            borderRadius: BorderRadius.circular(12),
      );
      // Style for the boxes when there is an error
      final errorPinTheme = defaultPinTheme.copyDecorationWith(
            border: Border.all(color: Colors.redAccent, width: 2),
            color: Colors.red.shade50, // This sets the light red background
            borderRadius: BorderRadius.circular(12),
      );
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Text('Verify Your Email', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(
                    "A verification code has been sent to ${widget.user.email}.\nThis step ensures the Integrity of the Studently Community.\n",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 40),
                  // ==================== OTP Input Field ====================
                  Pinput(
                    length: 6,
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    
                    // Styles
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    errorPinTheme: errorPinTheme, // Uses the red style defined above
                    
                    // Text Style for the error message below the box
                    errorTextStyle: const TextStyle(
                      color: Colors.redAccent, 
                      fontSize: 14, 
                      fontWeight: FontWeight.w500
                    ),

                    // Behavior
                    pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                    showCursor: true,
                    
                    // THE KEY LOGIC:
                    forceErrorState: _otpError != null, // Turn boxes red if error exists
                    errorText: _otpError,               // Show this text below boxes
                    
                    onCompleted: (pin) => _verifyCode(),
                    
                    onChanged: (value) {
                      // UX Improvement: Clear the error immediately when they start typing
                      if (_otpError != null) {
                        setState(() => _otpError = null);
                      }
                    },
                  ),
                  // ===================================================

                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _canResend ? _resendCode : null,
                    child: Text(
                      _canResend ? 'Resend Code' : 'Resend code in $_secondsRemaining seconds',
                      style: TextStyle(
                        color: _canResend ? blue : Colors.grey,
                        fontSize: 15,
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: contentWidth,
                    child: ElevatedButton(
                      onPressed: _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      child: const Text('Verify', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
