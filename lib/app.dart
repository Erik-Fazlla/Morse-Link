import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/send/presentation/screens/home_screen.dart';

class MorseApp extends StatelessWidget {
  const MorseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
