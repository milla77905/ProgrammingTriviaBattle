import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:triviabattle/auth/auth_screen.dart';
import 'package:triviabattle/providers/quiz_provider.dart';
import 'solo_quiz.dart';
import 'multiplayer_screen.dart';
import 'statistics_screen.dart';
import 'leaderboard_screen.dart';
import '../auth/auth_service.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  static const Color bgDark = Color(0xFF0E0E11);
  static const Color bgCard = Color(0xFF1A1A22);
  static const Color accent = Color(0xFF7C7CFF);

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'ProgTrivia',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: accent,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Log out',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: bgCard,
                  title: const Text(
                    'Log out',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Are you sure you want to log out?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await authService.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => AuthScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Choose Game Mode',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(20),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.95,
              children: [
                _MenuCard(
                  title: 'Solo Quiz',
                  subtitle: 'Play alone',
                  icon: Icons.person_outline,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider(
                        create: (_) => QuizProvider(),
                        child: const SoloQuiz(),
                      ),
                    ),
                  ),
                ),
                _MenuCard(
                  title: 'Multiplayer',
                  subtitle: 'Play with others',
                  icon: Icons.groups_rounded,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MultiplayerScreen(),
                    ),
                  ),
                ),
                _MenuCard(
                  title: 'Statistics',
                  subtitle: 'Your progress',
                  icon: Icons.bar_chart_rounded,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StatisticsScreen(),
                    ),
                  ),
                ),
                _MenuCard(
                  title: 'Leaderboard',
                  subtitle: 'Top players',
                  icon: Icons.leaderboard_rounded,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeaderboardScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  static const Color bgCard = Color(0xFF1A1A22);
  static const Color accent = Color(0xFF7C7CFF);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bgCard,
              bgCard.withOpacity(0.85),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: accent),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
