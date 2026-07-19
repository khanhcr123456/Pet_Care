import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pet_care/config/app_config.dart';
import 'package:pet_care/screens/landing_screen.dart';
import 'package:pet_care/screens/admin_dashboard_screen.dart';
import 'package:pet_care/screens/vet_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final userInfoStr = prefs.getString('userInfo');
  Map<String, dynamic>? userInfo;
  
  if (userInfoStr != null) {
    try {
      userInfo = jsonDecode(userInfoStr);
    } catch (e) {
      // Ignored
    }
  }

  runApp(PetCareApp(initialUser: userInfo));
}

class PetCareApp extends StatelessWidget {
  final Map<String, dynamic>? initialUser;
  
  const PetCareApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    Widget homeScreen = const LandingScreen();
    
    if (initialUser != null) {
      final user = initialUser!;
      final role = user['role'];
      if (role == 'admin') {
        homeScreen = AdminDashboardScreen(user: user);
      } else if (role == 'vet') {
        homeScreen = VetDashboardScreen(user: user);
      } else {
        homeScreen = LandingScreen(user: user);
      }
    }

    return MaterialApp(
      title: AppConfig.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFD740))),
      home: homeScreen,
    );
  }
}

