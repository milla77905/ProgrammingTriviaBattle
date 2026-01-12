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

  // Shrani multiplayer rezultat
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

      // Posodobi multiplayer statistiko
      final userDoc = await userRef.get();
      final Map<String, dynamic>? userData = userDoc.data();

      final Map<String, dynamic> multiplayerStats =
          userData?['multiplayerStats'] ??
              {
                'wins': 0,
                'losses': 0,
                'gamesPlayed': 0,
                'totalScore': 0,
                'winRate': 0.0,
              };

      final int newWins = multiplayerStats['wins'] + (won ? 1 : 0);
      final int newLosses = multiplayerStats['losses'] + (won ? 0 : 1);
      final int newGamesPlayed = multiplayerStats['gamesPlayed'] + 1;
      final double newWinRate =
          newGamesPlayed == 0 ? 0.0 : (newWins / newGamesPlayed * 100);

      await userRef.update({
        'points': FieldValue.increment(yourScore),
        'totalGames': FieldValue.increment(1),
        'lastGamePlayed': FieldValue.serverTimestamp(),
        'gamesPlayed.multiplayer': FieldValue.increment(1),
        'multiplayerStats.wins': newWins,
        'multiplayerStats.losses': newLosses,
        'multiplayerStats.gamesPlayed': newGamesPlayed,
        'multiplayerStats.totalScore': FieldValue.increment(yourScore),
        'multiplayerStats.winRate': newWinRate,
        'bestScore': yourScore > (userData?['bestScore'] ?? 0)
            ? yourScore
            : FieldValue.increment(0),
      });

      print(
          '✅ Multiplayer game saved: You ${won ? 'won' : 'lost'} with $yourScore points');
    } catch (e) {
      print('❌ Error saving multiplayer game: $e');
      rethrow;
    }
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
