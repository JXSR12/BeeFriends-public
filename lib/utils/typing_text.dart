import 'package:flutter/material.dart';
import 'dart:async';

class TypingText extends StatefulWidget {
  final double fontSize;
  final List<Color> colors;

  TypingText({required this.fontSize, required this.colors});

  @override
  _TypingTextState createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  Timer? _timer;
  Timer? _wordTimer;
  List<String> words = ["match", "partner", "friend", "someone", "buddy", "mate", "pal"];
  int wordIndex = 0;
  int charIndex = 0;
  bool isBackspacing = false;

  @override
  void initState() {
    super.initState();
    _startWordTimer(Duration(seconds: 3));
  }

  void _startWordTimer(Duration duration) {
    _wordTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          isBackspacing = !isBackspacing;
        });
        if (!isBackspacing) {
          wordIndex = (wordIndex + 1) % words.length;
          charIndex = 0;
          _timer?.cancel(); // Cancel existing timer
          _timer = Timer.periodic(Duration(milliseconds: 100), _typeEffect);
          _startWordTimer(Duration(seconds: 3));
        } else {
          _timer?.cancel(); // Cancel existing timer
          _timer = Timer.periodic(Duration(milliseconds: 100), _typeEffect);
          _startWordTimer(Duration(seconds: 1));
        }
      }
    });
  }

  void _typeEffect(Timer timer) {
    if (mounted) {
      setState(() {
        if (isBackspacing) {
          if (charIndex == 0) {
            _timer?.cancel();
          } else {
            charIndex--;
          }
        } else {
          if (charIndex < words[wordIndex].length) {
            charIndex++;
          } else {
            _timer?.cancel();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wordTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      words[wordIndex].substring(0, charIndex),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: widget.fontSize,
        color: widget.colors[wordIndex % widget.colors.length],
      ),
    );
  }
}
