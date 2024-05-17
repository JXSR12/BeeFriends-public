import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:BeeFriends/home.dart';
import 'package:BeeFriends/open_message_page.dart';
import 'package:BeeFriends/profile_page.dart';
import 'package:BeeFriends/utils/common_bottom_app_bar.dart';
import 'package:BeeFriends/utils/countdown_timer.dart';
import 'package:BeeFriends/utils/data_manager.dart';
import 'package:BeeFriends/utils/inapp_notification_body.dart';
import 'package:BeeFriends/utils/notification_controller.dart';
import 'package:BeeFriends/utils/notification_manager.dart';
import 'package:BeeFriends/utils/user_provider.dart';
import 'package:BeeFriends/utils/user_status_widget_beets.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:in_app_notification/in_app_notification.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/models/offerings_wrapper.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'chats_page.dart';
import 'login_page.dart';
import 'package:BeeFriends/main.dart';
import 'matchmake_page.dart';

final bool _kAutoConsume = Platform.isIOS || true;

const List<String> _kProductIds = <String>[
  'beets',
  'beets.4',
  'beets.8',
  'beets.16',
  'beets.32',
  'beets.64',
  'beets.x',
];

const List<String> _kSubscriptionIds = <String>[
  'premium',
];

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

Future<void> checkLoginStatus(bool forcedCheckTrigger) async {
  Config config = Config(
      tenant: 'common',
      clientId: 'b89cc19d-4587-4170-9b80-b39204b74380',
      scope: 'openid profile offline_access User.Read',
      redirectUri: 'https://beefriends-a1c17.firebaseapp.com/__/auth/handler',
      navigatorKey: navigatorKey,
      loader: SizedBox());
  final AadOAuth oauth = AadOAuth(config);
  bool isLoggedIn = await oauth.hasCachedAccountInformation;

  print('Is logged in? $isLoggedIn');
  if (!isLoggedIn || forcedCheckTrigger) {
    Navigator.pushReplacement(
      navigatorKey.currentContext!,
      MaterialPageRoute(
        builder: (context) => LoginPage(
          onUserLoggedIn: () {
            navigatorKey.currentState?.pushReplacement(
              MaterialPageRoute(builder: (context) => MainPage()),
            );
          },
          showForcedLogoutAlert: forcedCheckTrigger,
        ),
      ),
    );
  }
}


