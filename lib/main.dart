import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'screens/main_shell.dart';
import 'services/api_service.dart';
import 'services/log_service.dart';
import 'services/storage_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait for a more polished feel on phones
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Force dark status bar icons on dark background
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AiAnywhereTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialise services
  final storageService = StorageService();
  await storageService.initialize();

  final logService = LogService(storageService);
  await logService.initialize();

  final apiService = ApiService(logService);

  final appProvider = AppProvider(
    storage: storageService,
    api: apiService,
    log: logService,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: logService),
        ChangeNotifierProvider.value(value: appProvider),
      ],
      child: const AiAnywhereApp(),
    ),
  );
}

class AiAnywhereApp extends StatefulWidget {
  const AiAnywhereApp({super.key});

  @override
  State<AiAnywhereApp> createState() => _AiAnywhereAppState();
}

class _AiAnywhereAppState extends State<AiAnywhereApp> {
  @override
  void initState() {
    super.initState();
    // Delay initialization so the widget tree is built first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Anywhere',
      debugShowCheckedModeBanner: false,
      theme: AiAnywhereTheme.dark,
      home: const MainShell(),
    );
  }
}
