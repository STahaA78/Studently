import 'package:flutter/material.dart';
import 'package:email_otp/email_otp.dart';
import 'package:studently/logger.dart';
import 'package:studently/models/user.dart';
import 'package:pinput/pinput.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/screens/signup_additional_page.dart';
import 'package:studently/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupEmailVerificationPage extends StatefulWidget {
  final User user;
  const SignupEmailVerificationPage({super.key, required this.user});
  @override
  State<SignupEmailVerificationPage> createState() => _SignupEmailVerificationPageState();
}

class _SignupEmailVerificationPageState extends State<SignupEmailVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  
  String? _completionError;
  //Timer code
  Timer? _resendTimer;
  int _secondsRemaining = 0;
  bool get _canResend => _secondsRemaining == 0;

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

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _handleCompletion() async {
    final code = _otpController.text.trim();
    logger.i('OTP Verification Started for email: ${widget.user.email}.');
    logger.d('Entered code: $code');
    // 1. Check Length
    if (code.length != 6) {
      setState(() {
        _completionError = 'Enter all 6 digits';
      });
      logger.w('OTP Verification Failed: Entered code length is not 6 digits.');
      return;
    }

    // 2. Check Validity
    //final isValid = EmailOTP.verifyOTP(otp: code);
    // testing workaround
    bool isValid;
    if (code == "123456") {
      isValid = true;
    } else {
      isValid = false;
    }
    if (!isValid) {
      setState(() {
        _completionError = 'Invalid code. Please try again.';
      });
      logger.w('OTP Verification Failed: Invalid code entered for email: ${widget.user.email}.');
      // Clear the field so they can type again easily
      return;
    }
    else{
      logger.i('OTP Verification Succeeded for email: ${widget.user.email}.');
      // Proceed to the next signup step
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProviderScope(
            child: SignupAdditionalPage(user: widget.user),
          ),
        ),
      );
    }
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

      // Improved PIN theme - moved here for hot reload to work
      final defaultPinTheme = PinTheme(
        width: 56,
        height: 64,
        textStyle: const TextStyle(
          fontSize: 24,
          color: Colors.black,
          fontWeight: FontWeight.w700,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        ),
      );

      // Define the style for the FOCUSED box (Blue border)
      final focusedPinTheme = defaultPinTheme.copyDecorationWith(
            border: Border.all(color: blue, width: 2.5),
            borderRadius: BorderRadius.circular(14),
      );
      // Style for the boxes when there is an error
      final errorPinTheme = defaultPinTheme.copyDecorationWith(
            border: Border.all(color: Colors.redAccent, width: 2),
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
      );
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: AppStyle.backButtonLeftPadding, bottom: AppStyle.backButtonBottomPadding),
                      child: IconButton(
                        padding: EdgeInsets.zero, // removes extra padding
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF323743), // your fill color
                          size: 30,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: AppStyle.signUpPageTitleLeftPadding, right: 40),
                  child:
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Email Verification',
                      style: GoogleFonts.poppins(
                        fontSize: AppStyle.signUpPageHeadingFontSize,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Email Icon (centered)
                Icon(
                  Icons.mail_outline,
                  size: 64,
                  color: blue,
                ),
                const SizedBox(height: 16),
                // Instruction Text (centered)
                Text.rich(
                  TextSpan(
                    text: "Enter the 6 digit code sent to \n",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    children: [
                      TextSpan(
                        text: widget.user.email,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: ".\nPlease check your spam folder if you don't see it.",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppStyle.verticalSpacingSmall),
                // ==================== OTP Input Field ====================
                SizedBox(
                  width: contentWidth,
                  child: Pinput(
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
                  showCursor: false,
                  
                  // THE KEY LOGIC:
                  forceErrorState: _completionError != null, // Turn boxes red if error exists
                  errorText: _completionError,               // Show this text below boxes
                  
                  onCompleted: (pin) => _handleCompletion(),
                  
                  onChanged: (value) {
                    // UX Improvement: Clear the error immediately when they start typing
                    if (_completionError != null) {
                      setState(() => _completionError = null);
                    }
                  },
                ),
                ),
                // ===================================================

                const SizedBox(height: AppStyle.verticalSpacingSmall),
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
                const SizedBox(height: AppStyle.verticalSpacingSmall),
                SizedBox(
                  height: 45,
                  width: contentWidth,
                  child: ElevatedButton(
                    onPressed: _handleCompletion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                    ),
                    child: const Text('Verify', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
