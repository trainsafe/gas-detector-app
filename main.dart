import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'ui/instructor/instructor_login_screen.dart';
import 'ui/instructor/instructor_dashboard_screen.dart';
import 'ui/trainee/trainee_login_screen.dart';
import 'ui/trainee/trainee_simulator_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
  WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
      runApp(const MyApp());
  } catch (e) {
    print('Firebase initialization failed: \$e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gas Detector Training',
      theme: ThemeData.dark(),
      // Removed initialRoute to support dynamic routing
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/trainee-login':
            return MaterialPageRoute(builder: (_) => const TraineeLoginScreen());
          case '/trainee-simulator':
            final args = settings.arguments as Map<String, dynamic>?;
            final sessionCode = args != null && args['sessionCode'] is String ? args['sessionCode'] as String : '';
            return MaterialPageRoute(builder: (_) => TraineeSimulatorScreen(sessionCode: sessionCode));
          case '/instructor-login':
            return MaterialPageRoute(builder: (_) => const InstructorLoginScreen());
          case '/instructor-dashboard':
            return MaterialPageRoute(builder: (_) => const InstructorDashboardScreen());
          default:
            return MaterialPageRoute(builder: (_) => const TraineeLoginScreen());
        }
      },

    );
  }
}

