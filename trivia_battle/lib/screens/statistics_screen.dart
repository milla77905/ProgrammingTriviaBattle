import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

const bgMain = Color(0xFF0E0E11);
const bgCard = Color(0xFF1A1A22);
const accent = Color(0xFF7C7CFF);

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        backgroundColor: bgMain,
        elevation: 0,
        title: const Text(
          'Statistics',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: accent,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
            size: 20,
          ),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Basic'),
            Tab(text: 'Multiplayer'),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirestoreService.userStatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: accent),
            );
          }

          if (snapshot.hasError) {
            return _ErrorBox(
              title: 'Error loading statistics',
              message: snapshot.error.toString(),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const _EmptyStats();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final int totalGames = (data['totalGames'] ?? 0) as int;
          final int totalCorrect = (data['totalCorrect'] ?? 0) as int;
          final int totalQuestions = (data['totalQuestions'] ?? 0) as int;
          final int bestScore = (data['bestScore'] ?? 0) as int;
          final int points = (data['points'] ?? 0) as int;

          final dynamic accuracyValue = data['averageAccuracy'];
          final double averageAccuracy = accuracyValue is double
              ? accuracyValue
              : (accuracyValue is int ? accuracyValue.toDouble() : 0.0);

          final dynamic gamesPlayedValue = data['gamesPlayed'];
          final Map<String, dynamic> gamesPlayed =
              gamesPlayedValue is Map<String, dynamic> ? gamesPlayedValue : {};
          final int soloGames = (gamesPlayed['solo'] ?? 0) as int;
          final int multiplayerGames = (gamesPlayed['multiplayer'] ?? 0) as int;

          final dynamic mpStatsValue = data['multiplayerStats'];
          final Map<String, dynamic> multiplayerStats =
              mpStatsValue is Map<String, dynamic> ? mpStatsValue : {};
          final int mpWins = (multiplayerStats['wins'] ?? 0) as int;
          final int mpLosses = (multiplayerStats['losses'] ?? 0) as int;
          final int mpGames = (multiplayerStats['gamesPlayed'] ?? 0) as int;
          final double mpWinRate =
              (multiplayerStats['winRate'] ?? 0.0).toDouble();

          return TabBarView(
            controller: _tabController,
            children: [
              _BasicStats(
                totalGames: totalGames,
                totalCorrect: totalCorrect,
                totalQuestions: totalQuestions,
                bestScore: bestScore,
                points: points,
                averageAccuracy: averageAccuracy,
                soloGames: soloGames,
                multiplayerGames: multiplayerGames,
              ),
              _MultiStats(
                mpGames: mpGames,
                mpWins: mpWins,
                mpLosses: mpLosses,
                mpWinRate: mpWinRate,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BasicStats extends StatelessWidget {
  final int totalGames;
  final int totalCorrect;
  final int totalQuestions;
  final int bestScore;
  final int points;
  final double averageAccuracy;
  final int soloGames;
  final int multiplayerGames;

  const _BasicStats({
    required this.totalGames,
    required this.totalCorrect,
    required this.totalQuestions,
    required this.bestScore,
    required this.points,
    required this.averageAccuracy,
    required this.soloGames,
    required this.multiplayerGames,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _HeaderCard(points: points, bestScore: bestScore),
          const SizedBox(height: 16),
          _StatGrid(
            items: [
              _StatItem(
                title: 'Games played',
                value: totalGames.toString(),
                icon: Icons.gamepad,
                accent: accent,
                subtitle: 'Solo: $soloGames • Multi: $multiplayerGames',
              ),
              _StatItem(
                title: 'Best score',
                value: bestScore.toString(),
                icon: Icons.star,
                accent: Colors.amber,
                subtitle: 'points',
              ),
              _StatItem(
                title: 'Accuracy',
                value: '${averageAccuracy.toStringAsFixed(1)}%',
                icon: Icons.percent,
                accent: Colors.green,
                subtitle: 'Progress',
                progress: averageAccuracy / 100,
              ),
              _StatItem(
                title: 'Correct answers',
                value: '$totalCorrect/$totalQuestions',
                icon: Icons.check_circle,
                accent: Colors.green,
                subtitle: totalQuestions == 0
                    ? '0%'
                    : '${(totalCorrect / totalQuestions * 100).toStringAsFixed(1)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MultiStats extends StatelessWidget {
  final int mpGames;
  final int mpWins;
  final int mpLosses;
  final double mpWinRate;

  const _MultiStats({
    required this.mpGames,
    required this.mpWins,
    required this.mpLosses,
    required this.mpWinRate,
  });

  @override
  Widget build(BuildContext context) {
    if (mpGames == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No multiplayer games yet.\nPlay a multiplayer match to unlock stats!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            color: bgCard,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _StatRow(
                    label: 'Multiplayer games',
                    value: '$mpGames games',
                    icon: Icons.group,
                    color: accent,
                  ),
                  _StatRow(
                    label: 'Wins',
                    value: mpWins.toString(),
                    icon: Icons.emoji_events,
                    color: Colors.green,
                  ),
                  _StatRow(
                    label: 'Losses',
                    value: mpLosses.toString(),
                    icon: Icons.sentiment_dissatisfied,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  _ProgressBar(
                    label: 'Win rate',
                    value: mpWinRate / 100,
                    suffix: '${mpWinRate.toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int points;
  final int bestScore;

  const _HeaderCard({
    required this.points,
    required this.bestScore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              accent.withOpacity(0.35),
              bgCard,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'YOUR STATS',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              points.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total points',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.amber.shade600, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Best score: $bestScore',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final List<_StatItem> items;

  const _StatGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.05,
      children: items,
    );
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final String subtitle;
  final double progress;

  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    this.subtitle = '',
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(color: Colors.white70),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            if (progress > 0) ...[
              const SizedBox(height: 10),
              _ProgressBar(
                label: '',
                value: progress,
                suffix: '',
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final String suffix;

  const _ProgressBar({
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (label.isNotEmpty)
          Row(
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              Text(suffix, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.grey.shade800,
          color: accent,
          minHeight: 6,
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insights,
              size: 60,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            const Text(
              'No statistics yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Play solo quizzes to see your stats',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Start playing'),
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String title;
  final String message;

  const _ErrorBox({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
