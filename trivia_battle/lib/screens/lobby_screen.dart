import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:triviabattle/providers/quiz_provider.dart';
import 'package:triviabattle/screens/multiplayer_game.dart';

class LobbyScreen extends StatefulWidget {
  final String lobbyId;

  const LobbyScreen({super.key, required this.lobbyId});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with WidgetsBindingObserver {
  bool _isReady = false;
  bool _isLoading = false;
  bool _isStartingGame = false;

  static const bgMain = Color(0xFF0E0E11);
  static const bgCard = Color(0xFF1A1A22);
  static const accent = Color(0xFF7C7CFF);

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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _leaveLobby();
    }
  }

  Future<void> _startGame() async {
    if (!_canHostStartGame(snapshotData!)) return;

    setState(() => _isStartingGame = true);

    try {
      final quizProvider = Provider.of<QuizProvider>(context, listen: false);
      await quizProvider.fetchQuestionsFromApi(amount: 10);

      final questions = quizProvider.questions.map((q) {
        return {
          'question': q.question,
          'options': q.options,
          'correctIndex': q.correctIndex,
          'category': 'Programming',
          'difficulty': 'medium',
        };
      }).toList();

      final user = FirebaseAuth.instance.currentUser;
      final lobbyRef =
          FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
      final lobbyDoc = await lobbyRef.get();
      final data = lobbyDoc.data()!;
      final players = Map<String, dynamic>.from(data['players'] ?? {});

      final playerUpdates = <String, dynamic>{};
      for (final playerId in players.keys) {
        playerUpdates['players.$playerId.score'] = 0;
        playerUpdates['players.$playerId.answered'] = false;
        playerUpdates['players.$playerId.lastAnswer'] = -1;
        playerUpdates['players.$playerId.answeredAt'] = null;
      }

      await lobbyRef.update({
        'status': 'playing',
        'questions': questions,
        'currentQuestion': 0,
        'roundStartedAt': FieldValue.serverTimestamp(),
        'roundDuration': 10,
        ...playerUpdates,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting the game: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingGame = false);
    }
  }

  bool _canHostStartGame(Map<String, dynamic> data) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final players = Map<String, dynamic>.from(data['players'] ?? {});

    final isHost = data['hostId'] == user.uid;
    if (!isHost) return false;

    bool allReady = true;
    for (final player in players.values) {
      if ((player as Map)['ready'] != true) {
        allReady = false;
        break;
      }
    }

    return allReady && players.length >= 2;
  }

  Future<void> _toggleReady() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('lobbies')
          .doc(widget.lobbyId)
          .update({
        'players.${user.uid}.ready': !_isReady,
      });

      setState(() => _isReady = !_isReady);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating ready status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveLobby() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final lobbyRef =
          FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
      final lobbyDoc = await lobbyRef.get();
      if (!lobbyDoc.exists) return;

      final data = lobbyDoc.data()!;
      final players = Map<String, dynamic>.from(data['players'] ?? {});

      if (!players.containsKey(user.uid)) return;

      players.remove(user.uid);

      if (players.isEmpty) {
        await lobbyRef.delete();
      } else {
        String newHostId = data['hostId'];
        if (newHostId == user.uid) {
          newHostId = players.keys.first;
          final newHost = players[newHostId];

          await lobbyRef.update({
            'currentPlayers': FieldValue.increment(-1),
            'hostId': newHostId,
            'hostName': newHost['name'],
            'players': players,
          });
        } else {
          await lobbyRef.update({
            'currentPlayers': FieldValue.increment(-1),
            'players': players,
          });
        }
      }
    } catch (e) {
      print('Error leaving lobby: $e');
    }
  }

  Future<void> _leaveLobbyAndPop() async {
    await _leaveLobby();
    if (mounted) Navigator.pop(context);
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        backgroundColor: bgMain,
        elevation: 0,
        title: const Text(
          'Lobby',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: accent),
            const SizedBox(height: 16),
            Text(
              'Loading lobby...',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLobbyNotFound() {
    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        backgroundColor: bgMain,
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
          'Lobby',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: accent,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgCard,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Lobby not found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The lobby was closed or deleted.',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Go back',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? snapshotData;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    const bgMain = Color(0xFF0E0E11);
    const bgCard = Color(0xFF1A1A22);
    const accent = Color(0xFF7C7CFF);

    return WillPopScope(
      onWillPop: () async {
        await _leaveLobby();
        return true;
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lobbies')
            .doc(widget.lobbyId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildLobbyNotFound();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          snapshotData = data;
          final status = data['status'] ?? 'waiting';
          final players = Map<String, dynamic>.from(data['players'] ?? {});
          final isHost = data['hostId'] == user?.uid;

          if (status == 'playing') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MultiplayerGame(lobbyId: widget.lobbyId),
                  ),
                );
              }
            });
            return _buildLoadingScreen();
          }

          final canStartGame = _canHostStartGame(data);

          return Scaffold(
            backgroundColor: bgMain,
            appBar: AppBar(
              backgroundColor: bgMain,
              elevation: 0,
              title: Text(
                data['name'] ?? 'Lobby',
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
                onPressed: _leaveLobbyAndPop,
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // === LOBBY INFO CARD ===
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          data['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Host: ${data['hostName']}',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _infoItem(
                              icon: Icons.group,
                              label: '${players.length}/${data['maxPlayers']}',
                            ),
                            _infoItem(
                              icon: Icons.timer,
                              label: '${data['roundDuration'] ?? 10}s',
                            ),
                          ],
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // === PLAYERS ===
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Players',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: players.length,
                            itemBuilder: (context, index) {
                              final playerId = players.keys.elementAt(index);
                              final player = players[playerId];
                              final isReady = player['ready'] ?? false;
                              final isHostPlayer = playerId == data['hostId'];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: bgCard,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isReady
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: isReady
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        player['name'],
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                    if (isHostPlayer)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: accent.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'HOST',
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: isHost
                        ? (canStartGame ? _startGame : null)
                        : _toggleReady,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accent.withOpacity(0.4),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          isHost
                              ? 'START GAME'
                              : _isReady
                                  ? 'READY'
                                  : 'GET READY',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: _leaveLobbyAndPop,
                    child: const Text(
                      'Leave lobby',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoItem({required IconData icon, required String label}) {
    return Column(
      children: [
        Icon(icon, color: Color(0xFF7C7CFF)),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}
