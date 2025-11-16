import 'package:flutter/material.dart';
import 'screens/login_page.dart';  // Make sure this path matches your file location
import 'package:device_preview/device_preview.dart';

void main() {
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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(), // directly show the login page
    );
  }
}
