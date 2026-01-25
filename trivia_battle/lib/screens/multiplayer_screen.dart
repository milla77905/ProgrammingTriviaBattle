import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lobby_screen.dart';

class MultiplayerScreen extends StatefulWidget {
  const MultiplayerScreen({super.key});

  @override
  State<MultiplayerScreen> createState() => _MultiplayerScreenState();
}

class _MultiplayerScreenState extends State<MultiplayerScreen> {
  final TextEditingController _lobbyNameController = TextEditingController();
  final Set<String> _joiningLobbies = {};
  int _selectedPlayers = 4;
  bool _isLoading = false;

  static const Color bgDark = Color(0xFF0E0E11);
  static const Color bgCard = Color(0xFF1A1A22);
  static const Color accent = Color(0xFF7C7CFF);

  @override
  void dispose() {
    _lobbyNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Multiplayer',
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// CREATE LOBBY CARD
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.15),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Lobby',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),

                  /// LOBBY NAME
                  TextField(
                    controller: _lobbyNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Lobby name',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon:
                          const Icon(Icons.videogame_asset, color: accent),
                      filled: true,
                      fillColor: bgDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// PLAYER COUNT
                  const Text(
                    'Max players',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [2, 3, 4, 5, 6, 7, 8].map((players) {
                      final selected = _selectedPlayers == players;
                      return ChoiceChip(
                        label: Text('$players'),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _selectedPlayers = players;
                          });
                        },
                        selectedColor: accent,
                        backgroundColor: bgDark,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  /// CREATE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isLoading ? null : _createLobby,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Lobby'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// LOBBIES TITLE
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Available Lobbies',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),

            /// LOBBY LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('lobbies')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: accent),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No lobbies available',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  final waitingLobbies = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['status'] == 'waiting';
                  }).toList();

                  return ListView.builder(
                    itemCount: waitingLobbies.length,
                    itemBuilder: (context, index) {
                      final lobby = waitingLobbies[index];
                      final data = lobby.data() as Map<String, dynamic>;

                      final lobbyId = lobby.id;
                      final isJoining = _joiningLobbies.contains(lobbyId);

                      final currentPlayers = data['currentPlayers'] ?? 0;
                      final maxPlayers = data['maxPlayers'] ?? 4;
                      final isFull = currentPlayers >= maxPlayers;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bgCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.groups_rounded,
                                color: accent, size: 30),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name'] ?? 'Lobby',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Host: ${data['hostName'] ?? 'Host'}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$currentPlayers / $maxPlayers players',
                                    style: TextStyle(
                                      color: isFull
                                          ? Colors.redAccent
                                          : Colors.greenAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            /// JOIN BUTTON
                            isFull
                                ? const Text(
                                    'FULL',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: isJoining
                                        ? null
                                        : () => _joinLobby(lobbyId),
                                    child: isJoining
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Join',
                                            style: TextStyle(
                                                color: Color.fromARGB(
                                                    255, 237, 237, 240)),
                                          ),
                                  )
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createLobby() async {
    final name = _lobbyNameController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (name.isEmpty || user == null) return;

    setState(() => _isLoading = true);

    try {
      final lobbyRef = FirebaseFirestore.instance.collection('lobbies').doc();

      await lobbyRef.set({
        'id': lobbyRef.id,
        'name': name,
        'hostId': user.uid,
        'hostName': user.displayName ?? 'Player',
        'maxPlayers': _selectedPlayers,
        'currentPlayers': 1,
        'status': 'waiting',
        'players': {
          user.uid: {
            'uid': user.uid,
            'name': user.displayName ?? 'Player',
            'score': 0,
            'ready': true,
            'joinedAt': FieldValue.serverTimestamp(),
          }
        },
        'createdAt': FieldValue.serverTimestamp(),
        'gameStarted': false,
        'currentQuestion': 0,
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(lobbyId: lobbyRef.id),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinLobby(String lobbyId) async {
    setState(() => _joiningLobbies.add(lobbyId));

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final lobbyRef =
          FirebaseFirestore.instance.collection('lobbies').doc(lobbyId);

      await lobbyRef.update({
        'currentPlayers': FieldValue.increment(1),
        'players.${user.uid}': {
          'uid': user.uid,
          'name': user.displayName ?? 'Player',
          'score': 0,
          'ready': false,
          'joinedAt': FieldValue.serverTimestamp(),
        }
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(lobbyId: lobbyId),
        ),
      );
    } finally {
      setState(() => _joiningLobbies.remove(lobbyId));
    }
  }
}
