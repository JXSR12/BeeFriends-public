import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NicknameManager {
  static Map<String, String> _nicknameCache = {};

  static Future<void> initialize(String userId) async {
    _nicknameCache = {};

    final prefs = await SharedPreferences.getInstance();
    final storedNicknames = prefs.getString('nicknames') ?? '{}';
    _nicknameCache = Map<String, String>.from(json.decode(storedNicknames));

    // Fetch nicknames from Firestore if cache is empty
    if (_nicknameCache.isEmpty) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('userNicknames')
          .doc(userId)
          .collection('matches')
          .get();

      for (var doc in querySnapshot.docs) {
        _nicknameCache[doc.id] = doc.data()['nickname'] ?? '';
      }

      // Store nicknames in shared preferences
      await prefs.setString('nicknames', json.encode(_nicknameCache));
    }
  }

  static String getNickname(String matchId, String ifNotExistPlaceholder) {
    print("Trying to get nick for $matchId: ${_nicknameCache[matchId] != null ? '~${_nicknameCache[matchId]}' : 'not found'}");
    return _nicknameCache[matchId] != null ? '~${_nicknameCache[matchId]}' : ifNotExistPlaceholder;
  }

  static Future<void> setNickname(String userId, String matchId, String nickname) async {
    await FirebaseFirestore.instance
        .collection('userNicknames')
        .doc(userId)
        .collection('matches')
        .doc(matchId)
        .set({'nickname': nickname});

    _nicknameCache[matchId] = nickname;

    // Update shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nicknames', json.encode(_nicknameCache));
  }

  static Future<void> deleteNickname(String userId, String matchId) async {
    await FirebaseFirestore.instance
        .collection('userNicknames')
        .doc(userId)
        .collection('matches')
        .doc(matchId)
        .delete();

    _nicknameCache.remove(matchId);

    // Update shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nicknames', json.encode(_nicknameCache));
  }
}
