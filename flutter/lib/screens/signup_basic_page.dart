import 'package:flutter/material.dart';
import 'login_page.dart';
import 'signup_additional_page.dart';
import 'package:studently/models.dart';
import 'package:studently/logger.dart';
class SignupBasicPage extends StatefulWidget {
  const SignupBasicPage({super.key});

  @override
  State<SignupBasicPage> createState() => _SignupBasicPageState();
}

class _SignupBasicPageState extends State<SignupBasicPage> {
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
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Email cannot be empty');
      return false;
    }
    final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address');
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Column(
                  children: [
                    const Text(
                      'Welcome to',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/studently_logo.png',
                          height: 40,
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
                          hintText: 'john.doe@example.com',
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
                          onPressed: () {
                            final name = _nameController.text.trim();
                            final email = _emailController.text.trim().toLowerCase();
                            final pass = _passwordController.text;
                            logger.d("[$runtimeType] Next Button Pressed with Name: $name, Email: $email, Password: $pass");
                            if (_validateInputs(name: name, email: email, pass: pass)) {
                              final user = User(
                                fullName: _nameController.text.trim(),
                                email: _emailController.text.trim().toLowerCase(),
                                password: _passwordController.text.trim(),
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SignupAdditionalPage(user: user),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blue,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
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
                      const SizedBox(height: 20),

                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account? ",
                            style: TextStyle(
                                fontSize: 15, color: Colors.black87),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const LoginPage()),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
