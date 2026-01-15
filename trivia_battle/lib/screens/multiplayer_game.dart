import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:triviabattle/services/firestore_service.dart';

class MultiplayerGame extends StatefulWidget {
  final String lobbyId;
  const MultiplayerGame({super.key, required this.lobbyId});

  @override
  State<MultiplayerGame> createState() => _MultiplayerGameState();
}

class _MultiplayerGameState extends State<MultiplayerGame> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Timer? _uiRefreshTimer;
  Timer? _roundTimer;
  bool _gameEnded = false;
  bool _isMovingToNextQuestion = false;

  String? _myUid;
  String? _opponentUid;
  String? _opponentName;
  int _myScore = 0;
  int _opponentScore = 0;
  int _timeLeft = 10;

  @override
  void initState() {
    super.initState();
    _myUid = _auth.currentUser?.uid;
    _uiRefreshTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _roundTimer?.cancel();
    super.dispose();
  }

  void _startRoundTimer(int duration) {
    _roundTimer?.cancel();
    _timeLeft = duration;

    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            timer.cancel();
            _checkRoundStatus();
          }
        });
      }
    });
  }

  void _checkRoundStatus() async {
    if (_isMovingToNextQuestion) return;

    final lobbyDoc =
        await _firestore.collection('lobbies').doc(widget.lobbyId).get();
    if (!lobbyDoc.exists) return;

    final data = lobbyDoc.data()!;
    final playersMap = data['players'] as Map<String, dynamic>? ?? {};

    bool allAnswered = true;
    for (final player in playersMap.values) {
      if ((player as Map)['answered'] != true) {
        allAnswered = false;
        break;
      }
    }

    // Če so vsi odgovorili ali je čas potekel, pojdi na naslednje vprašanje
    if (allAnswered || _timeLeft <= 0) {
      _moveToNextQuestion(data);
    }
  }

  Future<void> _moveToNextQuestion(Map<String, dynamic> data) async {
    if (_isMovingToNextQuestion) return;

    _isMovingToNextQuestion = true;
    final currentIdx = data['currentQuestion'] as int? ?? 0;
    final questions =
        (data['questions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];

    if (currentIdx + 1 >= questions.length) {
      await _firestore.collection('lobbies').doc(widget.lobbyId).update({
        'status': 'finished',
      });
    } else {
      await _firestore.collection('lobbies').doc(widget.lobbyId).update({
        'currentQuestion': currentIdx + 1,
        'roundStartedAt': FieldValue.serverTimestamp(),
      });

      await _resetPlayersAnswers(data);

      _startRoundTimer(data['roundDuration'] as int? ?? 10);
    }

    _isMovingToNextQuestion = false;
  }

  Future<void> _resetPlayersAnswers(Map<String, dynamic> data) async {
    final playersMap = data['players'] as Map<String, dynamic>? ?? {};
    final updates = <String, dynamic>{};

    for (final playerId in playersMap.keys) {
      updates['players.$playerId.answered'] = false;
      updates['players.$playerId.lastAnswer'] = -1;
      updates['players.$playerId.answeredAt'] = null;
    }

    await _firestore.collection('lobbies').doc(widget.lobbyId).update(updates);
  }

  int _calculateSecondsLeft(DateTime? startedAt, int durationSec) {
    if (startedAt == null) return durationSec;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    return max(0, durationSec - elapsed);
  }

  Color _getDifficultyColor(String? diff) {
    switch (diff?.toLowerCase()) {
      case 'hard':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('lobbies').doc(widget.lobbyId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildErrorScreen("Lobby ne obstaja več");
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'unknown';

        if (status == 'finished') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_gameEnded && mounted) {
              _gameEnded = true;
              _showResults(data);
            }
          });
          return _buildLoadingScreen("Igra je končana...");
        }

        if (status != 'playing') {
          return _buildLoadingScreen("Igra se še ni začela...");
        }

        final questions = (data['questions'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        if (questions.isEmpty) {
          return _buildLoadingScreen("Čakam na vprašanja...");
        }

        final currentIdx = data['currentQuestion'] as int? ?? 0;
        if (currentIdx >= questions.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_gameEnded && mounted) {
              _gameEnded = true;
              _showResults(data);
            }
          });
          return _buildLoadingScreen("Konec vprašanj...");
        }

        if (_roundTimer == null || !_roundTimer!.isActive) {
          final roundStarted = (data['roundStartedAt'] as Timestamp?)?.toDate();
          final duration = data['roundDuration'] as int? ?? 10;
          final timeLeftFromServer =
              _calculateSecondsLeft(roundStarted, duration);
          _timeLeft = timeLeftFromServer;
          _startRoundTimer(duration);
        }

        final question = questions[currentIdx];
        final roundStarted = (data['roundStartedAt'] as Timestamp?)?.toDate();
        final duration = data['roundDuration'] as int? ?? 10;

        final playersMap = data['players'] as Map<String, dynamic>? ?? {};
        final myPlayer = playersMap[_myUid] ?? {};
        final opponentEntries =
            playersMap.entries.where((e) => e.key != _myUid).toList();

        if (opponentEntries.isEmpty) {
          return _buildLoadingScreen("Čakam na nasprotnika...");
        }

        final opponentEntry = opponentEntries.first;
        _opponentUid ??= opponentEntry.key;
        _opponentName ??= (opponentEntry.value as Map)['name'] ?? 'Nasprotnik';

        _myScore = (myPlayer['score'] as num?)?.toInt() ?? 0;
        _opponentScore = (opponentEntry.value['score'] as num?)?.toInt() ?? 0;

        final timeUp = _timeLeft <= 0;

        final hasAnswered = myPlayer['answered'] == true;
        final selectedIdx = (myPlayer['lastAnswer'] as num?)?.toInt() ?? -1;
        final correctIdx = question['correctIndex'] as int;

        final options = List<String>.from(question['options']);

        return Scaffold(
          appBar: AppBar(
            title: Text('Vprašanje ${currentIdx + 1}/${questions.length}'),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    const Icon(Icons.timer, size: 18),
                    const SizedBox(width: 4),
                    Text('$_timeLeft s',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                color: Colors.blue.shade700,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildScoreColumn("Jaz", _myScore, Colors.white),
                    _buildScoreColumn(_opponentName ?? "Nasprotnik",
                        _opponentScore, Colors.yellow[100]!),
                  ],
                ),
              ),

              // Vprašanje + kategorija + težavnost
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          label: Text(question['category'] ?? 'Kategorija'),
                          backgroundColor: Colors.grey[300],
                        ),
                        Chip(
                          label: Text(
                              (question['difficulty'] ?? 'easy').toUpperCase()),
                          backgroundColor:
                              _getDifficultyColor(question['difficulty']),
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 3)),
                        ],
                      ),
                      child: Text(
                        question['question'] ?? '',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // Možnosti
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: options.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final text = entry.value;
                      final isCorrect = idx == correctIdx;
                      final isSelected = idx == selectedIdx;

                      Color? bgColor;
                      Color? textColor = Colors.black87;
                      BorderSide border =
                          BorderSide(color: Colors.grey.shade300, width: 1.5);

                      if (hasAnswered || timeUp) {
                        if (isCorrect) {
                          bgColor = Colors.green.shade100;
                          border = BorderSide(color: Colors.green, width: 2.5);
                          textColor = Colors.green.shade900;
                        } else if (isSelected) {
                          bgColor = Colors.red.shade100;
                          border = BorderSide(color: Colors.red, width: 2.5);
                          textColor = Colors.red.shade900;
                        }
                      }

                      return Card(
                        elevation: hasAnswered || timeUp ? 0 : 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: border,
                        ),
                        color: bgColor ?? Colors.white,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: (hasAnswered || timeUp)
                              ? null
                              : () => _submitAnswer(idx, question, _timeLeft),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: textColor,
                                  fontWeight:
                                      isSelected ? FontWeight.bold : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              if (hasAnswered || timeUp)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        selectedIdx == correctIdx ? "✅ PRAVILNO!" : "❌ Napačno",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: selectedIdx == correctIdx
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (selectedIdx != correctIdx)
                        Text(
                          "Pravilen odgovor: ${options[correctIdx]}",
                          style: const TextStyle(fontSize: 16),
                        ),
                      const SizedBox(height: 12),
                      // Prikaži če nasprotnik še ni odgovoril
                      if (!_checkIfAllAnswered(playersMap) && hasAnswered)
                        Text(
                          "Čakam na nasprotnika...",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _checkIfAllAnswered(Map<String, dynamic> playersMap) {
    for (final player in playersMap.values) {
      if ((player as Map)['answered'] != true) {
        return false;
      }
    }
    return true;
  }

  Widget _buildScoreColumn(String label, int score, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(color: color.withOpacity(0.9), fontSize: 13)),
        Text(
          "$score",
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _submitAnswer(
      int index, Map<String, dynamic> question, int timeLeft) async {
    final uid = _myUid;
    if (uid == null) return;

    final isCorrect = index == question['correctIndex'];
    int points = 0;

    if (isCorrect) {
      points = _calculatePoints(question['difficulty'], timeLeft);
    }

    await _firestore.collection('lobbies').doc(widget.lobbyId).update({
      'players.$uid.answered': true,
      'players.$uid.lastAnswer': index,
      'players.$uid.answeredAt': FieldValue.serverTimestamp(),
      if (points > 0) 'players.$uid.score': FieldValue.increment(points),
    });

    _checkRoundStatus();
  }

  int _calculatePoints(String? difficulty, int timeLeft) {
    int base = 10;
    if (difficulty == 'hard') base = 30;
    if (difficulty == 'medium') base = 20;

    final timeBonus = (timeLeft / 6).floor();
    return base + timeBonus.clamp(0, 10);
  }

  void _showResults(Map<String, dynamic> data) async {
    final players = data['players'] as Map<String, dynamic>? ?? {};
    final myScore = (players[_myUid]?['score'] as num?)?.toInt() ?? 0;

    int maxScore = 0;
    String? winnerName;
    bool isDraw = false;
    List<Map<String, dynamic>> playerResults = [];

    for (final entry in players.entries) {
      final playerData = entry.value as Map<String, dynamic>;
      final score = (playerData['score'] as num?)?.toInt() ?? 0;
      final name = playerData['name'] ?? 'Neznan';

      playerResults.add({
        'name': name,
        'score': score,
      });

      if (score > maxScore) {
        maxScore = score;
        winnerName = name;
        isDraw = false;
      } else if (score == maxScore &&
          winnerName != null &&
          name != winnerName) {
        isDraw = true;
      }
    }

    final iWon = !isDraw &&
        winnerName != null &&
        playerResults.firstWhere((p) => p['name'] == winnerName,
                orElse: () => playerResults.first)['name'] ==
            playerResults.firstWhere(
                (p) => p['name'] == (players[_myUid]?['name'] ?? 'Jaz'),
                orElse: () => playerResults.first)['name'];

    try {
      await FirestoreService.saveMultiplayerGameResult(
        lobbyId: widget.lobbyId,
        yourScore: myScore,
        opponentScore: maxScore,
        won: iWon,
      );
    } catch (e) {
      print('Error saving multiplayer result: $e');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isDraw
            ? "🤝 IZENAČENO!"
            : iWon
                ? "🎉 ZMAGAL SI! 🎉"
                : "Konec igre"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final player in playerResults)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text("${player['name']}: ",
                        style: const TextStyle(fontSize: 16)),
                    Text("${player['score']} točk",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: player['name'] == winnerName
                              ? FontWeight.bold
                              : null,
                          color: player['name'] == winnerName
                              ? Colors.green
                              : null,
                        )),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (isDraw)
              const Text("Igra se je končala z izenačenjem!",
                  style: TextStyle(fontSize: 16, color: Colors.blue)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Nazaj na lobbyje"),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen(String text) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(text, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String msg) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            msg,
            style: const TextStyle(fontSize: 20, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
