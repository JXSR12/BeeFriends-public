import 'dart:async';
import 'package:flutter/material.dart';

class CountdownTimer extends StatefulWidget {
  final Future<Duration> remainingTime;
  final VoidCallback? onCountdownCompleted;

  const CountdownTimer({
    Key? key,
    required this.remainingTime,
    this.onCountdownCompleted,
  }) : super(key: key);

  @override
  _CountdownTimerState createState() => _CountdownTimerState();
}


class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _timer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    // Fetch the remaining time initially
    widget.remainingTime.then((remaining) {
      setState(() {
        _duration = remaining;
      });

      // Update the countdown every second
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_duration.inSeconds == 0) {
          timer.cancel();
          widget.onCountdownCompleted?.call(); // Notify the parent widget
        } else {
          setState(() {
            _duration -= Duration(seconds: 1);
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Format the duration as HH:mm:ss
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(_duration.inHours);
    final minutes = twoDigits(_duration.inMinutes.remainder(60));
    final seconds = twoDigits(_duration.inSeconds.remainder(60));

    return Text('$hours:$minutes:$seconds', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),);
  }
}
