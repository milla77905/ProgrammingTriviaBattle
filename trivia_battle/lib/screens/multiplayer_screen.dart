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

  @override
  void dispose() {
    _lobbyNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _lobbyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Ime Lobbyja',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.videogame_asset),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Število igralcev:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [2, 3, 4, 5, 6, 7, 8].map((players) {
                            return ChoiceChip(
                              label: Text('$players'),
                              selected: _selectedPlayers == players,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedPlayers = players;
                                });
                              },
                              selectedColor: Colors.blue.shade200,
                              labelStyle: TextStyle(
                                color: _selectedPlayers == players
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _createLobby,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Ustvari Lobby'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Text(
                  'Vsi Lobbyji:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('lobbies')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_off,
                            size: 50,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          const Text('Ni lobbyjev'),
                          const SizedBox(height: 5),
                          Text(
                            'Ustvari prvega!',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }

                  final lobbies = snapshot.data!.docs;

                  final waitingLobbies = lobbies.where((lobby) {
                    final data = lobby.data() as Map<String, dynamic>;
                    return data['status'] == 'waiting';
                  }).toList();

                  return ListView.builder(
                    itemCount: waitingLobbies.length,
                    itemBuilder: (context, index) {
                      final lobby = waitingLobbies[index];
                      final data = lobby.data() as Map<String, dynamic>;
                      final lobbyId = lobby.id;
                      final lobbyName = data['name'] ?? 'Lobby';
                      final hostName = data['hostName'] ?? 'Host';
                      final currentPlayers = data['currentPlayers'] ?? 0;
                      final maxPlayers = data['maxPlayers'] ?? 4;
                      final isJoining = _joiningLobbies.contains(lobbyId);
                      final isFull = currentPlayers >= maxPlayers;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: const Icon(Icons.group, color: Colors.blue),
                          ),
                          title: Text(lobbyName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Host: $hostName'),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 16,
                                    color: isFull ? Colors.red : Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$currentPlayers/$maxPlayers igralcev',
                                    style: TextStyle(
                                      color: isFull ? Colors.red : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: isFull
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Polno',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: isJoining
                                      ? null
                                      : () => _joinLobby(lobbyId),
                                  child: isJoining
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Text('Pridruži se'),
                                ),
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
    final lobbyName = _lobbyNameController.text.trim();
    if (lobbyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vnesite ime lobbyja')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prijavite se')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final lobbyRef = FirebaseFirestore.instance.collection('lobbies').doc();

      final lobbyData = {
        'id': lobbyRef.id,
        'name': lobbyName,
        'hostId': user.uid,
        'hostName': user.displayName ?? 'Igralec',
        'maxPlayers': _selectedPlayers,
        'currentPlayers': 1,
        'status': 'waiting',
        'players': {
          user.uid: {
            'uid': user.uid,
            'name': user.displayName ?? 'Igralec',
            'score': 0,
            'ready': true,
            'joinedAt': FieldValue.serverTimestamp(),
          }
        },
        'createdAt': FieldValue.serverTimestamp(),
        'questions': [],
        'gameStarted': false,
        'currentQuestion': 0,
      };

      await lobbyRef.set(lobbyData);

      _lobbyNameController.clear();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyScreen(lobbyId: lobbyRef.id),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Napaka: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinLobby(String lobbyId) async {
    setState(() {
      _joiningLobbies.add(lobbyId);
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final lobbyRef =
          FirebaseFirestore.instance.collection('lobbies').doc(lobbyId);

      final lobbyDoc = await lobbyRef.get();
      if (!lobbyDoc.exists) {
        throw Exception('Lobby ne obstaja');
      }

      final data = lobbyDoc.data()!;
      final currentPlayers = data['currentPlayers'] ?? 0;
      final maxPlayers = data['maxPlayers'] ?? 4;
      final status = data['status'] ?? 'waiting';

      if (currentPlayers >= maxPlayers) {
        throw Exception('Lobby je poln');
      }

      if (status != 'waiting') {
        throw Exception('Igra je že v teku');
      }

      // Dodaj igralca
      await lobbyRef.update({
        'currentPlayers': FieldValue.increment(1),
        'players.${user.uid}': {
          'uid': user.uid,
          'name': user.displayName ?? 'Igralec',
          'score': 0,
          'ready': false,
          'joinedAt': FieldValue.serverTimestamp(),
        }
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyScreen(lobbyId: lobbyId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Napaka: $e')),
      );
    } finally {
      setState(() {
        _joiningLobbies.remove(lobbyId);
      });
    }
  }
}
