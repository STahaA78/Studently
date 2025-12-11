import 'package:flutter/material.dart';
import 'login_page.dart';
import 'signup_email_verification_page.dart';
import 'package:email_otp/email_otp.dart';
import 'package:studently/models.dart';
import 'package:studently/logger.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:studently/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupBasicPage extends StatefulWidget {
  const SignupBasicPage({super.key});

  @override
  State<SignupBasicPage> createState() => _SignupBasicPageState();
}

class _SignupBasicPageState extends State<SignupBasicPage> {
    Future<void> _handleCompletion() async {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final pass = _passwordController.text;
      logger.d("[$runtimeType] Next Button Pressed with Name: $name, Email: $email, Password: $pass");
      if (_validateInputs(name: name, email: email, pass: pass)) {
        final user = User(
          name: name,
          email: email,
          password: pass,
          birthday: null, // Birthday will be filled in next page
        );
        setState(() { _completionError = null; });
        bool otpSent = await _sendOtp(email: email);
        if (!otpSent || !mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SignupEmailVerificationPage(user: user),
          ),
        );
      }
    }
    String? _completionError;
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Focus nodes for validation on focus change
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  String? _nameError;
  String? _emailError;
  String? _passwordError;

  Future<bool> _sendOtp({required String email}) async {
    logger.i("[$runtimeType] SendOTP Started");
    logger.d("[$runtimeType] Email: $email");
    try {
      final sent = await EmailOTP.sendOTP(email: email);
      if (sent) {
        logger.i("[$runtimeType] OTP sent successfully to $email");
        return true;
      } else {
        logger.w("[$runtimeType] OTP sending failed to $email");
        return true;
        // setState(() {
        //   _completionError = 'Error sending OTP. Please try again.';
        // });
        //return false;
      }
    } catch (e) {
      logger.e("[$runtimeType] Failed to send OTP to $email", error: e);
      setState(() {
        _completionError = 'Error sending OTP. Please try again.';
      });
      return false;
    }
  }
  // Validation function
  bool _validateInputs({required String name, required String email, required String pass}) {
    logger.i("[$runtimeType] Validating Inputs Started");
    logger.d("[$runtimeType] Name: $name, Email: $email, Password: $pass");
    final validName = _validateName();
    final validEmail = _validateEmail();
    final validPass = _validatePassword();
    final ok = validName && validEmail && validPass;
    if (ok) logger.i("[$runtimeType] Validating Inputs Successful");
    return ok;
  }

  bool _validateName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Full name cannot be empty');
      return false;
    }
    if (_nameError != null) setState(() => _nameError = null);
    return true;
  }

  bool _validateEmail() {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _emailError = 'Email cannot be empty');
      return false;
    }
    final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      return false;
    }
    if (!email.endsWith("@lhr.nu.edu.pk")) {
      setState(() => _emailError = 'Email must be a valid NUCES Lahore email');
      return false;
    }
    if (_emailError != null) setState(() => _emailError = null);
    return true;
  }

  bool _validatePassword() {
    final pass = _passwordController.text;
    if (pass.isEmpty) {
      setState(() => _passwordError = 'Password cannot be empty');
      return false;
    }
    if (pass.length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 characters');
      return false;
    }
    if (_passwordError != null) setState(() => _passwordError = null);
    return true;
  }

  @override
  void dispose() {
    logger.i("[Signup Basic] Disposing Controllers Started");
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
    logger.i("[Signup Basic] Disposing Controllers Ended");
  }

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _validateEmail();
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) _validatePassword();
    });
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _validateName();
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

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              Column(
                children: [
                  // Back Button Row (left aligned)
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
                    Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Welcome to',
                            style: GoogleFonts.poppins(
                              fontSize: AppStyle.signUpPageHeadingFontSize,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
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
                      ]
                    ),
                  ),
                ],
              ),
        
              const SizedBox(height: 15),
        
              // Subtitle
              Text(
                "Let's get you started. Please fill in your\nbasic information below.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
        
              // FORM
              SizedBox(
                width: formWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name
                    const Text(
                      'Full Name',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      decoration: InputDecoration(
                        hintText: 'John Doe',
                        errorText: _nameError,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      onChanged: (_) {
                        if (_nameError != null) setState(() => _nameError = null);
                      },
                    ),
                    const SizedBox(height: 16),
        
                    // Email
                    const Text(
                      'Email',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'john.doe@lhr.nu.edu.pk',
                        errorText: _emailError,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      onChanged: (_) {
                        if (_emailError != null) setState(() => _emailError = null);
                      },
                      onEditingComplete: () => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 16),
        
                    // Password
                    const Text(
                      'Password',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        errorText: _passwordError,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      onChanged: (_) {
                        if (_passwordError != null) setState(() => _passwordError = null);
                      },
                      onEditingComplete: () => FocusScope.of(context).unfocus(),
                    ),
                    const SizedBox(height: 30),
        
                    // NEXT BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _handleCompletion();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (_completionError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _completionError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 20),
        
                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                            );
                          },
                          child: Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 15,
                              color: blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
