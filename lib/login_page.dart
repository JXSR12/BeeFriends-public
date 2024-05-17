import 'package:BeeFriends/utils/data_manager.dart';
import 'package:BeeFriends/utils/nickname_manager.dart';
import 'package:BeeFriends/utils/notification_controller.dart';
import 'package:BeeFriends/utils/user_provider.dart';
import 'package:BeeFriends/welcome_page.dart';
import 'package:aad_oauth/model/failure.dart';
import 'package:aad_oauth/model/token.dart';
import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:microsoft_graph_api/models/user/user_model.dart' as MSGUser;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'home.dart';
import 'main.dart';
import 'package:microsoft_graph_api/microsoft_graph_api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  final Function onUserLoggedIn;
  final bool showForcedLogoutAlert;

  LoginPage({required this.onUserLoggedIn, this.showForcedLogoutAlert = false});

  @override
  _LoginPageState createState() => _LoginPageState(showForcedLogoutAlert: this.showForcedLogoutAlert);
}

class _LoginPageState extends State<LoginPage> {
  bool isLoading = false;
  final bool showForcedLogoutAlert;

  _LoginPageState({this.showForcedLogoutAlert = false});

  static final Config config = Config(
      tenant: 'common',
      clientId: 'b89cc19d-4587-4170-9b80-b39204b74380',
      scope: 'openid profile offline_access User.Read',
      redirectUri: 'https://beefriends-a1c17.firebaseapp.com/__/auth/handler',
      navigatorKey: navigatorKey,
      loader: SizedBox());
  final AadOAuth oauth = AadOAuth(config);

  late CompleteUser _loggedInUser;

  void _login() async {
    await oauth.logout();
    login(false);
  }

  void _loginWithApple() async {
    await oauth.logout();
    login(false);
  }

