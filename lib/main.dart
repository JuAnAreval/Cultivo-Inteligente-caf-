import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/providers/task_provider.dart';
import 'package:app_flutter_ai/core/services/session_service.dart';
import 'package:app_flutter_ai/core/services/sync_service.dart';
import 'package:app_flutter_ai/screens/ai/dashboard_screen.dart';
import 'package:app_flutter_ai/screens/auth/login_screen.dart';
import 'package:app_flutter_ai/screens/farms/add_farm_screen.dart';
import 'package:app_flutter_ai/screens/farms/farm_list_screen.dart';
import 'package:app_flutter_ai/screens/home/home_screen.dart';
import 'package:app_flutter_ai/screens/lots/add_lot_screen.dart';
import 'package:app_flutter_ai/screens/lots/lot_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await SessionService.init();
  if (SessionService.isAuthenticated) {
    await SyncService.syncAll();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task IA Local',
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
      initialRoute: '/login',
    );
  }
}
