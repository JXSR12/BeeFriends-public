import 'dart:async';

import 'package:BeeFriends/chats_page.dart';
import 'package:BeeFriends/main.dart';
import 'package:BeeFriends/match_requests_page.dart';
import 'package:BeeFriends/profile_page.dart';
import 'package:BeeFriends/utils/common_bottom_app_bar.dart';
import 'package:BeeFriends/utils/display_utils.dart';
import 'package:BeeFriends/utils/inapp_notification_body.dart';
import 'package:BeeFriends/utils/maintenance_countdown.dart';
import 'package:BeeFriends/utils/notification_controller.dart';
import 'package:BeeFriends/utils/notification_manager.dart';
import 'package:BeeFriends/utils/starbees_section.dart';
import 'package:BeeFriends/utils/tips_carousel.dart';
import 'package:BeeFriends/utils/user_provider.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:animated_button_bar/animated_button_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'login_page.dart';
import 'main_page.dart';
import 'notifications_log_page.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  late CompleteUser? currentUser = null;

  Duration _duration = Duration();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newUser = UserProviderState.userOf(context);
    if (newUser != currentUser) {
      setState(() {
        currentUser = newUser;
      });
    }
  }

  final TextEditingController _confessionController = TextEditingController();

  static final Config config = Config(
      tenant: 'common',
      clientId: 'b89cc19d-4587-4170-9b80-b39204b74380',
      scope: 'openid profile offline_access User.Read',
      redirectUri: 'https://beefriends-a1c17.firebaseapp.com/__/auth/handler',
      navigatorKey: navigatorKey,
      loader: SizedBox());
  final AadOAuth oauth = AadOAuth(config);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkLoginStatus();
    }
  }

  void _checkLoginStatus() async {
    bool isLoggedIn = await oauth.hasCachedAccountInformation;
    print('Is logged in? $isLoggedIn');
    if (!isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginPage(
            onUserLoggedIn: () {
              navigatorKey.currentState?.pushReplacement(
                  MaterialPageRoute(builder: (context) => Home()));
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .doc('/globalPlatformState/scheduledMaintenances')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(); // No data found
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        bool isActive = data['active'] ?? false;
        Timestamp nextTimestamp = data['nextTimestamp'];
        DateTime maintenanceTime = DateTime.now();
        if (isActive) {
          maintenanceTime = nextTimestamp.toDate();
          _duration = maintenanceTime.difference(DateTime.now());
          if (_duration.isNegative) {
            _duration = Duration.zero;
          }
        }

        return
          SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (isActive) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10),
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.redAccent, // A color to indicate caution
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning, color: Colors.white), // Danger icon
                        SizedBox(width: 8),
                        Text(
                          'Platform will undergo maintenance in',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    MaintenanceCountdown(maintenanceTime: maintenanceTime),
                    SizedBox(height: 8),
                    Text(
                      'You will be unable to access the app when it occurs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.green, Colors.green.shade700],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'Welcome, ${currentUser?.displayName}',
                        textAlign: TextAlign.center, // Centers the text inside the container
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(1.0, 1.0),
                              blurRadius: 3.0,
                              color: Colors.deepPurple.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  StarbeesSection(currentUser: currentUser!),
                  SizedBox(height: 5),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => NotificationsLogPage(),
                      ));
                    },
                    child: Container(
                      padding: EdgeInsets.all(2),
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green[50], // Lighter shade for background
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3), // Soft shadow with a tint of the accent color
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: Offset(0, 3), // changes position of shadow
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Icon(Icons.notifications, size: 36, color: Colors.green[600]), // Accent color for the icon
                        title: Text(
                          'View notifications history',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800], // Darker shade for text
                          ),
                        ),
                        subtitle: Text(
                          'Don\'t miss out on important things',
                          style: TextStyle(
                            color: Colors.green[500], // Accent color for subtitle
                          ),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, color: Colors.green[400]), // Accent color for the arrow
                      ),
                    ),
                  ),
                  SizedBox(height: 5),
                  TipsCarousel(),
                  SizedBox(height: 20),
                ],
              ),
            )
          ],
        ));
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitHours = twoDigits(duration.inHours);
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
  }
}