  Future<void> removeUserInfoFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('displayName');
    prefs.remove('email');
    prefs.remove('id');
  }

  void login(bool redirect) async {
    config.webUseRedirect = redirect;
    final result = await oauth.login();

    var accessToken = await oauth.getAccessToken();

    if (accessToken != null) {
      setState(() => isLoading = true); // Start loading

      try {
        MSGraphAPI graphAPI = new MSGraphAPI(accessToken);
        MSGUser.User user = await graphAPI.me.fetchUserInfo();

        String? name = user.displayName;
        String? email = user.mail;
        String? id = user.id;

        bool saved = await saveUserInfoToPreferences(user);

        if (name != null && email != null && id != null) {
          UserProvider.of(context).setUserId(id);
          final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();

          if(doc.exists && doc.data()?['studentNumber'] != null){
            NicknameManager.initialize(id);
            LogInResult result = await Purchases.logIn(id);
            await BeeFriendsState.checkAndUpdateUserPremiumStatus(result, id);

            await DataManager.saveFcmToken(id).then((value) async {
              await widget.onUserLoggedIn();
            });
          }else{
            var res = await afterLogin(context, id, email, name);

            if(res){
              _showSuccessDialog();
            }else{
              showUnsupportedDialog();
            }
          }

        } else {
          _showErrorDialog("Sorry but there was an error retrieving your data");
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Microsoft sign in cancelled')));
        _showErrorDialog(e);
      } finally {
        setState(() => isLoading = false);  // End loading
      }
    }else{
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Microsoft sign in cancelled')));
    }
  }

  Future<bool> saveUserInfoToPreferences(MSGUser.User user) async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceFcmToken = NotificationController().firebaseToken;
    DocumentReference fcmTokenDocRef = FirebaseFirestore.instance.collection('fcmTokens').doc(user.id);
    await fcmTokenDocRef.set({'token': deviceFcmToken});
    prefs.setString('displayName', user.displayName ?? "");
    prefs.setString('email', user.mail ?? "");
    prefs.setString('id', user.id ?? "");

    return prefs.containsKey('id');
  }

  void showError(dynamic ex) {
    showMessage(ex.toString());
  }

  void showMessage(String text) {
    var alert = AlertDialog(content: Text(text), actions: <Widget>[
      TextButton(
          child: const Text('Ok'),
          onPressed: () {
            Navigator.pop(context);
          })
    ]);
    showDialog(context: context, builder: (BuildContext context) => alert);
  }

  void _showErrorDialog(e) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('You are confirmed to be a student in one of our supported institutions (BINUS University).')));
  }

  void showUnsupportedDialog() {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Sorry, but we cannot verify that you are a student in one of our supported institutions. Try again later or use a different sign in method.')));
  }

  void _showForcedLogoutAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign In Alert'),
        content: Text(
            'Another sign in has been detected from another device, you have been signed out from this device. Sign in again to continue using the app.'),
        actions: <Widget>[
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<bool> hasCachedAccountInformation() async {
    var hasCachedAccountInformation = await oauth.hasCachedAccountInformation;
    return hasCachedAccountInformation;
  }

  void logout() async {
    await oauth.logout();
    await removeUserInfoFromSharedPreferences();
    showMessage('Logged out');
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: null,
      body: Stack(
        children: [
          // Original body components:
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo widget (Replace with your actual logo)
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
                // Slogan
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
                if(showForcedLogoutAlert)
                Container(
                  padding: EdgeInsets.all(6),
                  width: 300,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(0, 0, 0, 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('You have been signed out as we have detected a sign in from another device. Please sign in again to continue using the app.', style: TextStyle(fontSize: 14, color: Colors.red), textAlign: TextAlign.center,),
                ),
                SizedBox(height: 50),
                // Sign-in Button
                Container(
                  padding: EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(0, 0, 0, 0.2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: ElevatedButton.icon(
                    icon: Image.asset('assets/microsoft_logo.png', height: 18),
                    label: Text(
                      'Sign in with Microsoft',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: GoogleFonts.notoSans().fontFamily,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black54,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onPressed: _login,
                  ),
                ),
                // Padding(padding: EdgeInsets.only(left: 85, right: 85, top: 10), child:
                //   Container(
                //       padding: EdgeInsets.all(7),
                //       decoration: BoxDecoration(
                //         color: Color.fromRGBO(0, 0, 0, 0.2),
                //         borderRadius: BorderRadius.circular(5),
                //       ),
                //       child: SignInWithAppleButton(
                //         onPressed: () async {
                //           final credential = await SignInWithApple.getAppleIDCredential(
                //             scopes: [
                //               AppleIDAuthorizationScopes.email,
                //               AppleIDAuthorizationScopes.fullName,
                //             ],
                //             webAuthenticationOptions: WebAuthenticationOptions(
                //               clientId:
                //               'com.beefriends.beefriends',
                //               redirectUri: Uri.parse(
                //                 'https://beefriendsapp.com/supported-institutions/',
                //               ),
                //             ),
                //           );
                //
                //           //NO INSTITUTIONS SUPPORT LOGIN WITH APPLE YET
                //           showUnsupportedDialog();
                //
                //           //IF USED, PROCEED WITH THE credential.authorizationCode
                //         },
                //       )
                //   ),
                // ),
                SizedBox(height: 20),
                Divider(),
                Padding(padding: EdgeInsets.only(left: 40, top: 4, bottom: 4, right: 40),
                  child: Text(
                    'This application is meant to be used only by students of universities / college included in our currently supported institutions list.',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColorDark,
                        fontFamily: GoogleFonts.quicksand().fontFamily
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(padding: EdgeInsets.all(20), child:
                Align(
                  alignment: Alignment.center,
                  child: InkWell(
                    onTap: () async {
                      const String url = 'https://beefriendsapp.com/supported-institutions';
                      await launchUrl(Uri.parse(url));
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child:
                        Text(
                          'View the list of supported institutions here',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        ),
                        Icon(
                          Icons.open_in_new,
                          color: Colors.black54,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ],
            ),
          ),
          // Loading overlay:
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black45,  // Semi-transparent overlay
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 100, child: SpinKitWave(color: Colors.white70, duration: Duration(milliseconds: 400))),
                      SizedBox(height: 20),
                      Text('Fetching your profile data..', style: TextStyle(color: Colors.white))
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


}
