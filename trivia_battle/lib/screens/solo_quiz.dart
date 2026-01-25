import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quiz_provider.dart';

class SoloQuiz extends StatefulWidget {
  const SoloQuiz({super.key});

  @override
  State<SoloQuiz> createState() => _SoloQuizState();
}

class _SoloQuizState extends State<SoloQuiz>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _answerSelected = false;
  int? _selectedIndex;

  static const Color bgDark = Color(0xFF0E0E11);
  static const Color bgCard = Color(0xFF1A1A22);
  static const Color accent = Color(0xFF7C7CFF);

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 30))
          ..addListener(() {
            if (_controller.isCompleted && !_answerSelected) {
              _nextQuestion();
            }
          });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<QuizProvider>();
      await provider.startSoloGame();
      _controller.forward(from: 0);
    });
  }

  void _nextQuestion() {
    final provider = context.read<QuizProvider>();
    _selectedIndex = null;
    _answerSelected = false;
    _controller.reset();

    if (provider.hasMoreQuestions) {
      provider.nextQuestion();
      _controller.forward();
      setState(() {});
    } else {
      _showResults();
    }
  }

  void _showResults() {
    final provider = context.read<QuizProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: bgCard,
        title: const Text(
          'Quiz Finished',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Score: ${provider.score}',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Correct answers: ${provider.correctAnswers}/${provider.totalQuestions}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'Accuracy: ${((provider.correctAnswers / provider.totalQuestions) * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Back to menu'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuizProvider>(
      builder: (_, provider, __) {
        final question = provider.currentQuestion;

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
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Solo Quiz',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: accent,
              ),
            ),
          ),
          body: question == null
              ? const Center(
                  child: CircularProgressIndicator(color: accent),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      /// HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Question ${provider.currentQuestionIndex + 1}/${provider.totalQuestions}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            '${(30 * (1 - _controller.value)).toInt()}s',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      /// TIMER BAR
                      LinearProgressIndicator(
                        value: _controller.value,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(accent),
                      ),
                      const SizedBox(height: 20),

                      /// QUESTION
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: bgCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          question.question,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      /// SCORE (centered, subtle but visible)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: bgCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accent.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          'Score: ${provider.score}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const SizedBox(height: 20),

                      /// ANSWERS
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.25,
                          children:
                              question.options.asMap().entries.map((entry) {
                            final index = entry.key;
                            final option = entry.value;

                            Color bgColor = bgCard;

                            if (_answerSelected) {
                              if (index == question.correctIndex) {
                                bgColor = Colors.green.shade700;
                              } else if (index == _selectedIndex) {
                                bgColor = Colors.red.shade700;
                              }
                            }

                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _answerSelected
                                  ? null
                                  : () {
                                      setState(() {
                                        _answerSelected = true;
                                        _selectedIndex = index;
                                      });

                                      provider.answerQuestion(index);

                                      Future.delayed(
                                        const Duration(milliseconds: 1200),
                                        _nextQuestion,
                                      );
                                    },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    option,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
