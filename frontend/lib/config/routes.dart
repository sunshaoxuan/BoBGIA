import 'package:flutter/material.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/map_screen.dart';
import '../ui/screens/settings_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String map = '/map';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      home: (context) => const HomeScreen(),
      map: (context) => const MapScreen(),
      settings: (context) => const SettingsScreen(),
    };
  }
} 