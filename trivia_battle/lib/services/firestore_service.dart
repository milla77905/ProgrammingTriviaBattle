import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Ustvari userja če ne obstaja
  static Future<void> createUserIfNotExists() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);

    try {
      final doc = await userRef.get();

      if (!doc.exists) {
        await userRef.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'username': user.displayName ?? user.email?.split('@')[0] ?? 'User',
          'points': 0,
          'totalGames': 0,
          'totalCorrect': 0,
          'totalQuestions': 0,
          'bestScore': 0,
          'averageAccuracy': 0.0,
          'gamesPlayed': {
            'solo': 0,
            'multiplayer': 0,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'lastGamePlayed': null,
        });
        print('✅ User created in Firestore');
      } else {
        await userRef.update({
          'lastLogin': FieldValue.serverTimestamp(),
          'displayName': user.displayName,
          'photoURL': user.photoURL,
        });
      }
    } catch (e) {
      print('❌ Error creating/updating user: $e');
    }
  }

  // Shrani rezultat solo igre
  static Future<void> saveSoloGameResult({
    required int correct,
    required int total,
    required int score,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final gameRef = _firestore.collection('games').doc();

      // Preberi trenutne vrednosti
      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        print('❌ User document not found, creating...');
        await createUserIfNotExists();
      }

      final Map<String, dynamic> userData = userDoc.data() ?? {};

      final int currentPoints = userData['points'] ?? 0;
      final int currentTotalGames = userData['totalGames'] ?? 0;
      final int currentTotalCorrect = userData['totalCorrect'] ?? 0;
      final int currentTotalQuestions = userData['totalQuestions'] ?? 0;
      final int currentBestScore = userData['bestScore'] ?? 0;
      final int currentSoloGames =
          (userData['gamesPlayed'] as Map<String, dynamic>?)?['solo'] ?? 0;

      // Izračunaj nove vrednosti
      final int newTotalCorrect = currentTotalCorrect + correct;
      final int newTotalQuestions = currentTotalQuestions + total;
      final double newAverageAccuracy = (newTotalQuestions == 0)
          ? 0.0
          : (newTotalCorrect / newTotalQuestions * 100);

      // Shrani igro v history
      await gameRef.set({
        'userId': user.uid,
        'username': user.displayName ?? user.email?.split('@')[0],
        'correct': correct,
        'total': total,
        'score': score,
        'accuracy': total == 0 ? 0 : (correct / total * 100).round(),
        'mode': 'solo',
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
      });

      // Posodobi user statistiko - UPORABI FieldValue.increment za pravilno štetje
      await userRef.update({
        'points': FieldValue.increment(score),
        'totalGames': FieldValue.increment(1),
        'totalCorrect': FieldValue.increment(correct),
        'totalQuestions': FieldValue.increment(total),
        'averageAccuracy': newAverageAccuracy,
        'lastGamePlayed': FieldValue.serverTimestamp(),
        'gamesPlayed.solo': FieldValue.increment(1),
      });

      // Posodobi bestScore če je potrebno
      if (score > currentBestScore) {
        await userRef.update({'bestScore': score});
      }

      print('✅ Solo game saved to Firestore:');
      print('   Score: $score points');
      print('   Correct: $correct/$total');
      print('   New total games: ${currentTotalGames + 1}');
      print('   New total points: ${currentPoints + score}');
    } catch (e) {
      print('❌ Error saving solo game to Firestore: $e');
      rethrow;
    }
  }

  static Stream<QuerySnapshot> getActiveLobbies({
    int? minPlayers,
    int? maxPlayers,
  }) {
    Query query = _firestore
        .collection('lobbies')
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt', descending: true);

    if (minPlayers != null) {
      query = query.where('currentPlayers', isGreaterThanOrEqualTo: minPlayers);
    }
    if (maxPlayers != null) {
      query = query.where('maxPlayers', isLessThanOrEqualTo: maxPlayers);
    }

    return query.snapshots();
  }

  static Stream<QuerySnapshot> getOtherLobbies({
    int? minPlayers,
    int? maxPlayers,
  }) {
    Query query = _firestore
        .collection('lobbies')
        .where('status', isNotEqualTo: 'waiting')
        .orderBy('createdAt', descending: true);

    if (minPlayers != null) {
      query = query.where('currentPlayers', isGreaterThanOrEqualTo: minPlayers);
    }
    if (maxPlayers != null) {
      query = query.where('maxPlayers', isLessThanOrEqualTo: maxPlayers);
    }

    return query.snapshots();
  }

  static Future<void> saveMultiplayerGameResult({
    required String lobbyId,
    required int yourScore,
    required int opponentScore,
    required bool won,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final gameRef = _firestore.collection('games').doc();

      await gameRef.set({
        'userId': user.uid,
        'username': user.displayName ?? user.email?.split('@')[0],
        'yourScore': yourScore,
        'opponentScore': opponentScore,
        'won': won,
        'mode': 'multiplayer',
        'lobbyId': lobbyId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final userDoc = await userRef.get();
      final Map<String, dynamic>? userData = userDoc.data();

      await userRef.update({
        'points': FieldValue.increment(yourScore),
        'totalGames': FieldValue.increment(1),
        'lastGamePlayed': FieldValue.serverTimestamp(),
        'gamesPlayed.multiplayer': FieldValue.increment(1),
      });

      final multiplayerStats = userData?['multiplayerStats'] ??
          {
            'wins': 0,
            'losses': 0,
            'gamesPlayed': 0,
            'totalScore': 0,
            'winRate': 0.0,
          };

      final int newWins =
          (multiplayerStats['wins'] as int? ?? 0) + (won ? 1 : 0);
      final int newLosses =
          (multiplayerStats['losses'] as int? ?? 0) + (won ? 0 : 1);
      final int newGamesPlayed =
          (multiplayerStats['gamesPlayed'] as int? ?? 0) + 1;
      final int newTotalScore =
          (multiplayerStats['totalScore'] as int? ?? 0) + yourScore;
      final double newWinRate =
          newGamesPlayed == 0 ? 0.0 : (newWins / newGamesPlayed * 100);

      await userRef.update({
        'multiplayerStats.wins': newWins,
        'multiplayerStats.losses': newLosses,
        'multiplayerStats.gamesPlayed': newGamesPlayed,
        'multiplayerStats.totalScore': newTotalScore,
        'multiplayerStats.winRate': newWinRate,
      });

      // Posodobi bestScore če je potrebno
      if (yourScore > (userData?['bestScore'] ?? 0)) {
        await userRef.update({'bestScore': yourScore});
      }

      print('✅ Multiplayer game saved. Won: $won, Score: $yourScore');
    } catch (e) {
      print('❌ Error saving multiplayer game: $e');
    }
  }

  // LOBBY METODE

  // Ustvari nov lobby z izbiro števila igralcev
  static Future<String> createLobby(String lobbyName, int maxPlayers) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    // Preveri veljavnost števila igralcev
    if (maxPlayers < 2 || maxPlayers > 8) {
      throw Exception('Število igralcev mora biti med 2 in 8');
    }

    final lobbyRef = _firestore.collection('lobbies').doc();

    final lobbyData = {
      'id': lobbyRef.id,
      'name': lobbyName,
      'hostId': user.uid,
      'hostName': user.displayName ?? 'Unknown Player',
      'maxPlayers': maxPlayers,
      'currentPlayers': 1,
      'status': 'waiting',
      'players': {
        user.uid: {
          'uid': user.uid,
          'name': user.displayName ?? 'Unknown Player',
          'score': 0,
          'ready': true,
          'joinedAt': FieldValue.serverTimestamp(),
        }
      },
      'createdAt': FieldValue.serverTimestamp(),
      'currentQuestion': 0,
      'questions': [],
      'gameStarted': false,
      'roundDuration': 30,
    };

    await lobbyRef.set(lobbyData);
    return lobbyRef.id;
  }

  // Pridruži se lobbyju z transaction
  static Future<void> joinLobby(String lobbyId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    final lobbyRef = _firestore.collection('lobbies').doc(lobbyId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(lobbyRef);
      if (!snapshot.exists) throw Exception('Lobby ne obstaja');

      final data = snapshot.data() as Map<String, dynamic>;
      final currentPlayers = data['currentPlayers'] ?? 0;
      final maxPlayers = data['maxPlayers'] ?? 4;
      final status = data['status'] ?? 'waiting';
      final players = Map<String, dynamic>.from(data['players'] ?? {});

      // Preveri če je lobby poln
      if (currentPlayers >= maxPlayers) {
        throw Exception('Lobby je poln');
      }

      // Preveri če je igra že v teku
      if (status != 'waiting') {
        throw Exception('Igra je že v teku');
      }

      // Preveri če je igralec že v lobbyju
      if (players.containsKey(user.uid)) {
        throw Exception('Že ste v tem lobbyju');
      }

      // Dodaj igralca
      transaction.update(lobbyRef, {
        'currentPlayers': FieldValue.increment(1),
        'players.${user.uid}': {
          'uid': user.uid,
          'name': user.displayName ?? 'Unknown Player',
          'score': 0,
          'ready': false,
          'joinedAt': FieldValue.serverTimestamp(),
        }
      });
    });
  }

  // Zapusti lobby s transaction
  static Future<void> leaveLobby(String lobbyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final lobbyRef = _firestore.collection('lobbies').doc(lobbyId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(lobbyRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final players = Map<String, dynamic>.from(data['players'] ?? {});

      if (!players.containsKey(user.uid)) {
        return; // Igralec ni v tem lobbyju
      }

      // Odstrani igralca
      players.remove(user.uid);

      if (players.isEmpty) {
        // Če ni več igralcev, izbriši lobby
        transaction.delete(lobbyRef);
      } else {
        // Če je host zapustil lobby, določi novega hosta
        String newHostId = data['hostId'];
        if (newHostId == user.uid) {
          newHostId = players.keys.first;
          final newHost = players[newHostId];

          transaction.update(lobbyRef, {
            'currentPlayers': FieldValue.increment(-1),
            'hostId': newHostId,
            'hostName': newHost['name'],
            'players': players,
          });
        } else {
          transaction.update(lobbyRef, {
            'currentPlayers': FieldValue.increment(-1),
            'players': players,
          });
        }
      }
    });
  }

  // Toggle ready status
  static Future<void> toggleReady(String lobbyId, bool ready) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('lobbies').doc(lobbyId).update({
      'players.${user.uid}.ready': ready,
    });
  }

  // Začni igro
  static Future<void> startGame(
      String lobbyId, List<Map<String, dynamic>> questions) async {
    await _firestore.collection('lobbies').doc(lobbyId).update({
      'status': 'playing',
      'gameStarted': true,
      'questions': questions,
      'currentQuestion': 0,
      'roundStartedAt': FieldValue.serverTimestamp(),
    });
  }

  // Stream za posamezen lobby
  static Stream<DocumentSnapshot> lobbyStream(String lobbyId) {
    return _firestore.collection('lobbies').doc(lobbyId).snapshots();
  }

  // Posodobi rezultat igralca
  static Future<void> updatePlayerScore(String lobbyId, int score) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('lobbies').doc(lobbyId).update({
      'players.${user.uid}.score': FieldValue.increment(score),
    });
  }

  // Nastavi vprašanja za lobby
  static Future<void> setLobbyQuestions(
      String lobbyId, List<Map<String, dynamic>> questions) async {
    await FirebaseFirestore.instance.collection('lobbies').doc(lobbyId).update({
      'questions': questions,
      'status': 'playing',
      'gameStarted': true,
      'currentQuestion': 0,
      'roundStartedAt': FieldValue.serverTimestamp(),
      'roundDuration': 10,
    });
  }

  static Future<void> advanceToNextQuestion(String lobbyId, int currentQuestion,
      Map<String, dynamic> playerUpdates) async {
    await FirebaseFirestore.instance.collection('lobbies').doc(lobbyId).update({
      'currentQuestion': currentQuestion + 1,
      'roundStartedAt': FieldValue.serverTimestamp(),
      ...playerUpdates,
    });
  }

  // Pridobi lobby podatke
  static Future<Map<String, dynamic>?> getLobbyData(String lobbyId) async {
    final doc = await _firestore.collection('lobbies').doc(lobbyId).get();
    return doc.data();
  }

  // Stream za leaderboard
  static Stream<QuerySnapshot> leaderboardStream() {
    return _firestore
        .collection('users')
        .where('points', isGreaterThan: 0)
        .orderBy('points', descending: true)
        .limit(50)
        .snapshots();
  }

  // Stream za user statistiko
  static Stream<DocumentSnapshot> userStatsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  // Pridobi zgodovino iger
  static Stream<QuerySnapshot> gameHistoryStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('games')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();
  }

  // Pridobi multiplayer statistiko
  static Future<Map<String, dynamic>> getMultiplayerStats() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();

      return data?['multiplayerStats'] ??
          {
            'wins': 0,
            'losses': 0,
            'gamesPlayed': 0,
            'totalScore': 0,
            'winRate': 0.0,
          };
    } catch (e) {
      print('Error getting multiplayer stats: $e');
      return {};
    }
  }

  static String? get currentUserId {
    return _auth.currentUser?.uid;
  }

  // Debug metoda za izpis userjev
  static Future<void> printAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      print('Total users in database: ${snapshot.docs.length}');
      for (final doc in snapshot.docs) {
        print('User: ${doc.data()}');
      }
    } catch (e) {
      print('Error printing users: $e');
    }
  }
}
