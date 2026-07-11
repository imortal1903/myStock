import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/theme_controller.dart';
import 'features/crud/viewmodels/home_viewmodel.dart';
import 'features/crud/views/home_page.dart';
import 'features/settings/repositories/settings_repository.dart';
import 'features/settings/viewmodels/settings_viewmodel.dart';

main(){
  runApp(const MyStockApp());
}

class MyStockApp extends StatelessWidget {
  const MyStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProxyProvider<ThemeController, SettingsViewModel>(
          create: (ctx) => SettingsViewModel(
            repository: SettingsRepository(),
            themeController: ctx.read<ThemeController>(),
          ),
          update: (ctx, themeController, previous) =>
          previous ??
              SettingsViewModel(
                repository: SettingsRepository(),
                themeController: themeController,
              ),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: 'myStock',
            debugShowCheckedModeBanner: false,
            themeMode: themeController.themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              fontFamily: 'Roboto',
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF6B3FA0),
                secondary: Color(0xFFFFB830),
                surface: Colors.white,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF1A1A2E),
              fontFamily: 'Roboto',
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF6B3FA0),
                secondary: Color(0xFFFFB830),
                surface: Color(0xFF252540),
              ),
            ),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}