import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/utils/constants.dart';
// Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:email_otp/email_otp.dart';
import 'screens/community_feed_page.dart';
//import 'screens/knowledge_hub_page.dart';

import 'screens/login_page.dart';  // Make sure this path matches your file location
import 'package:studently/models/course.dart';

void main() async {
    EmailOTP.config(
      appName: "Studently",
      appEmail: "support@studently.com",
      otpLength: 6,
      otpType: OTPType.numeric,
      emailTheme: EmailTheme.v1,
    );
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(
      ProviderScope(
        child: DevicePreview(
          enabled: true , // Set to false to disable Device Preview
          builder: (context) => const MyApp(), // Wrap your app
        ),
      ),
    );
    // runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    final Color blue = AppStyle.blue;
    final Color white = AppStyle.white;
    final double formFieldRadius = AppStyle.formFieldRadius;
    final double formFieldBorderSize = AppStyle.formFieldBorderSize;
    final EdgeInsets normalVerticalPadding = AppStyle.normalVerticalPadding;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(), // directly show the login page
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            boldText: false,
          ),
          child: child!,
        );
      },
      //home: CommunityFeedPage(),
      // home: AddResourcePage(
      //   course: Course(
      //     name: "Artificial Intelligence",
      //     code: "AI2002"
      //   )
      // ),
      
      // Global theme settings
      theme : ThemeData(
        // global colors
        primaryColor: blue,
        scaffoldBackgroundColor: white,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        // 2. Global Text Field Style
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black, fontSize: 16), // Desktop/Web default
          bodyMedium: TextStyle(color: Colors.black, fontSize: 16), // Mobile default
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          //hint text color
          hintStyle: TextStyle(color: const Color(0xFF475569)), // neutral 600
          // Default Border (when not clicked)
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(formFieldRadius),
            // neutral 300
            borderSide: BorderSide(color: const Color(0xFFD1D5DB), width: formFieldBorderSize), // Grey outline
          ),
          
          // Focused Border (when typing)
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(formFieldRadius),
            borderSide: BorderSide(color: blue, width: formFieldBorderSize), // Blue thick outline
          ),
          
          // Error Border (when validation fails)
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(formFieldRadius),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          
          // Focused Error Border
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(formFieldRadius),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
        ),
        // 3. Global Elevated Button Style
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: blue,
            foregroundColor: white, // Text color
            elevation: 0,
            padding: normalVerticalPadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(formFieldRadius),
            ),
          ),
        ),
        // 2. SECONDARY BUTTONS (White Background, Blue Text, Blue Border)
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: white,
            foregroundColor: blue, // Text Color
            side: BorderSide(color: blue, width: formFieldBorderSize),
            padding: normalVerticalPadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(formFieldRadius)
            ),
          ),
        ),
      )
    );
  }
}
