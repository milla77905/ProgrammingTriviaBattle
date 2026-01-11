import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quiz_provider.dart';

class SoloQuiz extends StatefulWidget {
  const SoloQuiz({super.key});

  @override
  _SoloQuizState createState() => _SoloQuizState();
}

class _SoloQuizState extends State<SoloQuiz>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _answerSelected = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );

    _controller.addListener(() {
      if (_controller.isCompleted && !_answerSelected) {
        _nextQuestion();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<QuizProvider>(context, listen: false);
      if (!provider.gameFinished) {
        await provider.startSoloGame();
        _controller.forward(from: 0.0);
      }
    });
  }

  void _nextQuestion() {
    final provider = Provider.of<QuizProvider>(context, listen: false);
    if (!provider.gameFinished) {
      provider.nextQuestion();
      _answerSelected = false;
      _controller.reset();
      if (provider.hasMoreQuestions && !provider.gameFinished) {
        _controller.forward();
      } else if (provider.gameFinished) {
        _showResults();
      }
    }
  }

  void _showResults() {
    final provider = Provider.of<QuizProvider>(context, listen: false);
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kviz končan!'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tvoj rezultat: ${provider.score} točk',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Text(
                    'Pravilnih odgovorov: ${provider.correctAnswers}/${provider.totalQuestions}',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 6),
                Text(
                    'Natančnost: ${((provider.correctAnswers / provider.totalQuestions) * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                const Text('Rezultat je bil shranjen v statistiko!',
                    style: TextStyle(fontSize: 14, color: Colors.green)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Nazaj na menu'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewGame();
            },
            child: const Text('Nova igra'),
          ),
        ],
      ),
    );
  }

  Future<void> _startNewGame() async {
    final provider = Provider.of<QuizProvider>(context, listen: false);
    provider.resetGame();
    await provider.startSoloGame();
    _answerSelected = false;
    _controller.reset();
    _controller.forward();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuizProvider>(
      builder: (context, provider, child) {
        final question = provider.currentQuestion;

        if (provider.gameFinished) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Kviz končan'),
              backgroundColor: Colors.blue.shade700,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, size: 70, color: Colors.amber),
                    const SizedBox(height: 16),
                    const Text(
                      'Bravo!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tvoj rezultat: ${provider.score} točk',
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pravilnih: ${provider.correctAnswers}/${provider.totalQuestions}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Nova igra'),
                      onPressed: () => _startNewGame(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Nazaj na menu'),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (question == null) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Nalagam vprašanja...'),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Solo Kviz'),
            backgroundColor: Colors.blue.shade700,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Točke: ${provider.score}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Vprašanje ${provider.currentQuestionIndex + 1}/${provider.totalQuestions}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Pravilnih: ${provider.correctAnswers}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                LinearProgressIndicator(
                  value: _controller.value,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${(30 * (1 - _controller.value)).toInt()}s',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      question.question,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Options
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.3,
                    children: question.options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      return ElevatedButton(
                        onPressed: _answerSelected
                            ? null
                            : () {
                                setState(() {
                                  _answerSelected = true;
                                });
                                provider.answerQuestion(index);

                                if (!provider.hasMoreQuestions) {
                                  Future.delayed(
                                      const Duration(milliseconds: 500), () {
                                    _nextQuestion();
                                  });
                                } else {
                                  Future.delayed(
                                      const Duration(milliseconds: 1200), () {
                                    _nextQuestion();
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _answerSelected
                              ? (index == question.correctIndex
                                  ? Colors.green.shade100
                                  : Colors.red.shade100)
                              : Colors.blue.shade50,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(12),
                          elevation: 1,
                        ),
                        child: Text(
                          option,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Next button
                if (_answerSelected && provider.hasMoreQuestions)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Naslednje vprašanje'),
                      onPressed: () {
                        _nextQuestion();
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
