import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for kReleaseMode
import 'package:device_preview/device_preview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/utils/constants.dart';

// Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:email_otp/email_otp.dart';

import 'screens/community_feed_page.dart';
import 'screens/login_page.dart';
import 'package:studently/models/course.dart';

// Import the Auth Provider
import 'package:studently/providers/auth_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
void main() async {
  EmailOTP.config(
    appName: "Studently",
    appEmail: "support@studently.com",
    otpLength: 6,
    otpType: OTPType.numeric,
    emailTheme: EmailTheme.v1,
  );
  
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Hive for Web/Mobile
  await Hive.initFlutter();
  
  // Open the auth box before the app runs
  await Hive.openBox('authBox');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    ProviderScope(
      // Wrap your app with DevicePreview
      child: DevicePreview(
        // Automatically disable DevicePreview when you build a release APK/Web build
        enabled: !kReleaseMode, 
        builder: (context) => const MyApp(),
      ),
    ),
  );
  // runApp(
  //   const ProviderScope(
  //     child: MyApp(),
  //   ),
  // );
} 

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    
    // Watch the auth state
    final authState = ref.watch(authProvider);

    final Color blue = AppStyle.blue;
    final Color white = AppStyle.white;
    final double formFieldRadius = AppStyle.formFieldRadius;
    final double formFieldBorderSize = AppStyle.formFieldBorderSize;
    final EdgeInsets normalVerticalPadding = AppStyle.normalVerticalPadding;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      
      // REQUIRED FOR DEVICE PREVIEW: Injects the preview's locale settings
      locale: DevicePreview.locale(context),

      // Dynamic Routing Magic
      home: authState.when(
        data: (user) {
          if (user != null) return const CommunityFeedPage();
          return const LoginPage();
        },
        // If the provider hits an error (like a wrong password), stay on LoginPage
        error: (err, stack) => const LoginPage(),
        
        // Only show the full-screen loader if we have absolutely no data yet (initial app boot)
        // If we already have 'null' data (meaning we are on the login page), don't show the full screen loader!
        loading: () {
          // Check if we are transitioning FROM the login page
          if (authState.hasValue) {
            return const LoginPage(); // Keep showing the login page so the button spinner works!
          }
          
          // Otherwise, show the boot-up spinner
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: Color(0xFF1976D2))),
          );
        },
      ),

      // MERGED BUILDER: Combines DevicePreview with your custom MediaQuery
      builder: (context, child) {
        // 1. Let DevicePreview build its frame and tools
        final devicePreviewChild = DevicePreview.appBuilder(context, child);
        
        // 2. Apply your global "no bold text" rule to the preview
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            boldText: false,
          ),
          child: devicePreviewChild,
        );
      },
      
      // Global theme settings
      theme: ThemeData(
        primaryColor: blue,
        scaffoldBackgroundColor: white,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black, fontSize: 16),
          bodyMedium: TextStyle(color: Colors.black, fontSize: 16),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          hintStyle: const TextStyle(color: Color(0xFF475569)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(formFieldRadius),
            borderSide: BorderSide(color: const Color(0xFFD1D5DB), width: formFieldBorderSize),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(formFieldRadius),
            borderSide: BorderSide(color: blue, width: formFieldBorderSize),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(formFieldRadius),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(formFieldRadius),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: blue,
            foregroundColor: white,
            elevation: 0,
            padding: normalVerticalPadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(formFieldRadius),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: white,
            foregroundColor: blue,
            side: BorderSide(color: blue, width: formFieldBorderSize),
            padding: normalVerticalPadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(formFieldRadius),
            ),
          ),
        ),
      )
    );
  }
}