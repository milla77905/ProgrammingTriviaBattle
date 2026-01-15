import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistika'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirestoreService.userStatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            print('Error in stats stream: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Napaka pri nalaganju',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _EmptyStats();
          }

          try {
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
                gamesPlayedValue is Map<String, dynamic>
                    ? gamesPlayedValue
                    : {};
            final int soloGames = (gamesPlayed['solo'] ?? 0) as int;
            final int multiplayerGames =
                (gamesPlayed['multiplayer'] ?? 0) as int;

            final dynamic mpStatsValue = data['multiplayerStats'];
            final Map<String, dynamic> multiplayerStats =
                mpStatsValue is Map<String, dynamic> ? mpStatsValue : {};
            final int mpWins = (multiplayerStats['wins'] ?? 0) as int;
            final int mpLosses = (multiplayerStats['losses'] ?? 0) as int;
            final int mpGames = (multiplayerStats['gamesPlayed'] ?? 0) as int;
            final double mpWinRate =
                (multiplayerStats['winRate'] ?? 0.0).toDouble();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MainStatCard(points: points, bestScore: bestScore),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'Osnovna statistika',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    padding: const EdgeInsets.all(4),
                    children: [
                      _StatCard(
                        title: 'Odigrane igre',
                        value: totalGames.toString(),
                        icon: Icons.gamepad,
                        color: Colors.blue,
                        subtitle: 'Solo: $soloGames\nMulti: $multiplayerGames',
                      ),
                      _StatCard(
                        title: 'Najboljši rezultat',
                        value: bestScore.toString(),
                        icon: Icons.star,
                        color: Colors.amber,
                        subtitle: 'točk',
                      ),
                      _StatCard(
                        title: 'Natančnost',
                        value: '${averageAccuracy.toStringAsFixed(1)}%',
                        icon: Icons.percent,
                        color: Colors.green,
                        subtitle: 'Točke: $points',
                      ),
                      _StatCard(
                        title: 'Pravilni odgovori',
                        value: '$totalCorrect/$totalQuestions',
                        icon: Icons.check_circle,
                        color: Colors.green,
                        subtitle: totalQuestions == 0
                            ? '0%'
                            : '${(totalCorrect / totalQuestions * 100).toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (mpGames > 0) ...[
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 8),
                      child: Text(
                        'Multiplayer statistika',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6A1B9A),
                        ),
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            _StatRow(
                              label: 'Multiplayer igre',
                              value: '$mpGames igre',
                              icon: Icons.group,
                            ),
                            _StatRow(
                              label: 'Zmage',
                              value: mpWins.toString(),
                              icon: Icons.emoji_events,
                              color: Colors.green,
                            ),
                            _StatRow(
                              label: 'Porazi',
                              value: mpLosses.toString(),
                              icon: Icons.sentiment_dissatisfied,
                              color: Colors.red,
                            ),
                            _StatRow(
                              label: 'Uspešnost',
                              value: '${mpWinRate.toStringAsFixed(1)}%',
                              icon: Icons.trending_up,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            );
          } catch (e) {
            print('Error parsing stats data: $e');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Napaka pri obdelavi podatkov',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
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
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Še ni statistike',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Igraj solo kvize za ogled statistike',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Začni igrati'),
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainStatCard extends StatelessWidget {
  final int points;
  final int bestScore;

  const _MainStatCard({
    required this.points,
    required this.bestScore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events,
                size: 36,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'SKUPNE TOČKE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              points.toString(),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 12),
            Divider(
              color: Colors.grey.shade300,
              height: 1,
              thickness: 1,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star,
                  size: 18,
                  color: Colors.amber.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  'Najboljši rezultat: $bestScore',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameHistoryList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.gameHistoryStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          if (error.contains('index')) {
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Zgodovina iger se še nalaga',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Firebase potrebuje nekaj časa za nastavitev',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Osveži'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('Napaka: ${snapshot.error}'),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Še ni zgodovine iger',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tvoja prva igra bo tukaj!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final displayCount = docs.length > 5 ? 5 : docs.length;

        return Column(
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayCount,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;

                final String mode = data['mode']?.toString() ?? 'solo';
                final int score =
                    (data['score'] ?? data['yourScore'] ?? 0) as int;
                final int correct = (data['correct'] ?? 0) as int;
                final int total = (data['total'] ?? 1) as int;
                final dynamic timestamp = data['timestamp'];

                final String formattedDate = _formatDate(timestamp);
                final int accuracy =
                    total == 0 ? 0 : ((correct / total) * 100).round();

                return Card(
                  margin: EdgeInsets.zero,
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: mode == 'solo'
                            ? Colors.blue.shade50
                            : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        mode == 'solo' ? Icons.person : Icons.group,
                        size: 20,
                        color: mode == 'solo' ? Colors.blue : Colors.purple,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            mode == 'solo' ? 'Solo kviz' : 'Multiplayer',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: mode == 'solo'
                                ? Colors.blue.shade100
                                : Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            mode == 'solo' ? 'SOLO' : 'MULTI',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: mode == 'solo'
                                  ? const Color(0xFF1565C0)
                                  : const Color(0xFF6A1B9A),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '$formattedDate • $correct/$total pravilno ($accuracy%)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$score',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'točk',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (docs.length > 5) ...[
              const SizedBox(height: 8),
              Text(
                'Prikazano $displayCount od ${docs.length} iger',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        );
      },
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Neznan datum';

    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        final now = DateTime.now();
        final difference = now.difference(date);

        if (difference.inDays == 0) {
          return 'Danes';
        } else if (difference.inDays == 1) {
          return 'Včeraj';
        } else if (difference.inDays < 7) {
          return 'Pred ${difference.inDays} dnevi';
        } else {
          return '${date.day}. ${date.month}. ${date.year}';
        }
      }
    } catch (e) {
      print('Error formatting date: $e');
    }

    return 'Neznan datum';
  }
}
