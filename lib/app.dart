import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'theme/app_theme.dart';

class MLBAnalyticsApp extends StatelessWidget {
  const MLBAnalyticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MLB Analytics',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}