import 'package:flutter/material.dart';
import 'signup_basic_page.dart'; // <-- import the signup page here

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color blue = const Color(0xFF1976D2);
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final double formWidth = isLandscape ? screenSize.width * 0.6 : screenSize.width * 0.85;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                      height: 80, // enlarged logo
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
                      // Email
                      TextField(
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextField(
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),

                      // Forgot Password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: Text('Forgot Password?', style: TextStyle(color: blue)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // Add login logic or navigation here
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
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

                      // OR Divider
                      Row(
                        children: [
                          const Expanded(child: Divider(thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'OR',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                          const Expanded(child: Divider(thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Sign Up Button (navigates to SignupBasicPage)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupBasicPage(),
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
    );
  }
}
