import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'state/app_controller.dart';
import 'ui/screens/login_screen.dart';
import 'ui/shell/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  await controller.initialize();
  runApp(LiveboxMonitorApp(controller: controller));
}

class LiveboxMonitorApp extends StatelessWidget {
  final AppController controller;
  const LiveboxMonitorApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Livebox Monitor',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: controller.themeMode,
          home: controller.isConnected
              ? AppShell(controller: controller)
              : LoginScreen(controller: controller),
        );
      },
    );
  }
}
