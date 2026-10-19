import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'core/theme/color_palette.dart';
import 'core/theme/theme_controller.dart';
import 'core/backup/backup_scheduler.dart';
import 'core/notificacoes/notificacao_navigation.dart';
import 'core/notificacoes/notificacao_service.dart';

import 'features/crud/viewmodels/home_viewmodel.dart';
import 'features/crud/views/home_page.dart';

import 'features/config/repositories/config_repository.dart';
import 'features/config/viewmodels/config_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: const [
      SystemUiOverlay.top,
    ],
  );

  await BackupScheduler.inicializar();
  await BackupScheduler.sincronizarAoAbrirApp();

  final settingsRepository = ConfigRepository();
  final settings = await settingsRepository.carregar();

  runApp(
    MyStockApp(
      settingsRepository: settingsRepository,
      themeModeInicial: settings.themeMode,
    ),
  );
}

class MyStockApp extends StatefulWidget {
  final ConfigRepository settingsRepository;
  final ThemeMode themeModeInicial;

  const MyStockApp({
    super.key,
    required this.settingsRepository,
    required this.themeModeInicial,
  });

  @override
  State<MyStockApp> createState() => _MyStockAppState();
}

class _MyStockAppState extends State<MyStockApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificacaoService.instance.checkLaunchPayload();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      BackupScheduler.agendarAoFechar();
    }

    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [
          SystemUiOverlay.top,
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(),
        ),

        ChangeNotifierProvider(
          create: (_) => ThemeController(widget.themeModeInicial),
        ),

        ChangeNotifierProxyProvider<ThemeController, ConfigViewModel>(
          create: (context) => ConfigViewModel(
            repository: widget.settingsRepository,
            themeController: context.read<ThemeController>(),
          ),
          update: (context, themeController, previous) =>
          previous ??
              ConfigViewModel(
                repository: widget.settingsRepository,
                themeController: themeController,
              ),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, child) {
          return MaterialApp(
            navigatorKey: NotificacaoNavigation.navigatorKey,
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