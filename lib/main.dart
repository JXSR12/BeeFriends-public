import 'dart:io';

import 'package:BeeFriends/main_page.dart';
import 'package:BeeFriends/utils/app_lifecycle_manager.dart';
import 'package:BeeFriends/utils/nickname_manager.dart';
import 'package:BeeFriends/utils/notification_controller.dart';
import 'package:BeeFriends/utils/notification_manager.dart';
import 'package:BeeFriends/utils/user_provider.dart';
import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_notification/in_app_notification.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:purchases_flutter/models/purchases_configuration.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'package:flutter/services.dart';

class CompleteUser {
  final String? displayName;
  final String? email;
  final String? id;
  final String? birthDate;
  final String? description;
  final String? gender;
  final String? height;
  final String? interests;
  final int? lookingFor;
  final String? major;
  final String? religion;
  final String? studentNumber;
  final String? campus;
  final String? defaultPicture;
  final List<String>? otherPictures;
  final int? beets;
  final String? accountType;

  CompleteUser({
    this.displayName,
    this.email,
    this.id,
    this.birthDate,
    this.description,
    this.gender,
    this.height,
    this.interests,
    this.lookingFor,
    this.major,
    this.religion,
    this.studentNumber,
    this.campus,
    this.defaultPicture,
    this.otherPictures,
    this.beets,
    this.accountType
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLifecycleManager().initialize();
  runApp(BeeFriends(
    onUserLoggedIn: () {
      navigatorKey.currentState?.pushReplacement(MaterialPageRoute(builder: (context) => MainPage()));
    },
  ));

  FlutterError.onError = (details) {
  };
}

Future<void> initApp() async {
  // final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
  // if (Platform.isIOS) {
  //   print('Platform is iOS, trying to get APNS Token');

  //   if (apnsToken != null) {
  //     final notificationSettings = await AwesomeNotifications().requestPermissionToSendNotifications();
  //     print('APNS Token is NOT null, trying to intiialize FirebaseMessaging listener');
  //     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  //       print('On foreground msg');
  //       NotificationManager.handleFCMForegroundMessage(message.data, navigatorKey.currentContext!);
  //     });

  //     FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
  //   }else{
  //     print('APNS Token is null');
  //     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  //       print('On foreground msg');
  //       NotificationManager.handleFCMForegroundMessage(message.data, navigatorKey.currentContext!);
  //     });

  //     FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
  //   }
  // } else {
  //   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  //     NotificationManager.handleFCMForegroundMessage(message.data, navigatorKey.currentContext!);
  //   });

  //   FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
  // }

  NotificationController.initializeLocalNotifications(debug: true);
  NotificationController.startListeningNotificationEvents();
}

// @pragma('vm:entry-point')
// Future<void> handleBackgroundMessage(RemoteMessage message) async {
//   print('On background msg');
//   await NotificationManager.handleFCMBackgroundMessage(message.data);
// }


class BeeFriends extends StatefulWidget {
  final Function onUserLoggedIn;

  BeeFriends({required this.onUserLoggedIn});

  @override
  BeeFriendsState createState() => BeeFriendsState();

}

final navigatorKey = GlobalKey<NavigatorState>();

class BeeFriendsState extends State<BeeFriends> {
  CompleteUser? _loggedInUser;
  late Future<CompleteUser?> _userInfoFuture;
  late Future<FirebaseApp> _firebaseInitFuture;
  String _denyMessage = 'Waiting for the maintenance to finish';

  static const experimentMaterial3 = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp
    ]);
    _firebaseInitFuture = _loadFirebase().then((value) {
      _fetchDenyMessage();
      initApp().then((val) {
        _userInfoFuture = _loadUserInfo();
      });

      return value;
    });

  }

  Future<FirebaseApp> _loadFirebase() async {
    await dotenv.load(fileName: ".env");
    var app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await AwesomeNotificationsFcm().initialize(
        onFcmSilentDataHandle: NotificationController.mySilentDataHandle,
        onFcmTokenHandle: NotificationController.myFcmTokenHandle,
        onNativeTokenHandle: NotificationController.myNativeTokenHandle,
        licenseKeys: [dotenv.env['AWN_LICENSE_KEY']!],
        debug: false);
    await AwesomeNotificationsFcm().requestFirebaseAppToken();

    return app;
  }

  Future<CompleteUser?> _loadUserInfo() async {
    await initPlatformState();

    final prefs = await SharedPreferences.getInstance();
    final displayName = prefs.getString('displayName');
    final email = prefs.getString('email');
    final id = prefs.getString('id');

    print('ID: $id');

    if (id != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (userDoc.exists) {
        Map<String, dynamic>? picturesMap = userDoc.get('pictures') as Map<String, dynamic>?;
        String? defaultPicture = picturesMap?['default'];
        List<String>? otherPictures = List<String>.from(picturesMap?['others'] ?? []);

        NicknameManager.initialize(id);

        _loggedInUser = CompleteUser(
          displayName: displayName,
          email: email,
          id: id,
          birthDate: userDoc.get('birthDate'),
          description: userDoc.get('description'),
          gender: userDoc.get('gender'),
          height: userDoc.get('height'),
          interests: userDoc.get('interests'),
          lookingFor: userDoc.get('lookingFor'),
          major: userDoc.get('major'),
          religion: userDoc.get('religion'),
          campus: userDoc.get('campus'),
          studentNumber: userDoc.get('studentNumber'),
          defaultPicture: defaultPicture,
          otherPictures: otherPictures,
          beets: (userDoc.get('beets') as num).toInt(),
          accountType: userDoc.get('accountType')
        );

        LogInResult result = await Purchases.logIn(id);
        await checkAndUpdateUserPremiumStatus(result, id);

      }

      return _loggedInUser;
    }

    return null;
  }

  static Future<void> checkAndUpdateUserPremiumStatus(LogInResult result, String userId) async{
    Map<String, EntitlementInfo> entitlements = result.customerInfo.entitlements.all;

    if(entitlements['Premium'] != null && entitlements['Premium']!.isActive){
      await FirebaseFirestore.instance.collection('users').doc(userId).set({'accountType': 'PREMIUM'}, SetOptions(merge: true));
    }else{
      await FirebaseFirestore.instance.collection('userSettings').doc(userId).set({'show_read_receipts': true}, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('users').doc(userId).set({'accountType': 'REGULAR'}, SetOptions(merge: true));
    }
  }

  String encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = ThemeData(
      fontFamily: 'Quicksand',
      scaffoldBackgroundColor: Color(0xFFfec629),
      primaryColor: Color(0xFFfec629),
      primaryColorDark: Color(0xff2d2d2d),
      primaryColorLight: Color(0xfffad353),
      cardColor: Color(0xFF028ed5),
      hintColor: Color(0xff8f5404),
      dialogBackgroundColor: Color(0xfffdd687),
      useMaterial3: false,
      indicatorColor: Color(0xff369ef8),
      appBarTheme: AppBarTheme(
        color: Color(0xff262626),
      ),
    );

    final ThemeData themeDataMat3 = ThemeData(
      useMaterial3: true,  // Enable Material 3
      fontFamily: 'Quicksand',
      scaffoldBackgroundColor: Color(0xFFfec629),
      // Define a ColorScheme with your specific colors
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFFfec629),
        onPrimary: Color(0xffffffff), // Choose a color for text/icons on primary color
        primaryContainer: Color(0xff2d2d2d),
        onPrimaryContainer: Color(0xffffffff), // Color for text/icons on primary container
        secondary: Color(0xFF028ed5),
        onSecondary: Color(0xffffffff), // Color for text/icons on secondary color
        secondaryContainer: Color(0xff8f5404),
        onSecondaryContainer: Color(0xffffffff), // Text/icons on secondary container
        background: Color(0xfffdd687),
        onBackground: Color(0xff000000), // Text/icons on background color
        surface: Color(0xff262626),
        onSurface: Color(0xffffffff), // Text/icons on surface color
        error: Color(0xffb00020), // Choose an appropriate error color
        onError: Color(0xffffffff), // Text/icons on error color
        onErrorContainer: Color(0xff930006), // Choose a color for error container
        onTertiary: Color(0xffffffff), // Adjust as needed
        onTertiaryContainer: Color(0xffffffff), // Adjust as needed
        outline: Color(0xff757575), // Outline color, typically used for borders
        shadow: Color(0xff000000), // Shadow color
        inverseSurface: Color(0xff121212), // Inverse surface color, used in dark theme
        onInverseSurface: Color(0xffffffff), // Text/icons on inverse surface
        inversePrimary: Color(0xffd0e3ff), // Inverse primary color
        tertiary: Color(0xff018786), // Tertiary color
        tertiaryContainer: Color(0xff00574B), // Tertiary container color
        surfaceVariant: Color(0xffc4c4c4), // Surface variant color
        onSurfaceVariant: Color(0xff000000), // Text/icons on surface variant
      ),
      // Other properties...
      appBarTheme: AppBarTheme(
        color: Color(0xff262626),
      ),
    );

    return FutureBuilder(
      future: _firebaseInitFuture,
      builder: (context, snapshot) {
        // If Firebase is still loading, show the loading screen
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoadingScreen(context);
        }

        // Once Firebase is loaded, proceed with the StreamBuilder
        //Initialize messaging service for notifs
        // initApp();
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .doc('/globalPlatformState/platformStatus')
              .snapshots(),
          builder: (context, platformSnapshot) {
            if (platformSnapshot.hasData && platformSnapshot.data!.exists) {
              var platformStatus = platformSnapshot.data!.data() as Map<String, dynamic>;
              bool isPlatformOpen = platformStatus['open'] ?? false;

              if (!isPlatformOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Fluttertoast.showToast(
                      msg: "BeeFriends is currently closed for maintenance. Try again later.",
                      toastLength: Toast.LENGTH_LONG,
                      gravity: ToastGravity.CENTER,
                      timeInSecForIosWeb: 3,
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                      fontSize: 16.0
                  );
                });
                return _buildMaintenanceScreen(context);
              }
            }

            // Build the main part of the app
            return InAppNotification(
              child: FutureBuilder(
                future: _userInfoFuture,
                builder: (context, firebaseSnapshot) {
                  if (firebaseSnapshot.hasError) {
                    String errorId = '';

                    DocumentReference docRef = FirebaseFirestore.instance.collection('launchErrorReports').doc();

                    // Save the generated ID
                    errorId = docRef.id;

                    final reportData = {
                      'timestamp': FieldValue.serverTimestamp(),
                      'error': 'Application Launch Error : Firebase Initialization',
                      'shortMessage': firebaseSnapshot.error.toString(),
                      'stackTrace': firebaseSnapshot.stackTrace.toString(),
                    };

                    // Use the pre-generated document reference to create the document
                    docRef.set(reportData).catchError((error) {
                      print("Error creating report: $error");
                    });
                    return MaterialApp(
                      home: Scaffold(
                        appBar: AppBar(
                          title: Text('BeeFriends Launch Error'),
                        ),
                        body: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'Application Launch Failed',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'Your launch error has been logged and saved. The error ID is ${errorId}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'Try to clear the app cache and storage, or reinstalling the app.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(height: 200),
                            Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'None of the solutions worked? Try contacting app support',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                // Gather device information
                                String deviceName = Platform.localHostname;
                                String osName = Platform.operatingSystem;
                                String osVersion = Platform.operatingSystemVersion;

                                // Get current timestamp
                                String currentTimestamp = DateTime.now().toString();

                                // Get application version
                                PackageInfo packageInfo = await PackageInfo.fromPlatform();
                                String appName = packageInfo.appName;
                                String appVersion = packageInfo.version;

                                final Uri emailLaunchUri = Uri(
                                  scheme: 'mailto',
                                  path: 'app-support@beefriendsapp.com',
                                  query: encodeQueryParameters(<String, String>{
                                    'subject': 'BeeFriends App Launch Issue',
                                    'body': "Hello, I am having problems launching BeeFriends. \n"
                                        "The error message displayed is 'Application Launch Failed'. \n"
                                        "The error instance ID is '$errorId'. \n"
                                        "The current timestamp is: $currentTimestamp \n"
                                        "The device used is: $deviceName running $osName $osVersion \n"
                                        "The application version is: $appName $appVersion \n"
                                        "This message is automatically generated by BeeFriends internal error report tool.\n"
                                  }),
                                );
                                if (await canLaunchUrl(emailLaunchUri)) {
                                  await launchUrl(emailLaunchUri);
                                } else {
                                  await launchUrl(emailLaunchUri);
                                }
                              },
                              child: Text('Contact App Support'),
                            ),
                            SizedBox(height: 20),
                            Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'If the button above does not work. Send an email manually to \'app-support@beefriendsapp.com\'',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (firebaseSnapshot.connectionState == ConnectionState.done) {
                    return FutureBuilder<CompleteUser?>(
                      future: _userInfoFuture,
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (userSnapshot.hasError) {
                          return Text('Error: ${userSnapshot.error}');
                        } else if (!userSnapshot.hasData || userSnapshot.data == null) {
                          return UserProvider(
                            initialUser: null,
                            child: MaterialApp(
                              title: 'BeeFriends',
                              debugShowCheckedModeBanner: false,
                              theme: experimentMaterial3 ? themeDataMat3 : themeData,
                              navigatorKey: navigatorKey,
                              home: _buildHomePageBasedOnUser(userSnapshot.data),
                            ),
                          );
                        } else {
                          return UserProvider(
                            initialUser: userSnapshot.data,
                            child: MaterialApp(
                              title: 'BeeFriends',
                              debugShowCheckedModeBanner: false,
                              theme: experimentMaterial3 ? themeDataMat3 : themeData,
                              navigatorKey: navigatorKey,
                              home: _buildHomePageBasedOnUser(userSnapshot.data),
                            ),
                          );
                        }
                      },
                    );
                  }else{
                    return _buildLoadingScreen(context);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: null,
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/beefriends_logo.png', width: 200, height: 200),
                  Text(
                    'BeeFriends',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        fontFamily: GoogleFonts.quicksand(fontWeight: FontWeight.bold).fontFamily
                    ),
                  ),
                  SizedBox(height: 20),
                  Padding(padding: EdgeInsets.only(left: 15, top: 30, bottom: 30, right: 15),
                      child: Column(children: [
                        Text(
                          'Find your honey,',
                          style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).hintColor,
                              fontFamily: GoogleFonts.quicksand().fontFamily
                          ),
                        ),
                        Text(
                          'make sweet memories',
                          style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).hintColor,
                              fontFamily: GoogleFonts.quicksand().fontFamily
                          ),
                        )
                      ],)
                  ),
                  SizedBox(height: 50),
                  const Center(child: SizedBox(height: 100, child: SpinKitWave(color: Colors.blue, duration: Duration(milliseconds: 400)))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceScreen(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: null,
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/beefriends_logo.png', width: 200, height: 200),
                  Text(
                    'BeeFriends',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        fontFamily: GoogleFonts.quicksand(fontWeight: FontWeight.bold).fontFamily
                    ),
                  ),
                  SizedBox(height: 20),
                  Padding(padding: EdgeInsets.only(left: 15, top: 30, bottom: 30, right: 15),
                      child: Column(children: [
                        Text(
                          'Platform maintenance is underway',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).hintColor,
                              fontFamily: GoogleFonts.quicksand().fontFamily
                          ),
                        ),
                        const SizedBox(height: 20,),
                        Divider(),
                        const SizedBox(height: 20,),
                        Text(
                          _denyMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              color: Theme.of(context).hintColor,
                              fontFamily: GoogleFonts.quicksand().fontFamily
                          ),
                        ),
                        const SizedBox(height: 20,),
                        Divider(),
                        const SizedBox(height: 20,),
                        Text(
                          'All users are denied access to the app at the moment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).hintColor,
                              fontFamily: GoogleFonts.quicksand().fontFamily
                          ),
                        ),
                      ],)
                  ),
                  SizedBox(height: 50),
                  const Center(child: SizedBox(height: 100, child: SpinKitWave(color: Colors.red, duration: Duration(milliseconds: 1000)))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchDenyMessage() async {
    try {
      DocumentSnapshot platformStatus = await FirebaseFirestore.instance
          .doc('/globalPlatformState/platformStatus')
          .get();
      setState(() {
        _denyMessage = platformStatus['denyMessage'] ?? _denyMessage;
      });
    } catch (e) {
      // Handle errors if necessary
      print('Error fetching deny message: $e');
    }
  }

  static Future<void> initPlatformState() async {
    await Purchases.setLogLevel(LogLevel.warn);

    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration =
          PurchasesConfiguration('goog_WkPzVvEZEHHRuXrRnMIVhfRuwhs');
    } else if (Platform.isIOS) {
      configuration =
          PurchasesConfiguration('appl_MnysOoSybyPwDWOUKouDvCrdsxN');
    } else {
      configuration =
          PurchasesConfiguration('goog_WkPzVvEZEHHRuXrRnMIVhfRuwhs');
    }

    await Purchases.configure(configuration);
  }

  Widget _buildHomePageBasedOnUser(CompleteUser? user) {
    if (user != null) {
      return MainPage();
    } else {
      return LoginPage(onUserLoggedIn: widget.onUserLoggedIn);
    }
  }
}

class FirebaseInitErrorScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Error'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'An error occurred while launching the app. Try to reinstall or clear the application cache and data.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

