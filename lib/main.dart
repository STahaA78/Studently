import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';

// Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:email_otp/email_otp.dart';
import 'screens/login_page.dart';
// Hive imports
import 'package:studently/services/storage.dart';

// Import the Auth and Config Providers
import 'package:studently/providers/auth_provider.dart';
import 'package:studently/providers/backend_config_provider.dart';
import 'screens/community_feed_page.dart';
import 'screens/signup_basic_page.dart';

void main() async {
  EmailOTP.config(
    appName: "Studently",
    appEmail: "support@studently.com",
    otpLength: 6,
    otpType: OTPType.numeric,
    emailTheme: EmailTheme.v1,
  );
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Storage Service (handles config storage and Hive boxes at app startup)
  final storageService = StorageService();
  await storageService.initialize();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the auth state
    final authState = ref.watch(authProvider);

    // Trigger backend config loading on app startup
    ref.watch(backendConfigProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // REQUIRED FOR DEVICE PREVIEW: Injects the preview's locale settings
      locale: DevicePreview.locale(context),

      // Dynamic Routing Magic
      home: authState.when(
        data: (user) {
          if (user != null) return const CommunityFeedPage();

          // Check if Firebase user is logged in but not yet registered in backend
          // (This means new Google signup user)
          final firebaseUser = FirebaseAuth.instance.currentUser;
          if (firebaseUser != null && user == null) {
            return const SignupBasicPage();
          }

          return const LoginGooglePage();
        },
        // If the provider hits an error (like a wrong password or cancelled Google signin), stay on LoginPage
        error: (err, stack) {
          return const LoginGooglePage();
        },

        // Only show the full-screen loader if we have absolutely no data yet (initial app boot)
        // If we already have 'null' data (meaning we are on the login page), don't show the full screen loader!
        loading: () {
          // Check if we are transitioning FROM the login page
          if (authState.hasValue) {
            return const LoginGooglePage(); // Keep showing the login page so the button spinner works!
          }

          // Otherwise, show the boot-up spinner
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: AppStyle.primaryBlue),
            ),
          );
        },
      ),

      // MERGED BUILDER: Combines DevicePreview with your custom MediaQuery
      builder: (context, child) {
        // 1. Let DevicePreview build its frame and tools
        final devicePreviewChild = DevicePreview.appBuilder(context, child);

        // 2. Apply your global "no bold text" rule to the preview
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(boldText: false),
          child: devicePreviewChild,
        );
      },

      // Global theme settings
      theme: AppStyle.theme,
    );
  }
}
