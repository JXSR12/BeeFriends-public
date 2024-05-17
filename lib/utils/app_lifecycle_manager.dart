import 'package:flutter/material.dart';

class AppLifecycleManager with WidgetsBindingObserver {
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();

  late AppLifecycleState _lastLifecycleState;

  AppLifecycleManager._internal();

  factory AppLifecycleManager() {
    return _instance;
  }

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
  }

  bool isAppInForeground() {
    return _lastLifecycleState == AppLifecycleState.resumed;
  }
}
