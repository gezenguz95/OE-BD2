import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'pages/home_page.dart';
import 'services/app_settings.dart';
import 'services/locale_notifier.dart';
import 'services/theme_notifier.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait<void>([
    AppSettings().init(),
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]),
  ]);

  final db = AppDatabase();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider<ThemeNotifier>(
          create: (_) => ThemeNotifier(AppSettings().themeMode),
        ),
        ChangeNotifierProvider<LocaleNotifier>(
          create: (_) => LocaleNotifier(AppSettings().languageCode),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeNotifier>().mode;
    return MaterialApp(
      title: 'ÓE-BD2',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const HomePage(),
    );
  }
}
