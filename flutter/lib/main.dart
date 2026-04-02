import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/utils/constants.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:email_otp/email_otp.dart';

import 'screens/main_screen.dart';
import 'screens/login_page.dart';
import 'models/post.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive
  await Hive.initFlutter();
  // Register Adapters
  Hive.registerAdapter(CommentAdapter());
  Hive.registerAdapter(PostAdapter());

  EmailOTP.config(
    appName: "Studently",
    appEmail: "support@studently.com",
    otpLength: 6,
    otpType: OTPType.numeric,
    emailTheme: EmailTheme.v1,
  );
  
  runApp(
    ProviderScope(
      child: DevicePreview(
        enabled: !kReleaseMode, 
        builder: (context) => const MyApp(),
      ),
    ),
  );
} 

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFF1976D2),
      ),
      home: authState.when(
        data: (user) {
          if (user != null) return const MainScreen();
          return const LoginPage();
        },
        error: (err, stack) => const LoginPage(),
        loading: () {
          if (authState.hasValue) {
            return const LoginPage();
          }
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: Color(0xFF1976D2))),
          );
        },
      ),
      builder: DevicePreview.appBuilder,
    );
  }
}