class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  late CompleteUser? currentUser = null;
  bool _purchasePending = false;

  late List<Widget> _pages;

  Future<void> checkValidFcmToken(bool isFromSignIn) async {
    String? deviceFcmToken = NotificationController().firebaseToken;
    DocumentReference fcmTokenDocRef = FirebaseFirestore.instance.collection('fcmTokens').doc(currentUser?.id);
    DocumentSnapshot fcmTokenDoc = await fcmTokenDocRef.get();

    if (!fcmTokenDoc.exists || isFromSignIn) {
      await fcmTokenDocRef.set({'token': deviceFcmToken});
    } else {
      String? validFcmToken = (fcmTokenDoc.data() as Map<String, dynamic>)['token'];

      if (fcmTokenDoc.data() == null || deviceFcmToken == null || deviceFcmToken != validFcmToken) {
        await oauth.logout();
        checkLoginStatus(true);
      }
    }
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newUser = UserProviderState.userOf(context);

    checkValidFcmToken(false);
    NotificationController.resetBadge();

    if (newUser != null && newUser != currentUser) {
      setState(() {
        currentUser = newUser;
      });
    }
  }

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
    _pages = [
      Home(),
      OpenMessagePage(),
      MatchmakePage(),
      ChatsPage(),
    ];

    NotificationController.resetBadge();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        isAllowed = await NotificationController.displayNotificationRationale();
      }
    });
  }

  void _onBottomNavBarTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }


  @override
  Widget build(BuildContext context) {
    currentUser = UserProviderState.userOf(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: Image.asset('assets/beefriends_logo.png'),
        title: Text(
          currentUser?.accountType == 'REGULAR' ? 'BeeFriends' : 'BeeFriends Premium',
          style: TextStyle(fontSize: currentUser?.accountType == 'REGULAR' ? 30 : 20, fontWeight: FontWeight.bold, color: currentUser?.accountType == 'REGULAR' ? Colors.white : Colors.amberAccent,),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1), // Semi transparent background
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
              child: Row(
                children: [
                  Chip(
                    backgroundColor: Colors.black54,
                    label: Row(
                      children: [
                        SvgPicture.asset('assets/beets_icon.svg', height: 25, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                        SizedBox(width: 5.0),
                        Text('${currentUser?.beets}', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: Colors.orange),
                    onPressed: () {
                      showPurchaseOptionsDialog();
                    },
                  ),
                  Spacer(),  // Pushes the button to the right end
                  ElevatedButton.icon(
                    icon: Icon(Icons.info_outline_rounded, size: 16, color: Colors.white),
                    label: Text('Beets Information', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(50),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      textStyle: TextStyle(fontSize: 14),
                    ),
                    onPressed: _showInfoDialog,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundImage: NetworkImage(currentUser?.defaultPicture ?? 'assets/beefriends_logo.png'),
              ),
            ),
          ),
        ],
      )
      ,
      body: _pages[_currentIndex],
      bottomNavigationBar: CommonBottomAppBar(
        initialIndex: _currentIndex,
        onTap: _onBottomNavBarTapped,
      ),
    );
  }

  String _formatPrice(int price) {
    final formatCurrency = new NumberFormat.simpleCurrency(locale: 'id_ID', name: 'IDR', decimalDigits: 0);
    return formatCurrency.format(price).replaceAll('Rp', 'IDR ').replaceAll('.', ',');
  }


  void showPurchaseOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        if(_purchasePending) return Center(child: Column(children: [Text('Purchase Pending', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 10,), SizedBox(height: 30, child: SpinKitFadingFour(color: Colors.black54, duration: Duration(milliseconds: 200),)),],),);
        return AlertDialog(
          title: Text(
            'Need more Beets?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepOrange),
          ),
          content: StatefulBuilder(  // Use a StatefulBuilder to manage state for countdown
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text('Get Free Beets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FutureBuilder<bool>(
                        future: _canClaimBeets(currentUser?.id ?? ''),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 400),)),);
                          }
                          bool canClaim = snapshot.data ?? false;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  canClaim ? 'Claim your daily beets' : 'You can claim your daily beets in',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if (canClaim) ...[
                                ElevatedButton(
                                  onPressed: () async {
                                    int result = await DataManager.claimDailyBeets(currentUser?.id ?? '');
                                    setState(() {
                                    });

                                    String message;
                                    if (result != -1) {
                                      message = "Successfully claimed daily beets. $result beets have been added to your account.";
                                    } else {
                                      message = "Failed to claim daily beets. Please try again later.";
                                    }

                                    Navigator.of(context).pop();

                                    InAppNotification.show(
                                      child: BeetsClaimNotificationBody(message: message, success: result != -1,),
                                      context: context,
                                      onTap: () {},
                                      duration: Duration(milliseconds: 2000),
                                    );
                                  },
                                  child: const Text('Claim Now'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                                ),
                              ] else ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Center(
                                    child: CountdownTimer(
                                      remainingTime: _timeUntilNextClaim(currentUser?.id ?? ''),
                                      onCountdownCompleted: () {
                                        setState(() {
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(currentUser?.accountType == 'REGULAR' ? 'Upgrade to Premium Account' : 'Premium Membership Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 10),
                    UserStatusWidget(upgradeAction: _upgradePremium, hPadding: 16,),
                    SizedBox(height: 20),
                    Text('Purchase more Beets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FutureBuilder(
                        future: getBeetsPackages(),
                        builder: (BuildContext context, AsyncSnapshot<List<Package>> snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 400),)),);
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text("Error: ${snapshot.error}"));
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(child: Text("No products available"));
                          }

                          List<Package> products = snapshot.data!;
                          return Column(
                            children: products.map((product) {
                              List<String> titleWords = product.storeProduct.title.split(' ');
                              String shortTitle = titleWords.length >= 2 ? '${titleWords[0]} ${titleWords[1]}' : product.storeProduct.title;

                              String price = product.storeProduct.priceString;
                              return _beetOption(product, product.identifier, shortTitle, price);
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<List<Package>> getBeetsPackages() async{
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.all.containsKey('beets')) {
        Offering? beetsOffering = offerings.all['beets'];

        if(beetsOffering == null) return [];
        return beetsOffering.availablePackages;

      }
    } on PlatformException catch (e) {
      // optional error handling
    }

    return [];
  }

  Future<Timestamp> getServerTimestamp() async {
    final functions = FirebaseFunctions.instance;
    final HttpsCallableResult response = await functions.httpsCallableFromUrl('https://asia-southeast2-beefriends-a1c17.cloudfunctions.net/servertimestamp').call();
    Timestamp serverTimestamp = Timestamp.fromMillisecondsSinceEpoch(
        response.data['timestamp']['_seconds'] * 1000
    );

    return serverTimestamp;
  }

  Future<bool> _canClaimBeets(String userId) async {
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final userSnapshot = await userRef.get();
    final userData = userSnapshot.data() as Map<String, dynamic>;
    final lastBeetsClaim = userData['lastBeetsClaim'] as Timestamp?;
    final serverTimestamp = await getServerTimestamp();

    if (lastBeetsClaim == null) {
      return true;
    } else {
      final secondsSinceLastClaim = serverTimestamp.seconds - lastBeetsClaim.seconds;
      return secondsSinceLastClaim >= 86400;
    }
  }

  Future<Duration> _timeUntilNextClaim(String userId) async {
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final userSnapshot = await userRef.get();
    final userData = userSnapshot.data() as Map<String, dynamic>;
    final lastBeetsClaim = userData['lastBeetsClaim'] as Timestamp?;
    final serverTimestamp = await getServerTimestamp();

    if (lastBeetsClaim == null) {
      return Duration.zero;
    } else {
      final secondsSinceLastClaim = serverTimestamp.seconds - lastBeetsClaim.seconds;
      if (secondsSinceLastClaim < 86400) {
        final remainingSeconds = 86400 - secondsSinceLastClaim;
        return Duration(seconds: remainingSeconds);
      } else {
        return Duration.zero;
      }
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Beets Information', style: TextStyle(fontWeight: FontWeight.bold),),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: [
                      WidgetSpan(
                        child: SvgPicture.asset('assets/beets_icon.svg', height: 25, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                        alignment: PlaceholderAlignment.middle,
                      ),
                      TextSpan(text: " The number on the upper left corner you see is how many "),
                      TextSpan(text: 'Beets', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      TextSpan(text: " you currently have left.\n\n"),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: [
                      WidgetSpan(
                        child: Icon(Icons.arrow_right_alt, color: Colors.green, size: 20),
                        alignment: PlaceholderAlignment.middle,
                      ),
                      TextSpan(text: " You will be granted Beets daily.\n"),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: [
                      WidgetSpan(
                        child: Icon(Icons.star, color: Colors.amber, size: 20),
                        alignment: PlaceholderAlignment.middle,
                      ),
                      TextSpan(text: " "),
                      TextSpan(text: 'Premium', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                      TextSpan(text: " accounts get "),
                      TextSpan(text: '60 Beets', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      TextSpan(text: " daily while standard accounts get "),
                      TextSpan(text: '20 Beets', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      TextSpan(text: ".\n"),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: [
                      WidgetSpan(
                        child: Icon(Icons.arrow_right_alt, color: Colors.green, size: 20),
                        alignment: PlaceholderAlignment.middle,
                      ),
                      TextSpan(text: " Beets are consumed when you accept a candidate and sends a match request to them.\n"),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: [
                      WidgetSpan(
                        child: Icon(Icons.arrow_right_alt, color: Colors.green, size: 20),
                        alignment: PlaceholderAlignment.middle,
                      ),
                      TextSpan(text: " Beets are also consumed when you accept a match request from another person.\n"),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: [
                      WidgetSpan(
                        child: Icon(Icons.arrow_right_alt, color: Colors.green, size: 20),
                        alignment: PlaceholderAlignment.middle,
                      ),
                      TextSpan(text: " Beets might also be consumed when you post an OpenMessage.\n"),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: [
                      WidgetSpan(
                        child: Icon(Icons.arrow_right_alt, color: Colors.green, size: 20),
                        alignment: PlaceholderAlignment.middle,
                      ),
                      TextSpan(text: " The cost of sending and accepting match requests are dynamically calculated. It depends on the matching preferences set and the available candidates. "),
                      TextSpan(text: 'The easier our system finds a match that suits you, the cheaper it will be.\n'),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: [
                      WidgetSpan(
                        child: Icon(Icons.arrow_right_alt, color: Colors.green, size: 20),
                        alignment: PlaceholderAlignment.middle,
                      ),
                      TextSpan(text: " The cost of posting an OpenMessage is also dynamic. It depends on how frequent you are posting within a specific time period. "),
                      TextSpan(text: 'It will make sure to discourage spamming, while still being free for occasional posters.\n'),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: [
                      WidgetSpan(
                        child: Icon(Icons.arrow_right_alt, color: Colors.green, size: 20),
                        alignment: PlaceholderAlignment.middle,
                      ),
                      TextSpan(text: " The amount of Beets that will be consumed for any action will always be displayed, ensuring full control over your Beets spending.\n"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void handleError(IAPError error) {
    setState(() {
      _purchasePending = false;
    });
  }

  void showPendingUI() {
    setState(() {
      _purchasePending = true;
    });
  }

  Future<void> _upgradePremium() async{
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        Package? firstAvail = offerings.current?.availablePackages.first;

        try {
          CustomerInfo customerInfo = await Purchases.purchasePackage(firstAvail!);
          bool? isPremium = customerInfo.entitlements.all['Premium']?.isActive;
            if (isPremium != null && isPremium) {
                FirebaseFirestore firestore = FirebaseFirestore.instance;
                DocumentReference userDoc = firestore.doc("/users/${currentUser?.id ?? 'unidentified'}");
                DateTime currentDate = DateTime.now();
                DateTime subscriptionEndDate = currentDate.add(Duration(days: 30));

                CollectionReference premiumLogCollection = firestore.collection('manualPremiumSubscriptionLog');
                await premiumLogCollection.add({
                  'userId': currentUser?.id,
                  'timestamp': FieldValue.serverTimestamp(),
                  'subscriptionStartDate': currentDate,
                  'subscriptionEndDate': subscriptionEndDate,
                  'status': 'active'
                });

                await firestore.runTransaction((transaction) async {
                  transaction.update(userDoc, {'accountType': 'PREMIUM'});
                });

              NotificationManager.addPremiumPurchaseNotification(currentUser?.id ?? 'unidentified');
            }
         } on PlatformException catch (e) {
            var errorCode = PurchasesErrorHelper.getErrorCode(e);
            if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
              //Cancel purchase
            }
          }
      }
    } on PlatformException catch (e) {
      // optional error handling
    }
  }

  Widget _beetOption(Package product, String productId, String title, String price) {
    return ListTile(
      title: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      subtitle: Text(price),
      onTap: () async {
        try{
          CustomerInfo customerInfo = await Purchases.purchasePackage(product);
          FirebaseFirestore firestore = FirebaseFirestore.instance;
            if (productId.startsWith("beets")) {
              log('Delivering beets product');
              DocumentSnapshot productSnapshot = await firestore.doc("beetsPurchaseOptions/$productId").get();
              int amount = productSnapshot.get('amount');

              String? userId = currentUser?.id;
              if (userId != null) {
                log('UserID Not null');
                // Update beets in user account
                log('delivering beets');
                DocumentReference userDoc = firestore.doc("/users/$userId");
                await firestore.runTransaction((transaction) async {
                  DocumentSnapshot userSnapshot = await transaction.get(userDoc);
                  int currentBeets = (userSnapshot.get('beets') as num).toInt();
                  transaction.update(userDoc, {'beets': currentBeets + amount});
                });

                NotificationManager.addBeetsPurchaseNotification(currentUser?.id ?? 'unidentified', amount);

                if (currentUser?.id != null) {
                  log('adding purchase log');
                  DocumentReference logDoc = firestore.doc("/userPurchaseLog/${currentUser?.id}/${customerInfo.nonSubscriptionTransactions.last.transactionIdentifier}");
                  await logDoc.set({
                    'productId': customerInfo.nonSubscriptionTransactions.last.productIdentifier,
                    'transactionId': customerInfo.nonSubscriptionTransactions.last.transactionIdentifier,
                    'transactionDate': customerInfo.nonSubscriptionTransactions.last.purchaseDate,
                    'managementUrl': customerInfo.managementURL,
                    'purchaseUserId': customerInfo.originalAppUserId,
                  });
                }

                setState(() {
                  _purchasePending = false;
                });
              }
            }
        }on PlatformException catch(e){
          var errorCode = PurchasesErrorHelper.getErrorCode(e);
          if (errorCode != PurchasesErrorCode.purchaseCancelledError) {

          }
        }
      },
    );
  }
}
