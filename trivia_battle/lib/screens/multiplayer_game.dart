import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:triviabattle/screens/main_menu.dart';
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

  static const bgColor = Color(0xFF0E0E11);
  static const cardColor = Color(0xFF1A1A22);
  static const accentColor = Color(0xFF7C7CFF);

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
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          timer.cancel();
          _checkRoundStatus();
        }
      });
    });
  }

  void _checkRoundStatus() async {
    if (_isMovingToNextQuestion) return;

    final lobbyDoc =
        await _firestore.collection('lobbies').doc(widget.lobbyId).get();
    if (!lobbyDoc.exists) return;

    final data = lobbyDoc.data()!;
    final playersMap = data['players'] as Map<String, dynamic>? ?? {};

    final allAnswered =
        playersMap.values.every((p) => (p as Map)['answered'] == true);

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
      await _firestore
          .collection('lobbies')
          .doc(widget.lobbyId)
          .update({'status': 'finished'});
    } else {
      // 1) reset answers
      await _resetPlayersAnswers(data);

      // 2) update currentQuestion
      await _firestore.collection('lobbies').doc(widget.lobbyId).update({
        'currentQuestion': currentIdx + 1,
        'roundStartedAt': FieldValue.serverTimestamp(),
      });

      _startRoundTimer(data['roundDuration'] ?? 10);
    }

    _isMovingToNextQuestion = false;
  }

  Future<void> _resetPlayersAnswers(Map<String, dynamic> data) async {
    final playersMap = data['players'] as Map<String, dynamic>? ?? {};
    final updates = <String, dynamic>{};

    for (final id in playersMap.keys) {
      updates['players.$id.answered'] = false;
      updates['players.$id.lastAnswer'] = -1;
      updates['players.$id.answeredAt'] = null;
    }

    await _firestore.collection('lobbies').doc(widget.lobbyId).update(updates);
  }

  int _calculateSecondsLeft(DateTime? startedAt, int duration) {
    if (startedAt == null) return duration;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    return max(0, duration - elapsed);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('lobbies').doc(widget.lobbyId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _loading("Lobby not found");
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final status = data['status'];

        if (status == 'finished') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_gameEnded) {
              _gameEnded = true;
              _showResults(data);
            }
          });
          return _loading("Game finished...");
        }

        if (status != 'playing') {
          return _loading("Waiting for game to start...");
        }

        final questions =
            (data['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final currentIdx = data['currentQuestion'] ?? 0;

        if (_roundTimer == null || !_roundTimer!.isActive) {
          final startedAt = (data['roundStartedAt'] as Timestamp?)?.toDate();
          final duration = data['roundDuration'] ?? 10;
          _timeLeft = _calculateSecondsLeft(startedAt, duration);
          _startRoundTimer(duration);
        }

        final question = questions[currentIdx];
        final players = data['players'] as Map<String, dynamic>;
        final myPlayer = players[_myUid] ?? {};
        final opponent = players.entries.firstWhere((e) => e.key != _myUid);

        _opponentName ??= opponent.value['name'];
        _myScore = myPlayer['score'] ?? 0;
        _opponentScore = opponent.value['score'] ?? 0;

        final selectedIdx = myPlayer['lastAnswer'] ?? -1;
        final correctIdx = question['correctIndex'];

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),

                /// SCORES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _scoreCard("You", _myScore),
                    _scoreCard(_opponentName!, _opponentScore),
                  ],
                ),

                const SizedBox(height: 24),

                /// TIMER
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _timeLeft / (data['roundDuration'] ?? 10),
                        strokeWidth: 8,
                        backgroundColor: cardColor,
                        valueColor: const AlwaysStoppedAnimation(accentColor),
                      ),
                      Text(
                        "$_timeLeft",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  "Question ${currentIdx + 1}/${questions.length}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 24),

                /// QUESTION
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      question['question'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// ANSWERS
                Expanded(
                  child: GridView.count(
                    padding: const EdgeInsets.all(16),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: List<String>.from(question['options'])
                        .asMap()
                        .entries
                        .map(
                      (e) {
                        final isCorrect = e.key == correctIdx;
                        final isSelected = e.key == selectedIdx;

                        Color color = cardColor;
                        if (selectedIdx != -1) {
                          if (isCorrect) color = Colors.green.shade700;
                          if (isSelected && !isCorrect) {
                            color = Colors.red.shade700;
                          }
                        }

                        return GestureDetector(
                          onTap: selectedIdx != -1
                              ? null
                              : () => _submitAnswer(e.key, question, _timeLeft),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                e.value,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ),
                if (selectedIdx != -1 || _timeLeft <= 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      selectedIdx == correctIdx
                          ? "Correct! +${_calculatePoints(question['difficulty'], _timeLeft)} points"
                          : "Wrong",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: selectedIdx == correctIdx
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scoreCard(String name, int score) {
    return Column(
      children: [
        Text(name, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          "$score",
          style: const TextStyle(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _submitAnswer(
      int index, Map<String, dynamic> question, int timeLeft) async {
    final uid = _myUid;
    if (uid == null) return;

    final isCorrect = index == question['correctIndex'];
    int points =
        isCorrect ? _calculatePoints(question['difficulty'], timeLeft) : 0;

    await _firestore.collection('lobbies').doc(widget.lobbyId).update({
      'players.$uid.answered': true,
      'players.$uid.lastAnswer': index,
      if (points > 0) 'players.$uid.score': FieldValue.increment(points),
    });

    _checkRoundStatus();
  }

  int _calculatePoints(String? difficulty, int timeLeft) {
    int base = difficulty == 'hard'
        ? 30
        : difficulty == 'medium'
            ? 20
            : 10;
    return base + (timeLeft / 6).floor().clamp(0, 10);
  }

  void _showResults(Map<String, dynamic> data) {
    final players = data['players'] as Map<String, dynamic>;
    final results = players.values.toList()
      ..sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0));

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: bgColor,
          body: Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    results.first['score'] == players[_myUid]?['score']
                        ? "YOU WIN 🎉"
                        : "YOU LOSE",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Players + scores
                  for (final p in results)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        "${p['name']}\n${p['score']} pts",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true)
                          .pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const MainMenu()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Back",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loading(String text) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
      ),
    );
  }
}
