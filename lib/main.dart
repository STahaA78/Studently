import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'package:studently/providers/notifications_provider.dart';
import 'package:studently/services/app_navigation.dart';

// Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'package:studently/services/storage.dart';

// Import the Auth and Config Providers
import 'package:studently/providers/auth_provider.dart';
import 'package:studently/providers/discover_provider.dart';
import 'package:studently/providers/backend_config_provider.dart';
import 'package:studently/providers/feed_provider.dart';
import 'package:studently/providers/chat_provider.dart';
import 'package:studently/providers/knowledge_hub_provider.dart';
import 'screens/community_feed_page.dart';
import 'screens/signup_basic_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize centralized storage (Hive init + box opens + storage wrappers).
  await StorageService().initialize();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authProvider, (previous, next) {
      next.whenData((user) async {
        if (user == null) {
          await ref.read(notificationProvider.notifier).clearForLogout();
          
          // Reset all core providers to clear in-memory cache
          ref.invalidate(discoverConnectProvider);
          ref.invalidate(discoverRequestsProvider);
          ref.invalidate(feedProvider);
          ref.invalidate(chatProvider);
          ref.invalidate(allCoursesProvider);
          ref.invalidate(allResourceGroupsProvider);
          ref.invalidate(backendConfigProvider);
          
          // Reset navigation stack to root on logout and ensure we are on the base route
          if (appNavigatorKey.currentState != null) {
            appNavigatorKey.currentState!.pushNamedAndRemoveUntil('/', (route) => false);
          }
          return;
        }
        await ref.read(notificationProvider.notifier).initializeForCurrentUser();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await ref.read(notificationProvider.notifier).processPendingTapIfAny();
        });
      });
    });

    // Watch the auth state
    final authState = ref.watch(authProvider);

    // Trigger backend config loading on app startup
    ref.watch(backendConfigProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,

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

      // Global theme settings
      theme: AppStyle.theme,
    );
  }
}
