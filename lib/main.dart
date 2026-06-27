import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'services/mongo_service.dart';
import 'services/storage_service.dart';
import 'widgets/uri_dialog.dart';

void main() {
  runApp(const GhostLightApp());
}

class GhostLightApp extends StatelessWidget {
  const GhostLightApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GhostLight Portal Editor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5C6BC0),
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5C6BC0),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const _AppInit(),
      );
}

class _AppInit extends StatefulWidget {
  const _AppInit();

  @override
  State<_AppInit> createState() => _AppInitState();
}

class _AppInitState extends State<_AppInit> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Defer until after the first frame so showDialog has a valid context.
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final storedUri = await StorageService.getMongoUri();
    if (storedUri != null) {
      final (ok, _) = await MongoService.testConnection(storedUri);
      if (ok) {
        await MongoService.connect(storedUri);
        if (mounted) setState(() => _ready = true);
        return;
      }
    }
    // No valid stored URI — prompt until we get a working one.
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UriDialog(),
    );
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const MainScreen();
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
