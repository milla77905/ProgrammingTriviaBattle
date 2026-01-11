import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth/auth_screen.dart';
import 'providers/quiz_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDSG8yizEp-CkP8t08dQunIGLQyo27BRmc",
      appId: "1:429694467940:android:fc171a350c69219aa74471",
      messagingSenderId: "429694467940",
      projectId: "programmingtriviabattle",
      storageBucket: "programmingtriviabattle.firebasestorage.app",
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuizProvider()),
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
      debugShowCheckedModeBanner: false,
      title: 'TriviaBattle',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey.shade50,
      ),
      home: AuthScreen(),
    );
  }
}
