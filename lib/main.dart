import 'package:flutter/material.dart';
import 'package:pet_care/config/app_config.dart';
import 'package:pet_care/screens/landing_screen.dart';

void main() {
  runApp(const PetCareApp());
}

class PetCareApp extends StatelessWidget {
  const PetCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFD740))),
      home: const LandingScreen(),
    );
  }
}
