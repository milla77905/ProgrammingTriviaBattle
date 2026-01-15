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
          SnackBar(content: Text('Napaka pri zagonu igre: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingGame = false);
    }
  }

  // Popravljena metoda - sprejme podatke kot parameter
  bool _canHostStartGame(Map<String, dynamic> data) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final players = Map<String, dynamic>.from(data['players'] ?? {});

    // Preveri če je host
    final isHost = data['hostId'] == user.uid;
    if (!isHost) return false;

    // Preveri če so vsi igralci ready
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
          SnackBar(content: Text('Napaka pri spremembi statusa: $e')),
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
      print('Napaka pri zapuščanju lobbyja: $e');
    }
  }

  Future<void> _leaveLobbyAndPop() async {
    await _leaveLobby();
    if (mounted) Navigator.pop(context);
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Lobby')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Nalagam lobby...'),
          ],
        ),
      ),
    );
  }

  Widget _buildLobbyNotFound() {
    return Scaffold(
      appBar: AppBar(title: const Text('Lobby')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Lobby ne obstaja'),
            const SizedBox(height: 8),
            const Text('Lobby je bil zaprt ali izbrisan'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nazaj'),
            ),
          ],
        ),
      ),
    );
  }

  // Shranimo snapshot podatke za dostop v metodah
  Map<String, dynamic>? snapshotData;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
          snapshotData = data; // Shrani podatke za dostop v metodah
          final status = data['status'] ?? 'waiting';
          final players = Map<String, dynamic>.from(data['players'] ?? {});
          final isHost = data['hostId'] == user?.uid;

          // Če igra že teče → preusmeri v MultiplayerGame
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

          // Sinhroniziraj ready status
          if (user != null && players.containsKey(user.uid)) {
            final currentPlayer = players[user.uid];
            final serverReady = currentPlayer['ready'] ?? false;
            if (_isReady != serverReady) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isReady = serverReady);
              });
            }
          }

          // Preveri če lahko host začne igro
          final canStartGame = _canHostStartGame(data);

          return Scaffold(
            appBar: AppBar(
              title: Text(data['name'] ?? 'Lobby'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _leaveLobbyAndPop,
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Lobby info
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            data['name'] ?? 'Ime ni nastavljeno',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text('Host: ${data['hostName'] ?? 'Neznan'}'),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  const Icon(Icons.group),
                                  Text(
                                      '${players.length}/${data['maxPlayers'] ?? 4}'),
                                  const Text('Igralcev'),
                                ],
                              ),
                              Column(
                                children: [
                                  const Icon(Icons.timer),
                                  Text('${data['roundDuration'] ?? 10}s'),
                                  const Text('Čas'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Seznam igralcev
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Igralci:',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: players.isEmpty
                              ? const Center(child: Text('Še ni igralcev...'))
                              : ListView.builder(
                                  itemCount: players.length,
                                  itemBuilder: (context, index) {
                                    final playerId =
                                        players.keys.elementAt(index);
                                    final player = players[playerId];
                                    final isCurrentUser = playerId == user?.uid;
                                    final isReady = player['ready'] ?? false;
                                    final isHostPlayer =
                                        playerId == data['hostId'];

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isCurrentUser
                                          ? Colors.blue.shade50
                                          : null,
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: isReady
                                              ? Colors.green.shade100
                                              : Colors.orange.shade100,
                                          child: Icon(
                                            isReady
                                                ? Icons.check
                                                : Icons.person,
                                            color: isReady
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                        title: Text(
                                          player['name'] ?? 'Igralec',
                                          style: TextStyle(
                                              fontWeight: isCurrentUser
                                                  ? FontWeight.bold
                                                  : null),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isReady)
                                              const Icon(Icons.check,
                                                  color: Colors.green),
                                            if (isHostPlayer)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    left: 8),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Text('Host',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Gumbi
                  if (!isHost)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _toggleReady,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isReady ? Colors.green : Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 3),
                              )
                            : Text(_isReady ? 'Pripravljen!' : 'Pripravi se'),
                      ),
                    ),

                  if (isHost)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canStartGame && !_isStartingGame
                            ? _startGame
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              canStartGame ? Colors.green : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isStartingGame
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 3)),
                                  SizedBox(width: 12),
                                  Text('Nalagam vprašanja...'),
                                ],
                              )
                            : Text(
                                canStartGame
                                    ? 'ZAČNI IGRO'
                                    : players.length < 2
                                        ? 'Čakam na igralce'
                                        : 'Čakam na pripravo',
                              ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading || _isStartingGame
                          ? null
                          : _leaveLobbyAndPop,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Zapusti lobby'),
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
}
