import 'package:flutter/material.dart';
import 'screens/login_page.dart';  // Make sure this path matches your file location

void main() {
  runApp(const MyApp());
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
