import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  final Color bg1 = const Color(0xFF0E0E11);
  final Color bg2 = const Color(0xFF1A1A22);
  static const Color accent = Color(0xFF7C7CFF);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg1,
      appBar: AppBar(
        backgroundColor: bg2,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
            size: 20,
          ),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: accent,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.leaderboardStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.leaderboard,
                      size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No players on leaderboard yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Play games to appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;
          final currentUser = FirestoreService.currentUserId;

          return Column(
            children: [
              // TOP 3
              Container(
                height: 170,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [bg2, const Color(0xFF2A2A36)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (docs.length > 1)
                      _TopPlayerCard(rank: 2, player: docs[1]),
                    if (docs.isNotEmpty)
                      _TopPlayerCard(rank: 1, player: docs[0], isFirst: true),
                    if (docs.length > 2)
                      _TopPlayerCard(rank: 3, player: docs[2]),
                  ],
                ),
              ),

              // LIST
              Expanded(
                child: Container(
                  color: bg1,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isCurrentUser = doc.id == currentUser;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        child: Card(
                          elevation: 1,
                          color:
                              isCurrentUser ? Colors.white12 : Colors.white10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            leading: Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isCurrentUser
                                    ? accent.withOpacity(0.7)
                                    : Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentUser
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                            ),
                            title: Text(
                              data['username'] ?? 'Anonymous',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  '${data['totalGames'] ?? 0} games',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white60),
                                ),
                                if (data['averageAccuracy'] != null)
                                  Text(
                                    'Accuracy: ${(data['averageAccuracy'] as double).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.white60),
                                  ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${data['points'] ?? 0}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'points',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopPlayerCard extends StatelessWidget {
  final int rank;
  final DocumentSnapshot player;
  final bool isFirst;

  const _TopPlayerCard({
    required this.rank,
    required this.player,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = player.data() as Map<String, dynamic>;
    final username = data['username'] ?? 'Player';
    final points = data['points'] ?? 0;
    final games = data['totalGames'] ?? 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 👇 še manjši krogi
        Container(
          width: isFirst ? 60 : 52,
          height: isFirst ? 60 : 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            shape: BoxShape.circle,
            border: Border.all(
              color: _getRankColor(rank),
              width: isFirst ? 2.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: isFirst ? 14 : 13,
                fontWeight: FontWeight.bold,
                color: _getRankColor(rank),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // 👇 še manjša info kartica
        Container(
          width: isFirst ? 95 : 86,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Text(
                username.length > 8
                    ? '${username.substring(0, 8)}...'
                    : username,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$points pts',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7C7CFF),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$games games',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),
      ],
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.white;
    }
  }
}
