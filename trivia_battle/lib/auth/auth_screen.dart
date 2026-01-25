import 'package:flutter/material.dart';
import './auth_service.dart';
import '/screens/main_menu.dart';
import '../services/firestore_service.dart';

const bgMain = Color(0xFF0E0E11);
const bgCard = Color(0xFF1A1A22);
const accent = Color(0xFF7C7CFF);

class AuthScreen extends StatelessWidget {
  final AuthService _authService = AuthService();

  AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgMain,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LOGO / ICON
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.code_rounded,
                    size: 46,
                    color: accent,
                  ),
                ),

                const SizedBox(height: 28),

                // TITLE
                const Text(
                  'ProgTrivia',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Programming trivia game',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white60,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 36),

                // LOGIN CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Sign in to continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.login, size: 20),
                          label: const Text(
                            'Sign in with Google',
                            style: TextStyle(fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            try {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(
                                  child: CircularProgressIndicator(
                                    color: accent,
                                  ),
                                ),
                              );

                              final user =
                                  await _authService.signInWithGoogle();

                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }

                              if (user != null) {
                                await FirestoreService.createUserIfNotExists();

                                if (context.mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const MainMenu(),
                                    ),
                                  );
                                }
                              } else {
                                _showError(
                                  context,
                                  'Sign in failed. Please try again.',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                _showError(context, e.toString());
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'You must sign in with Google to use the app.',
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'What is ProgTrivia?',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        content: Text(message),
      ),
    );
  }
}
