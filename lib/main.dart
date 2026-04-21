import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/providers/task_provider.dart';
import 'package:app_flutter_ai/core/services/auth/auth_service.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:app_flutter_ai/screens/ai/dashboard_screen.dart';
import 'package:app_flutter_ai/screens/auth/login_screen.dart';
import 'package:app_flutter_ai/screens/fincas/add_farm_screen.dart';
import 'package:app_flutter_ai/screens/fincas/farm_list_screen.dart';
import 'package:app_flutter_ai/screens/home/home_screen.dart';
import 'package:app_flutter_ai/screens/lotes/add_lot_screen.dart';
import 'package:app_flutter_ai/screens/lotes/lot_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await SessionService.init();
  await AuthService.restoreSessionOnLaunch();
  final hasSession = SessionService.canRestoreSession;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: MyApp(hasSession: hasSession),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.hasSession,
  });

  final bool hasSession;

  @override
  Widget build(BuildContext context) {
    return _AppLifecycleGate(
      child: MaterialApp(
        title: 'Cultiva Tec',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.clayStrong,
            brightness: Brightness.light,
          ),
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: AppColors.textPrimary,
                displayColor: AppColors.textPrimary,
              ),
        ),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/home': (_) => const HomeScreen(),
          '/dashboard': (_) => const DashboardScreen(),
          '/add-farm': (_) => const AddFarmScreen(),
          '/farms': (_) => const FarmListScreen(),
          '/lots': (_) => const LotListScreen(
                farmId: '',
                farmName: '',
              ),
          '/add-lot': (_) => const AddLotScreen(
                farmId: '',
                farmName: '',
              ),
        },
        initialRoute: hasSession ? '/home' : '/login',
      ),
    );
  }
}

class _AppLifecycleGate extends StatefulWidget {
  const _AppLifecycleGate({
    required this.child,
  });

  final Widget child;

  @override
  State<_AppLifecycleGate> createState() => _AppLifecycleGateState();
}

class _AppLifecycleGateState extends State<_AppLifecycleGate>
    with WidgetsBindingObserver {
  bool _isRefreshing = false;

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
    if (state == AppLifecycleState.resumed) {
      _refreshSessionIfNeeded();
    }
  }

  Future<void> _refreshSessionIfNeeded() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;
    try {
      await SessionService.init();
      await AuthService.restoreSessionOnLaunch();
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
