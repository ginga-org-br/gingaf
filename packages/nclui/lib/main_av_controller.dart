import 'package:flutter/material.dart';

class MainAVController extends ChangeNotifier {
  String? _uri;
  bool _isPlaying = true;

  String? get uri => _uri;
  bool get isPlaying => _isPlaying;

  void setMainAvUri(String? val) {
    if (_uri != val) {
      _uri = val;
      notifyListeners();
    }
  }

  void play() {
    if (!_isPlaying) {
      _isPlaying = true;
      notifyListeners();
    }
  }

  void stop() {
    if (_isPlaying) {
      _isPlaying = false;
      notifyListeners();
    }
  }
}
