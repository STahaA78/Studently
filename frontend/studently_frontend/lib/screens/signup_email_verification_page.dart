import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SignupEmailVerificationPage extends StatefulWidget {
  const SignupEmailVerificationPage({super.key});

  @override
  State<SignupEmailVerificationPage> createState() =>
      _SignupEmailVerificationPageState();
}

class _SignupEmailVerificationPageState
    extends State<SignupEmailVerificationPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final FocusScopeNode _focusScopeNode = FocusScopeNode();

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    _focusScopeNode.dispose();
    super.dispose();
  }

  void _showCircularNotification(String message, {Color color = Colors.blue}) {
    OverlayEntry? entry;

    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 50,
          left: 0,
          right: 0,
          child: CircularSlideNotification(
            message: message,
            background: color,
            onDismissed: () => entry?.remove(),
          ),
        );
      },
    );

    Overlay.of(context).insert(entry);
  }

  void _verifyCode() {
    String code = _controllers.map((e) => e.text).join();
    if (code.length == 6) {
      _showCircularNotification("✅ Verified", color: Colors.green);
    } else {
      _showCircularNotification("❗ Enter all digits", color: Colors.redAccent);
    }
  }

  void _resendCode() {
    _showCircularNotification("📧 Code Resent", color: Colors.blueAccent);
  }

  @override
  Widget build(BuildContext context) {
    final Color blue = const Color(0xFF1976D2);
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final double contentWidth =
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
              children: [
                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "This helps us confirm it's really you and\nkeep our platform spam-free.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  "Enter the 6-digit verification code sent to your email",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),

                // OTP Boxes
                SizedBox(
                  width: contentWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 45,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: index == 0 ? _focusScopeNode : null,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(1),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              FocusScope.of(context).nextFocus();
                            }
                            if (value.isEmpty && index > 0) {
                              FocusScope.of(context).previousFocus();
                            }
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: blue, width: 2),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),

                GestureDetector(
                  onTap: _resendCode,
                  child: Text(
                    'Resend code',
                    style: TextStyle(
                      color: blue,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Verify',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

/// 🔔 Circular notification widget with slide animation
class CircularSlideNotification extends StatefulWidget {
  final String message;
  final Color background;
  final VoidCallback onDismissed;

  const CircularSlideNotification({
    super.key,
    required this.message,
    required this.background,
    required this.onDismissed,
  });

  @override
  State<CircularSlideNotification> createState() =>
      _CircularSlideNotificationState();
}

class _CircularSlideNotificationState extends State<CircularSlideNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 400),
    );
    _slideAnimation =
        Tween(begin: const Offset(0, -1), end: const Offset(0, 0)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 2), () {
      _controller.reverse();
      Future.delayed(const Duration(milliseconds: 400), widget.onDismissed);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: widget.background,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: widget.background.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_none, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
