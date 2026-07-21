import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/color_palette.dart';
import 'core/theme/theme_controller.dart';

import 'features/crud/viewmodels/home_viewmodel.dart';
import 'features/crud/views/home_page.dart';

import 'features/settings/repositories/settings_repository.dart';
import 'features/settings/viewmodels/settings_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsRepository = SettingsRepository();
  final settings = await settingsRepository.carregar();

  runApp(
    MyStockApp(
      settingsRepository: settingsRepository,
      themeModeInicial: settings.themeMode,
    ),
  );
}

class MyStockApp extends StatelessWidget {
  final SettingsRepository settingsRepository;
  final ThemeMode themeModeInicial;

  const MyStockApp({
    super.key,
    required this.settingsRepository,
    required this.themeModeInicial,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(),
        ),

        ChangeNotifierProvider(
          create: (_) => ThemeController(themeModeInicial),
        ),

        ChangeNotifierProxyProvider<ThemeController, SettingsViewModel>(
          create: (context) => SettingsViewModel(
            repository: settingsRepository,
            themeController: context.read<ThemeController>(),
          ),
          update: (context, themeController, previous) =>
          previous ??
              SettingsViewModel(
                repository: settingsRepository,
                themeController: themeController,
              ),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'myStock',

            themeMode: themeController.themeMode,

            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: kLightPalette.bg,
              fontFamily: 'Roboto',

              colorScheme: ColorScheme.light(
                primary: kLightPalette.primary,
                secondary: kLightPalette.accent,
                surface: kLightPalette.surface,
                error: kLightPalette.danger,
              ),

              dividerColor: kLightPalette.divider,
            ),

            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: kDarkPalette.bg,
              fontFamily: 'Roboto',

              colorScheme: ColorScheme.dark(
                primary: kDarkPalette.primary,
                secondary: kDarkPalette.accent,
                surface: kDarkPalette.surface,
                error: kDarkPalette.danger,
              ),

              dividerColor: kDarkPalette.divider,
            ),

            home: const HomePage(),
          );
        },
      ),
    );
  }
}