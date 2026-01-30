import 'package:flutter/material.dart';
import 'package:studently/screens/knowledge_hub_page.dart';
import 'package:device_preview/device_preview.dart';
import 'package:studently/utils/constants.dart';
// Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:email_otp/email_otp.dart';
//import 'screens/community_feed_page.dart';
import 'screens/knowledge_hub_page.dart';
//import 'screens/login_page.dart';  // Make sure this path matches your file location

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
    DevicePreview(
      enabled: true, // Set to false to disable Device Preview
      builder: (context) => MyApp(), // Wrap your app
    ),
  );
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
      //home: LoginPage(), // directly show the login page
      //home: CommunityFeedPage(),
      home: KnowledgeHubPage(),
      
      // Global theme settings
      theme : ThemeData(
        // global colors
        primaryColor: blue,
        scaffoldBackgroundColor: white,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        // 2. Global Text Field Style
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          
          // Default Border (when not clicked)
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(formFieldRadius),
            borderSide: BorderSide(color: Colors.grey, width: formFieldBorderSize), // Grey outline
          ),
          
          // Focused Border (when typing)
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(formFieldRadius),
            borderSide: BorderSide(color: blue, width: formFieldBorderSize), // Blue thick outline
          ),
          
          // Error Border (when validation fails)
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(formFieldRadius),
            borderSide: const BorderSide(color: Colors.redAccent),
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
