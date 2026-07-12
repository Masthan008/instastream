import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/theme.dart';
import 'presentation/providers/download_provider.dart';
import 'presentation/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
      ],
      child: const InstaStreamApp(),
    ),
  );
}

class InstaStreamApp extends StatelessWidget {
  const InstaStreamApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<DownloadProvider>(context).isDarkMode;
    return MaterialApp(
      title: 'InstaStream Downloader',
      debugShowCheckedModeBanner: false,
      theme: LiquidGlassTheme.lightTheme,
      darkTheme: LiquidGlassTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
