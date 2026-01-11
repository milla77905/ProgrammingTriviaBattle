import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';
import '../services/firestore_service.dart';

class Question {
  final String question;
  final List<String> options;
  final int correctIndex;

  Question({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

class QuizProvider with ChangeNotifier {
  List<Question> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int _correctAnswers = 0;
  List<bool> _answers = [];
  bool _gameFinished = false;

  List<Question> get questions => _questions;
  Question? get currentQuestion =>
      _questions.isNotEmpty ? _questions[_currentIndex] : null;
  int get currentQuestionIndex => _currentIndex;
  int get totalQuestions => _questions.length;
  int get score => _score;
  int get correctAnswers => _correctAnswers;
  bool get hasMoreQuestions => _currentIndex < _questions.length - 1;
  bool get gameFinished => _gameFinished;

  final HtmlUnescape _unescape = HtmlUnescape();

  Future<void> fetchQuestionsFromApi({int amount = 10}) async {
    try {
      _gameFinished = false;
      final url = Uri.parse(
          'https://opentdb.com/api.php?amount=$amount&category=18&type=multiple');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _questions = (data['results'] as List).map((item) {
          final incorrect = List<String>.from(item['incorrect_answers'])
              .map((e) => _unescape.convert(e))
              .toList();
          final correct = _unescape.convert(item['correct_answer'] as String);
          final allOptions = List<String>.from(incorrect)..add(correct);
          allOptions.shuffle();
          return Question(
            question: _unescape.convert(item['question']),
            options: allOptions,
            correctIndex: allOptions.indexOf(correct),
          );
        }).toList();
        _currentIndex = 0;
        _score = 0;
        _correctAnswers = 0;
        _answers = [];
        notifyListeners();
      } else {
        throw Exception('Failed to fetch questions');
      }
    } catch (e) {
      print('Error fetching questions: $e');
      rethrow;
    }
  }

  Future<void> startSoloGame() async {
    await fetchQuestionsFromApi();
  }

  void answerQuestion(int selectedIndex) {
    if (currentQuestion == null || _gameFinished) return;

    final isCorrect = selectedIndex == currentQuestion!.correctIndex;
    _answers.add(isCorrect);

    if (isCorrect) {
      _score += 10;
      _correctAnswers += 1;
    }

    if (!hasMoreQuestions) {
      _gameFinished = true;
      _saveGameToFirebase();
    }

    notifyListeners();
  }

  void nextQuestion() {
    if (hasMoreQuestions && !_gameFinished) {
      _currentIndex += 1;
      notifyListeners();
    } else if (!_gameFinished) {
      _gameFinished = true;
      _saveGameToFirebase();
      notifyListeners();
    }
  }

  Future<void> _saveGameToFirebase() async {
    if (_questions.isEmpty || (_score == 0 && _correctAnswers == 0)) {
      print('No game data to save');
      return;
    }

    try {
      await FirestoreService.saveSoloGameResult(
        correct: _correctAnswers,
        total: _questions.length,
        score: _score,
      );
      print(
          '✅ Game saved to Firestore: $_score points, $_correctAnswers/${_questions.length} correct');
    } catch (e) {
      print('❌ Error saving game to Firebase: $e');
    }
  }

  void resetGame() {
    _questions = [];
    _currentIndex = 0;
    _score = 0;
    _correctAnswers = 0;
    _answers = [];
    _gameFinished = false;
    notifyListeners();
  }

  double getCurrentGameAccuracy() {
    if (_answers.isEmpty) return 0.0;
    final correct = _answers.where((a) => a).length;
    return (correct / _answers.length * 100);
  }
}
