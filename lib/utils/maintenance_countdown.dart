import 'dart:async';

import 'package:flutter/material.dart';

class MaintenanceCountdown extends StatefulWidget {
  final DateTime maintenanceTime;

  MaintenanceCountdown({Key? key, required this.maintenanceTime}) : super(key: key);

  @override
  _MaintenanceCountdownState createState() => _MaintenanceCountdownState();
}

class _MaintenanceCountdownState extends State<MaintenanceCountdown> {
  Timer? _timer;
  Duration _duration = Duration();

  @override
  void initState() {
    super.initState();
    _duration = widget.maintenanceTime.difference(DateTime.now());
    _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      if (_duration.inSeconds > 0) {
        setState(() {
          _duration -= Duration(seconds: 1);
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitHours = twoDigits(duration.inHours);
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDuration(_duration),
      style: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }
}
