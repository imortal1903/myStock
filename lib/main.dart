import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/color_palette.dart';
import 'core/theme/theme_controller.dart';
import 'core/backup/backup_scheduler.dart';

import 'features/crud/viewmodels/home_viewmodel.dart';
import 'features/crud/views/home_page.dart';

import 'features/config/repositories/config_repository.dart';
import 'features/config/viewmodels/config_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Registra o callback do backup automático em segundo plano junto ao
  // WorkManager. Precisa rodar antes do runApp() — é o que permite o
  // agendamento feito em BackupViewModel.ativar()/definirHorario()
  // funcionar mesmo com o app fechado.
  await BackupScheduler.inicializar();

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // "paused" = o app saiu de primeiro plano (usuário trocou de app,
    // apertou home, ou está fechando de fato). Não dá pra distinguir com
    // certeza uma troca rápida de um fechamento definitivo — por isso só
    // ENFILEIRAMOS a tentativa aqui (BackupScheduler.agendarAoFechar()
    // decide, lendo a config salva, se o backup está ativado; e o próprio
    // WorkManager evita empilhar tentativas repetidas). Nunca fazemos a
    // chamada de rede diretamente neste callback — o processo pode ser
    // suspenso pelo Android antes dela terminar.
    if (state == AppLifecycleState.paused) {
      BackupScheduler.agendarAoFechar();
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