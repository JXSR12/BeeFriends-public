import 'dart:async';
import 'package:BeeFriends/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:microsoft_graph_api/models/user/user_model.dart' as MSGUser;

class UserProvider extends StatefulWidget {
  final CompleteUser? initialUser;
  final Widget child;

  UserProvider({Key? key, required this.initialUser, required this.child})
      : super(key: key);

  @override
  UserProviderState createState() => UserProviderState();

  static UserProviderState of(BuildContext context) {
    final _UserProviderInherited? result = context.dependOnInheritedWidgetOfExactType<_UserProviderInherited>();
    assert(result != null, 'No UserProvider found in context');
    return context.findAncestorStateOfType<UserProviderState>()!;
  }
}

class _UserProviderInherited extends InheritedWidget {
  final CompleteUser? user;

  _UserProviderInherited({Key? key, required this.user, required Widget child})
      : super(key: key, child: child);

  @override
  bool updateShouldNotify(covariant _UserProviderInherited oldWidget) {
    return oldWidget.user != user;
  }
  static _UserProviderInherited? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_UserProviderInherited>();
  }
}

class UserProviderState extends State<UserProvider> {
  CompleteUser? user;
  StreamSubscription? _userSubscription;

  @override
  void initState() {
    super.initState();
    user = widget.initialUser;
    _listenToUserChanges();
  }

  static CompleteUser? userOf(BuildContext context) {
    return _UserProviderInherited.of(context)?.user;
  }

  _listenToUserChanges() {
    if (widget.initialUser?.id != null) {
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.initialUser!.id)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

          Map<String, dynamic>? picturesMap = data['pictures'] as Map<String, dynamic>?;
          String? defaultPicture = picturesMap?['default'];
          List<String>? otherPictures = List<String>.from(picturesMap?['others'] ?? []);

          CompleteUser updatedUser = CompleteUser(
            displayName: data['name'],
            email: data['email'],
            id: data['id'],
            birthDate: data['birthDate'],
            description: data['description'],
            gender: data['gender'],
            height: data['height'],
            interests: data['interests'],
            lookingFor: data['lookingFor'],
            major: data['major'],
            religion: data['religion'],
            campus: data['campus'],
            studentNumber: data['studentNumber'],
            defaultPicture: defaultPicture,
            otherPictures: otherPictures,
            beets: (data['beets'] as num).toInt(),
            accountType: data['accountType']
          );

          setState(() {
            user = updatedUser;
            print(user?.displayName);
          });
        }
      });
    }
  }

  String? getUserId(){
    return user?.id;
  }

  void setUserId(String newUserId) {
    _userSubscription?.cancel();

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(newUserId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

        Map<String, dynamic>? picturesMap = data['pictures'] as Map<String, dynamic>?;
        String? defaultPicture = picturesMap?['default'];
        List<String>? otherPictures = List<String>.from(picturesMap?['others'] ?? []);

        CompleteUser updatedUser = CompleteUser(
          displayName: data['name'],
          email: data['email'],
          id: data['id'],
          birthDate: data['birthDate'],
          description: data['description'],
          gender: data['gender'],
          height: data['height'],
          interests: data['interests'],
          lookingFor: data['lookingFor'],
          major: data['major'],
          religion: data['religion'],
          campus: data['campus'],
          studentNumber: data['studentNumber'],
          defaultPicture: defaultPicture,
          otherPictures: otherPictures,
          beets: (data['beets'] as num).toInt(),
          accountType: data['accountType']
        );

        setState(() {
          user = updatedUser; // Use the state variable
        });
      }
    });
  }


  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _UserProviderInherited(
      user: user,
      child: widget.child,
    );
  }
}
