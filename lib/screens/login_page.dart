import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studently/app_style.dart';
import 'package:studently/logger.dart';
import 'package:studently/providers/auth_provider.dart';
import 'package:studently/models/user.dart';

class LoginGooglePage extends ConsumerStatefulWidget {
  const LoginGooglePage({super.key});

  @override
  ConsumerState<LoginGooglePage> createState() => _LoginGooglePageState();
}

class _LoginGooglePageState extends ConsumerState<LoginGooglePage> {
  String _googleSignInError = "";

  @override
  void initState() {
    super.initState();
    _googleSignInError = "";
  }

  void _handleGoogleSignIn() {
    logger.i("[$runtimeType] Google Sign-In Button Pressed");
    ref.read(authProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final double formWidth = isLandscape
        ? screenSize.width * 0.6
        : screenSize.width * 0.85;

    // Watch the provider for changes (loading, data, or error)
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    // Listen for errors
    ref.listen<AsyncValue<User?>>(authProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          setState(() {
            _googleSignInError = _getFriendlyErrorMessage(error);
          });
          logger.e("Google Sign-In Error: $error");
        },
      );
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo + Title
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/images/logo.svg',
                        height: AppStyle.logoSize,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Studently',
                        style: GoogleFonts.poppins(
                          color: AppStyle.primaryBlue,
                          fontSize: AppStyle.titleFontSize,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content
                SizedBox(
                  width: formWidth,
                  child: Column(
                    children: [
                      // Info Block
                      Text(
                        'Hi there! Login with Google to continue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Google Sign-In Button - Official Google Colors
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isLoading ? null : _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFFDADCE0),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF4285F4),
                                        ),
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/images/google_icon.svg',
                                      height: 20,
                                      width: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Sign in with Google',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        color: const Color(0xFF3C4043),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      // Error Message
                      if (_googleSignInError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            child: Text(
                              _googleSignInError,
                              style: TextStyle(
                                color: Colors.red[800],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
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

  String _getFriendlyErrorMessage(Object error) {
    return error.toString().replaceAll('Exception: ', '');
  }
}
