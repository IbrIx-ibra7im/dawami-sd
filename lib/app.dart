import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/app_repository.dart';
import 'features/fingerprint/fingerprint_screen.dart';

class DawamiApp extends StatelessWidget {
  const DawamiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();

    return MaterialApp(
      title: 'دوامي - نظام ذكي لإدارة الحضور والإنصراف للطلاب والموظفين والشركات والمؤسسات والمستشفيات',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: repo.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // Full Arabic RTL Locale
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const FingerprintScreen(isInitialScreen: true),
    );
  }
}

