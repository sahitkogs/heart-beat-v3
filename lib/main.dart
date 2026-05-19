import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: HeartbeatV3App()));
}

class HeartbeatV3App extends StatelessWidget {
  const HeartbeatV3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heartbeat v3',
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
