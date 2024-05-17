import 'dart:io';

import 'package:BeeFriends/main_page.dart';
import 'package:BeeFriends/settings_page.dart';
import 'package:BeeFriends/utils/common_bottom_app_bar.dart';
import 'package:BeeFriends/utils/data_manager.dart';
import 'package:BeeFriends/utils/display_utils.dart';
import 'package:BeeFriends/utils/helper_classes.dart';
import 'package:BeeFriends/utils/notification_manager.dart';
import 'package:BeeFriends/utils/starbees_purchase_section.dart';
import 'package:BeeFriends/utils/starbees_section.dart';
import 'package:BeeFriends/utils/user_provider.dart';
import 'package:BeeFriends/utils/user_status_widget_beets.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_button/flutter_swipe_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:purchases_flutter/models/offerings_wrapper.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as Path;
import 'package:microsoft_graph_api/models/user/user_model.dart' as MSGUser;
import 'package:transparent_image/transparent_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vibration/vibration.dart';
import 'home.dart';
import 'login_page.dart';
import 'package:BeeFriends/main.dart';

class ProfilePage extends StatefulWidget {
  @override
  ProfileState createState() => ProfileState();
}

class ProfileState extends State<ProfilePage> with WidgetsBindingObserver {

  late CompleteUser? currentUser = null;
  final ImagePicker _picker = ImagePicker();

  final ValueNotifier<bool> _isUploading = ValueNotifier<bool>(false);
  final ValueNotifier<double> _uploadProgress = ValueNotifier<double>(0.0);

  int defaultSlots = 0;
  int extraSlots = 0;
  int extraSlotCost = 30;

  bool _shouldUploadImage = false;

  late Future<List<SocialAccount>> _accountsFuture;
  late Future<List<String>> _specialRolesFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newUser = UserProviderState.userOf(context);
    if (newUser != currentUser) {
      setState(() {
        currentUser = newUser;
        setState(() {
          _accountsFuture = retrieveSocialAccounts();
          _specialRolesFuture = fetchSpecialRoles(currentUser?.id ?? 'UNKNOWN');
        });
        fetchDefaultSlots();
        fetchExtraSlots();
      });
    }
  }

  @override
  void initState() {
    super.initState();

    print('INIT PROFILE');
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_shouldUploadImage) {
        _uploadImage();
      }
    });
    setState(() {
      _accountsFuture = retrieveSocialAccounts();
      _specialRolesFuture = fetchSpecialRoles(currentUser?.id ?? 'UNKNOWN');
    });

  }

  Future<List<SocialAccount>> retrieveSocialAccounts() async {
    return DataManager.getSocialAccounts(currentUser?.id ?? 'UNKNOWN').then((value) {
      return value;
    });
  }

  Future<List<String>> fetchSpecialRoles(String userId) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (userDoc.exists && userDoc.data() != null) {
      var userData = userDoc.data() as Map<String, dynamic>;
      String rolesString = userData['specialRoles'] ?? '';
      return rolesString.split(',').map((role) => role.trim()).where((role) => role.isNotEmpty).toList();
    } else {
      return [];
    }
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

  static final Config config = Config(
      tenant: 'common',
      clientId: 'b89cc19d-4587-4170-9b80-b39204b74380',
      scope: 'openid profile offline_access User.Read',
      redirectUri: 'https://beefriends-a1c17.firebaseapp.com/__/auth/handler',
      navigatorKey: navigatorKey,
      loader: SizedBox());
  final AadOAuth oauth = AadOAuth(config);

  static Future<void> removeUserInfoFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('displayName');
    prefs.remove('email');
    prefs.remove('id');
  }

  Widget _buildBadge(IconData icon, String text, Color iconColor, Color textColor, Color backgroundColor) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    currentUser = UserProviderState.userOf(context);

    return Scaffold(
        appBar: AppBar(
          title: Text('Profile'),
          centerTitle: true,
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
            ),
          ],
        ),
      body: Stack(children: [SingleChildScrollView(
        child: Column(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 10),
                Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none, // Allows overlapping
                  children: [
                    Card(
                      elevation: 5,
                      shape: CircleBorder(),
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.blueGrey[50],
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: FadeInImage.assetNetwork(
                            placeholder: 'assets/beefriends_logo.png', // Placeholder image asset
                            image: currentUser?.defaultPicture ?? 'assets/beefriends_logo.png',
                          ).image,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -25,
                      child: Chip(
                        elevation: 5,
                        label: Text(
                          '${currentUser?.studentNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        avatar: Image.asset('assets/beefriends_logo.png'),
                        backgroundColor: Colors.blueGrey[50],
                        padding: EdgeInsets.only(top: 6, bottom: 6, left: 16, right: 16),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Container(
                  margin: EdgeInsets.only(left: 5, right: 5),
                  padding: EdgeInsets.only(left: 45, right: 45, top: 15, bottom: 15),
                  decoration: BoxDecoration(
                    color: Theme.of(context).indicatorColor,
                    border: Border.all(color: Colors.blueGrey[50] ?? Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${currentUser?.displayName}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                      Divider(),
                      if (currentUser?.accountType == 'PREMIUM')
                        _buildBadge(Icons.workspace_premium_rounded, 'Member of the Golden Hive', Colors.amberAccent, Colors.amberAccent, Colors.black)
                      else
                        _buildBadge(Icons.card_membership_rounded, 'Member of the Hive', Colors.blue, Colors.blue, Colors.white),
                      if (currentUser != null && currentUser!.beets! > 500)
                        _buildBadge(Icons.money_rounded, 'Member of the Rich Bee Society', Colors.yellowAccent, Colors.white, Colors.deepPurple.shade800),
                      FutureBuilder<List<String>>(
                        future: _specialRolesFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 500),));
                          }
                          if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          }

                          List<String> specialRoles = snapshot.data ?? [];

                          return Column(
                            children: [
                              if (specialRoles.contains('TEAM'))
                                _buildBadge(Icons.group, 'Member of the BeeFriends Team', Theme.of(context).indicatorColor, Colors.black, Theme.of(context).primaryColorLight),
                              if (specialRoles.contains('PLATFORMDEV'))
                                _buildBadge(Icons.build, 'BeeFriends Platform Developer', Theme.of(context).indicatorColor, Colors.black, Theme.of(context).primaryColorLight),
                              if (specialRoles.contains('PLATFORMMGR'))
                                _buildBadge(Icons.settings, 'BeeFriends Platform Manager', Theme.of(context).indicatorColor, Colors.black, Theme.of(context).primaryColorLight),
                              if (specialRoles.contains('MARKETINGDIR'))
                                _buildBadge(Icons.campaign, 'BeeFriends Marketing Director', Theme.of(context).indicatorColor, Colors.black, Theme.of(context).primaryColorLight),
                              if (specialRoles.contains('WEBDEV'))
                                _buildBadge(Icons.web, 'BeeFriends Web Developer', Theme.of(context).indicatorColor, Colors.black, Theme.of(context).primaryColorLight),
                              if (specialRoles.contains('BUSDIR'))
                                _buildBadge(Icons.business_center, 'BeeFriends Business Director', Theme.of(context).indicatorColor, Colors.black, Theme.of(context).primaryColorLight),
                            ],
                          );
                        },
                      )
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
            UserStatusWidget(upgradeAction: _upgradePremium, hPadding: 64),
            Divider(),
            ListTile(
              leading: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.cake_outlined),),
              title: Text('Birthdate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
              subtitle: Text(
                  currentUser?.birthDate != null
                      ? DateFormat('MMMM dd, yyyy').format(DateTime.parse(currentUser?.birthDate ?? '1900-01-01T00:00:00'))
                      : 'Not specified',
                  style: TextStyle(fontSize: 18)
              ),
            ),
            ListTile(
              leading: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.grade_outlined),),
              title: Text('Major', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
              subtitle: Text('${currentUser?.major}', style: TextStyle(fontSize: 18)),
            ),
            ListTile(
              leading: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.location_city_outlined),),
              title: Text('Campus location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
              subtitle: Text('${currentUser?.campus}', style: TextStyle(fontSize: 18)),
              trailing: IconButton(
                icon: Icon(Icons.edit),
                iconSize: 16,
                onPressed: editCampusLocation,
              ),
            ),
            ListTile(
              leading: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.people_alt_outlined),),
              title: Text('Looking for', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
              subtitle: Text(currentUser?.lookingFor == 0 ? 'Friends' : currentUser?.lookingFor == 1 ? 'A partner' : 'Both friends and partner', style: TextStyle(fontSize: 18)),
              trailing: IconButton(
                icon: Icon(Icons.edit),
                iconSize: 16,
                onPressed: editLookingFor,
              ),
            ),
            ListTile(
              leading: Padding(padding: EdgeInsets.all(10), child: Icon((currentUser?.gender == 'male') ? Icons.male_outlined : Icons.female_outlined),),
              title: Text('Gender', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
              subtitle: Text('${currentUser?.gender?.substring(0, 1).toUpperCase()}${currentUser?.gender?.substring(1)}', style: TextStyle(fontSize: 18)),
              trailing: IconButton(
                icon: Icon(Icons.edit),
                iconSize: 16,
                onPressed: editGender,
              ),
            ),
            ListTile(
              leading: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.balance_outlined),),
              title: Text('Religion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
              subtitle: Text('${currentUser?.religion}', style: TextStyle(fontSize: 18)),
              trailing: IconButton(
                icon: Icon(Icons.edit),
                iconSize: 16,
                onPressed: editReligion,
              ),
            ),
            ListTile(
              leading: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.height_outlined),),
              title: Text('Height', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
              subtitle: Text(currentUser?.height == 'empty' ? 'Prefer not to say' : '${currentUser?.height} cm', style: TextStyle(fontSize: 18)),
              trailing: IconButton(
                icon: Icon(Icons.edit),
                iconSize: 16,
                onPressed: editHeight,
              ),
            ),
            ListTile(
              leading: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.description_outlined),),
              title: Text('Personal description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
              subtitle: Text('${currentUser?.description}', style: TextStyle(fontSize: 18)),
              trailing: IconButton(
                icon: Icon(Icons.edit),
                onPressed: editDescription,
                iconSize: 16,
              ),
            ),
            SizedBox(height: 10,),
            ListTile(
              leading: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.interests_outlined),),
              title: Text('Interests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
              subtitle: Wrap(
                spacing: 6.0,
                children: (currentUser != null && currentUser?.interests != null && currentUser?.interests?.split(',').length == 1 && currentUser?.interests?.split(',')[0] == "") ? [Text("No interests set", style: TextStyle(fontSize: 18))] : currentUser?.interests?.split(',')
                    .map((interest) => interest.isNotEmpty ? Chip(label: Text(interest.trim())) : SizedBox.shrink())
                    .toList() ?? [],
              ),
              trailing: IconButton(
                icon: Icon(Icons.edit),
                iconSize: 16,
                onPressed: editInterests,
              ),
            ),
            SizedBox(height: 10,),
            ListTile(
              leading: (currentUser?.otherPictures?.length == 0) ? null : Padding(padding: EdgeInsets.all(10), child: Icon(Icons.photo_camera_back_outlined),),
              title: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Other pictures',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('defaultSlotsCount').doc('OTHER_PICTURES').get(),
                  builder: (context, snapshotDefaultSlots) {
                    if (!snapshotDefaultSlots.hasData) {
                        return Text(
                        "(--/-- slots used)",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      );
                    }

                    int defaultSlots = snapshotDefaultSlots.data!.get('count');
                    int currentPicsCount = currentUser?.otherPictures?.length ?? 0;
                    int extraSlots = 0;

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('userExtraSlots').doc(currentUser?.id).get(),
                      builder: (context, snapshotExtraSlots) {
                        if (snapshotExtraSlots.hasData && snapshotExtraSlots.data!.exists) {
                          extraSlots = snapshotExtraSlots.data!.get('otherPictures') ?? 0;
                        }

                        int totalSlots = defaultSlots + extraSlots;
                        String slotsIndicator = '($currentPicsCount/$totalSlots slots used)';

                        return Text(
                          slotsIndicator,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.7),
                          ),
                        );
                      },
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: SvgPicture.asset('assets/beets_icon.svg', height: 20, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                  label: Text('${extraSlotCost} (+1 slot)', style: TextStyle(fontSize: 16)),
                  onPressed: () {
                    showPurchaseDialog(context, extraSlotCost);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.4))
                )
              ],
            ),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start ,children: [SizedBox(height: currentUser?.otherPictures == null || currentUser!.otherPictures!.isEmpty ? 0 : 20,), _buildOtherPicturesSubtitle()],),
              trailing: currentUser?.otherPictures == null || currentUser!.otherPictures!.isEmpty ? null : IconButton(
                icon: Icon(Icons.add_a_photo_rounded),
                iconSize: 18,
                onPressed: uploadOtherPicture,

              ),
            ),
            SizedBox(height: 10,),
            _buildSocialAccountsSection(),
            SizedBox(height: 20,),
            Divider(),
            Container(
              color: Colors.green.shade800.withOpacity(1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 5),
                  GestureDetector(
                    onTap: () => StarbeesSectionState.showStarbeesInfoAlt(context),
                    child: Chip(
                      padding: EdgeInsets.only(left: 5, right: 5),
                      elevation: 5,
                      backgroundColor: Colors.transparent,
                      avatar: Icon(Icons.star_rounded, color: Colors.amber),
                      label: Text(
                        'Enhance your profile visibility with Starbee',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  StarbeePurchaseSection(currentUser: currentUser!),
                  SizedBox(height: 10),
                ],
              ),
            ),
            Divider(),
            Padding(
              padding: EdgeInsets.all(10),
              child: Container(
                width: double.infinity,
                  child: SwipeButton.expand(
                    thumb: Icon(
                      Icons.exit_to_app_rounded,
                      color: Colors.white,
                    ),
                    child: Text(
                      "Swipe right to sign out",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    activeThumbColor: Colors.red,
                    activeTrackColor: Colors.black54,
                    onSwipe: () async {
                      String? currentUserId = currentUser?.id;
                      await oauth.logout();

                      if (currentUserId != null && currentUserId != 'null') {
                        FirebaseFirestore.instance.collection('fcmTokens').doc(currentUserId).update({'token': FieldValue.delete()});
                      }

                      UserProvider.of(context).setUserId('null');
                      await removeUserInfoFromSharedPreferences();

                      Navigator.pop(context);
                      checkLoginStatus(false);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Signed out of your account"),
                          backgroundColor: Colors.black54,
                        ),
                      );
                    },
                  )

              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: Container(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  onPressed: () async {
                    // Show a confirmation dialog
                    bool confirm = await showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text('Confirm Account Deletion', style: TextStyle(fontWeight: FontWeight.bold),),
                          content: Text(
                              'This action will delete all your data in our platform. This includes your account membership (if any), your beets, your matches, your friends, your requests, and any chat history. Proceed with deletion?'
                          ),
                          actions: <Widget>[
                            TextButton(
                              child: Text('Cancel'),
                              onPressed: () {
                                Navigator.of(context).pop(false); // Dismiss dialog and return false
                              },
                            ),
                            TextButton(
                              child: Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),),
                              onPressed: () {
                                Navigator.of(context).pop(true); // Confirm and return true
                              },
                            ),
                          ],
                        );
                      },
                    ) ?? false;

                    // Proceed only if confirmed
                    if (confirm) {
                      final callable = FirebaseFunctions.instance.httpsCallableFromUrl(
                          'https://asia-southeast2-beefriends-a1c17.cloudfunctions.net/deleteUserAccountCascade'
                      );
                      dynamic response = await callable.call(<String, dynamic>{
                        'userId': currentUser?.id,
                      });

                      // Check the response
                      if (response.data == true) {
                        // Logic for sign out
                        String? currentUserId = currentUser?.id;
                        await oauth.logout();

                        UserProvider.of(context).setUserId('null');
                        await removeUserInfoFromSharedPreferences();

                        Navigator.pop(context);
                        checkLoginStatus(false);
                      } else {
                        // Display alert dialog
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text('Account Deletion Failed'),
                              content: Text('There is a problem deleting your account, please contact user support at user-support@beefriendsapp.com'),
                              actions: [
                                TextButton(
                                  child: Text('Send email to support'),
                                  onPressed: () async {
                                    final Uri emailLaunchUri = Uri(
                                      scheme: 'mailto',
                                      path: 'user-support@beefriendsapp.com',
                                    );
                                    if (await canLaunchUrl(emailLaunchUri)) {
                                      await launchUrl(emailLaunchUri);
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      }
                    }
                  },
                  child: Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold),),
                ),
              ),
            ),
            Padding(padding: EdgeInsets.all(20), child:
              Align(
                alignment: Alignment.center,
                child: InkWell(
                  onTap: () async {
                    const String url = 'https://beefriendsapp.com/privacy-policy';
                    await launchUrl(Uri.parse(url));
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child:
                      Text(
                        'Read our privacy policy regarding your data',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      ),
                      Icon(
                        Icons.open_in_new,
                        color: Colors.pink,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  String platformName = Platform.isAndroid ? "Android" : "iOS";
                  String version = snapshot.data!.version;
                  return Column(
                    children: [
                      Image.asset('assets/beefriends_logo.png', height: 18),
                      Text(
                        "BeeFriends for $platformName",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        "version $version",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "built by BeeFriends Team",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                      SizedBox(height: 15,)
                    ],
                  );
                } else {
                  return SizedBox(height: 30, child: SpinKitWave(color: Colors.white60, duration: Duration(milliseconds: 800),));
                }
              },
            ),
          ],
        ),
      ),
        ValueListenableBuilder<bool>(
          valueListenable: _isUploading,
          builder: (context, isUploading, child) {
            if (!isUploading) return SizedBox.shrink(); // If not uploading, don't show anything

            return Positioned.fill(
              child: Container(
                color: Colors.black45, // semi-transparent overlay
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 30, child: SpinKitWave(color: Colors.white60, duration: Duration(milliseconds: 800),)),
                      SizedBox(height: 20),
                      Text('Uploading image..', style: TextStyle(color: Colors.white),)
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
      )
    );
  }

  void showPurchaseDialog(BuildContext context, int extraSlotCost) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Purchase Extra Slot"),
          content: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.black, fontSize: 16),
              children: [
                TextSpan(text: "Confirm purchase of 1 extra picture slot for "),
                WidgetSpan(
                  child: SvgPicture.asset('assets/beets_icon.svg', height: 20, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                ),
                TextSpan(text: " ${extraSlotCost}?"),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text("Confirm", style: TextStyle(fontWeight: FontWeight.bold),),
              onPressed: () {
                purchaseExtraSlot(context, extraSlotCost);
              },
            ),
          ],
        );
      },
    );
  }

// Function to handle the purchase logic
  void purchaseExtraSlot(BuildContext context, int extraSlotCost) {
    // Firestore reference
    var userRef = FirebaseFirestore.instance.collection('users').doc(currentUser?.id);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        throw Exception("User does not exist!");
      }

      int currentBeets = (snapshot['beets'] as num).toInt();
      if (currentBeets >= extraSlotCost) {
        // Update Firestore
        transaction.update(userRef, {'beets': currentBeets - extraSlotCost});
        Navigator.of(context).pop(); // Close the dialog
        deliverExtraSlot(); // Deliver the extra slot
      } else {
        Navigator.of(context).pop(); // Close the dialog
        showAlertDialog(context, "Insufficient Beets", "You do not have enough beets to make this purchase.");
      }
    }).catchError((error) {
      // Handle any errors here
      print("Error purchasing extra slot: $error");
    });
  }

// Function to display an alert dialog
  void showAlertDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> uploadOtherPicture() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 200),)),
              SizedBox(width: 20),
              Text("Validating slots..")
            ],
          ),
        );
      },
    );

    await fetchDefaultSlots();
    await fetchExtraSlots();

    Navigator.of(context).pop();

    int totalSlots = defaultSlots + extraSlots;
    int currentPicsCount = currentUser?.otherPictures?.length ?? 0;

    if (currentPicsCount >= totalSlots) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Slot Limit Reached"),
            content: Text("You cannot add more pictures. You already used all your picture slots. Consider deleting a picture by long pressing it, or purchase extra slots."),
            actions: <Widget>[
              TextButton(
                child: Text("OK"),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
    } else {
      _uploadImage();
    }
  }

  Future<void> fetchDefaultSlots() async {
    DocumentSnapshot snapshot = await FirebaseFirestore.instance.collection('defaultSlotsCount').doc('OTHER_PICTURES').get();
    Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
    if (snapshot.exists && data != null && data.containsKey('count')) {
      setState(() {
        defaultSlots = data['count'];
      });
    }
  }

  Future<void> fetchExtraSlots() async {
    String userId = currentUser?.id ?? '';
    DocumentSnapshot snapshot = await FirebaseFirestore.instance.collection('userExtraSlots').doc(userId).get();
    Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
    if (snapshot.exists && data != null && data.containsKey('otherPictures')) {
      setState(() {
        extraSlots = data['otherPictures'];
        extraSlotCost = (extraSlots * 15) + 10;
      });
    }
  }

  Future<void> deliverExtraSlot() async {
    String userId = currentUser?.id ?? '';
    await FirebaseFirestore.instance.collection('userExtraSlots').doc(userId).set({
      'otherPictures': FieldValue.increment(1)
    }, SetOptions(merge: true));

    setState(() {
      extraSlots = extraSlots + 1;
      extraSlotCost = (extraSlots * 15) + 10;
    });
  }

  Widget _buildOtherPicturesSubtitle() {
    if (currentUser?.otherPictures == null || currentUser!.otherPictures!.isEmpty) {
      return Column(children: [SizedBox(height: 20,),
        Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  color: Colors.black54,
                  size: 40.0,
                ),
                SizedBox(height: 5.0),
                Text(
                  'No other pictures added',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                    fontWeight: FontWeight.bold
                  ),
                ),
                SizedBox(height: 5.0),
                Text(
                  'Showcase yourself using your best photos. Upload up to ${defaultSlots + extraSlots} pictures. These will only be shown to your friends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 15.0),
                ElevatedButton.icon(onPressed: uploadOtherPicture, label: Text('Add a Picture'), icon: Icon(Icons.add), style: ElevatedButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.4)),)
              ],
            ),
          ),
        )
      ],);
    }

    int picIdx = 0;

    return Wrap(
      runSpacing: 6.0,
      spacing: 12.0, // Gap between images
      children: currentUser!.otherPictures!.map((url) {
        int curIdx = picIdx;
        picIdx++;

        return GestureDetector(
          onTap: () => DisplayUtils.openImageDialog(context, currentUser!.otherPictures!, curIdx),
          onLongPress: () {
            Vibration.vibrate(duration: 10, amplitude: 200);
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Select action for this picture'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8), // Rounded corners
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: Offset(0, 3), // changes position of shadow
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8), // Rounded corners
                          child: FadeInImage.memoryNetwork(
                            placeholder: kTransparentImage,
                            image: url,
                            height: 110,
                            width: 110,
                            fit: BoxFit.cover,
                            imageErrorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                              return Container(
                                height: 110,
                                width: 110,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.image_outlined,
                                  color: Colors.white,
                                  size: 50,
                                ),
                                alignment: Alignment.center,
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 10,),
                      ListTile(
                        leading: Icon(Icons.fullscreen),
                        title: Text('View Fullscreen'),
                        onTap: () {
                          Navigator.of(context).pop(); // Close the dialog first
                          DisplayUtils.openImageDialog(context, currentUser!.otherPictures!, curIdx);
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Delete Picture', style: TextStyle(color: Colors.red)),
                        onTap: () {
                          Navigator.of(context).pop(); // Close the dialog first
                          deletePicture(url); // Replace with your function to delete the picture
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8), // Rounded corners
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 3), // changes position of shadow
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8), // Rounded corners
              child: FadeInImage.memoryNetwork(
                placeholder: kTransparentImage,
                image: url,
                height: 110,
                width: 110,
                fit: BoxFit.cover,
                imageErrorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                  return Container(
                    height: 110,
                    width: 110,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.white,
                      size: 50,
                    ),
                    alignment: Alignment.center,
                  );
                },
              ),
            ),
          ),
        );
      }).toList(),
    );

  }

  Widget _buildSocialAccountsSection() {
    return FutureBuilder<List<SocialAccount>>(
      future: _accountsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingAccountsPlaceholder();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData && snapshot.data!.isEmpty) {
          return _buildNoAccountsPlaceholder();
        } else {
          return _buildAccountsList(snapshot.data!);
        }
      },
    );
  }

    Widget _buildLoadingAccountsPlaceholder() {
      return ListTile(
        title: Text('Social Accounts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
        subtitle: Column(children: [SizedBox(height: 20,),
          Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SpinKitWave(color: Colors.black54,),
                  SizedBox(height: 5.0),
                  Text(
                    'Loading social accounts..',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                  SizedBox(height: 5.0),
                  Text(
                    'We are currently fetching your stored social accounts',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 15.0),
                ],
              ),
            ),
          )
        ],),
      );
    }


    Widget _buildNoAccountsPlaceholder() {
      return ListTile(
        title: Text('Social Accounts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
        subtitle: Column(children: [SizedBox(height: 20,),
          Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.supervisor_account_rounded,
                    color: Colors.black54,
                    size: 40.0,
                  ),
                  SizedBox(height: 5.0),
                  Text(
                    'No social accounts yet',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                  SizedBox(height: 5.0),
                  Text(
                    'Let your friends know who are you across different sites. These will only be shown to your friends.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 15.0),
                  ElevatedButton.icon(onPressed: () async {
                    await _addSocialAccount();
                  },
                      label: Text('Add a Social Account'),
                      icon: Icon(Icons.add),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.4)))
                ],
              ),
            ),
          )
        ],),
      );
    }

    Widget _buildAccountsList(List<SocialAccount> accounts) {
      return ListTile(
          leading: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.supervisor_account),),
          title: Text('Social Accounts',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [SizedBox(height: 10,), Wrap(
                spacing: 10.0,
                runSpacing: 10.0,
                children: accounts.map((account) =>
                    _buildSocialAccountCardWithDelete(context, account)).toList()
                  ..add(
                      ElevatedButton.icon(onPressed: () async {
                            await _addSocialAccount();
                            },
                          label: Text('Add'),
                          icon: Icon(Icons.add),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.4)))
                  ),
              ),
              ]
          )
      );
    }


  static Future<void> addSocialAccountToFirestore(String userId, SocialAccount account) async {
    if(userId == 'UNKNOWN') return;
    CollectionReference userSocialAccounts = FirebaseFirestore.instance.collection('userSocialAccounts');
    DocumentReference userDoc = userSocialAccounts.doc(userId);

    await userDoc.set({
      account.platform: {
        'accounts': FieldValue.arrayUnion([account.id])
      }
    }, SetOptions(merge: true));
  }

  Widget _buildSocialAccountCardWithDelete(BuildContext context, SocialAccount account) {
    return GestureDetector(
      onTap: () => openSocialLink(account),
        onLongPress: () {
          Vibration.vibrate(duration: 10, amplitude: 200);
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Select action for this social account'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Card(
                      color: Color.fromARGB(200, 255, 255, 255),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset('assets/icon_${account.platform}.svg', height: 25),
                              SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  account.id,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10,),
                    ListTile(
                      leading: Icon(Icons.no_accounts_rounded, color: Colors.red),
                      title: Text('Remove from Account', style: TextStyle(color: Colors.red)),
                      onTap: () {
                        Navigator.of(context).pop();
                        _confirmDeleteSocialAccount(account);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      child: Card(
        color: Color.fromARGB(200, 255, 255, 255),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset('assets/icon_${account.platform}.svg', height: 25),
                SizedBox(width: 10),
                Flexible( // Make the text flexible to avoid overflow
                  child: Text(
                    account.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget buildSocialAccountCard(BuildContext context, SocialAccount account) {
    return GestureDetector(
      onTap: () => openSocialLink(account),
      child: Card(
        color: Color.fromARGB(200, 255, 255, 255),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset('assets/icon_${account.platform}.svg', height: 25),
                SizedBox(width: 10),
                Flexible( // Make the text flexible to avoid overflow
                  child: Text(
                    account.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  static void openSocialLink(SocialAccount account) async {
    String? url;

    switch (account.platform) {
      case 'whatsapp':
        url = 'https://api.whatsapp.com/send?phone=${account.id}';
        break;
      case 'instagram':
        url = 'https://www.instagram.com/${account.id}';
        break;
      case 'tiktok':
        url = 'https://www.tiktok.com/@${account.id}';
        break;
      case 'pinterest':
        url = 'https://www.pinterest.com/${account.id}';
        break;
      case 'youtube':
        url = 'https://www.youtube.com/@${account.id}';
        break;
      case 'twitch':
        url = 'https://www.twitch.tv/${account.id}';
        break;
      case 'twitter':
        url = 'https://twitter.com/${account.id}';
        break;

      default:
        url = null;
    }

    if (url != null) {
      await launchUrl(Uri.parse(url));
    } else {

    }
  }

  void _confirmDeleteSocialAccount(SocialAccount account) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Removal'),
          content: Text('Are you sure you want to remove this social account?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop();
                _deleteAccountFromFirestore(account);
              },
            ),
          ],
        );
      },
    );
  }


  Future<void> _deleteAccountFromFirestore(SocialAccount account) async {
    String userId = currentUser?.id ?? 'UNKNOWN';
    if (userId == 'UNKNOWN') return;

    CollectionReference userSocialAccounts = FirebaseFirestore.instance.collection('userSocialAccounts');
    DocumentReference userDoc = userSocialAccounts.doc(userId);

    await userDoc.update({
      '${account.platform}.accounts': FieldValue.arrayRemove([account.id])
    });

    setState(() {
      _accountsFuture = retrieveSocialAccounts();
    });
  }


  Future<void> _addSocialAccount() async {
    // Show the dialog
    await showDialog(
      context: context,
      builder: (context) => AddSocialAccountDialog(currentUser?.id ?? 'UNKNOWN'),
    );

    setState(() {
      _accountsFuture = retrieveSocialAccounts();
    });
  }

  void deletePicture(String imageUrl) async {
      Reference storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      await storageRef.delete();

      await FirebaseFirestore.instance.collection('users').doc(currentUser?.id).update({
        'pictures.others': FieldValue.arrayRemove([imageUrl])
      });

      setState(() {});
  }

  void triggerImageUpload() {
    setState(() {
      _shouldUploadImage = true;
      _uploadImage();
    });
  }


  Future<void> _uploadImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    _isUploading.value = true;
    if (pickedFile != null) {
      XFile? xfile = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path,
        '${Path.dirname(pickedFile.path)}/${Path.basenameWithoutExtension(pickedFile.path)}_compressed.jpg',
        quality: 30,
      );

      File file = File(xfile!.path);

      Reference storageRef = FirebaseStorage.instance.ref().child('user_pictures/${currentUser?.id}/${Path.basename(file.path)}');
      UploadTask uploadTask = storageRef.putFile(file);

      uploadTask.snapshotEvents.listen((snapshot) {
        _uploadProgress.value = snapshot.bytesTransferred.toDouble() / snapshot.totalBytes.toDouble();
      });

      TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
      String downloadURL = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(currentUser?.id).update({
        'pictures.others': FieldValue.arrayUnion([downloadURL])
      });
    }
    _isUploading.value = false;
  }


  Future<String?> showEditDialog({
    required BuildContext context,
    required String title,
    required Widget content,
    required Function() onUpdate,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: content,
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () {
                onUpdate();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  void editGender() async {
    final List<String> genderOptions = ['male', 'female'];
    String? selectedGender = currentUser?.gender;

    await showEditDialog(
      context: context,
      title: 'Edit Gender',
      content: DropdownButtonFormField<String>(
        value: selectedGender,
        items: genderOptions.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text('${value.substring(0, 1).toUpperCase()}${value.substring(1)}'),
          );
        }).toList(),
        onChanged: (String? newValue) {
          selectedGender = newValue;
        },
      ),
      onUpdate: () {
        // Update Firestore
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.id)
            .update({'gender': selectedGender}).then((_) {
          final snackBar = SnackBar(content: Text('Successfully updated profile'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        })
            .catchError((error) {
        });
      },
    );
  }

  void editReligion() async {
    // Fetch religions from Firestore first
    final religions = await FirebaseFirestore.instance
        .collection('religionOptions')
        .get();

    List<String> religionOptions =
    religions.docs.map((doc) => doc.id).toList();
    String? selectedReligion = currentUser?.religion;

    await showEditDialog(
      context: context,
      title: 'Edit Religion',
      content: DropdownButtonFormField<String>(
        value: selectedReligion,
        items: religionOptions.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          selectedReligion = newValue;
        },
      ),
      onUpdate: () {
        // Update Firestore
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.id)
            .update({'religion': selectedReligion}).then((_) {
          final snackBar = SnackBar(content: Text('Successfully updated profile'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        })
            .catchError((error) {
        });
      },
    );
  }

  void editCampusLocation() async {
    final campuses = await FirebaseFirestore.instance
        .collection('campusOptions')
        .get();

    List<String> campusOptions = campuses.docs.map((doc) => doc.id).toList();
    String? selectedCampus = currentUser?.campus;

    await showEditDialog(
      context: context,
      title: 'Edit Campus Location',
      content: DropdownButtonFormField<String>(
        value: selectedCampus,
        items: campusOptions.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: TextStyle(fontSize: 13),),
          );
        }).toList(),
        onChanged: (String? newValue) {
          selectedCampus = newValue;
        },
      ),
      onUpdate: () {
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.id)
            .update({'campus': selectedCampus}).then((_) {
          final snackBar = SnackBar(content: Text('Successfully updated profile'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        })
            .catchError((error) {
        });
      },
    );
  }

  void editLookingFor() async {
    final Map<String, int> lookingForOptions = {
      'Friends': 0,
      'A partner': 1,
      'Both friends and partner': 2
    };
    String? selectedValue = lookingForOptions.keys.firstWhere(
            (k) => lookingForOptions[k] == currentUser?.lookingFor,
        orElse: () => 'Friends'); // Default to 'Friends'

    await showEditDialog(
      context: context,
      title: 'Edit Looking For',
      content: DropdownButtonFormField<String>(
        value: selectedValue,
        items: lookingForOptions.keys.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          selectedValue = newValue;
        },
      ),
      onUpdate: () {
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.id)
            .update({'lookingFor': lookingForOptions[selectedValue]}).then((_) {
          final snackBar = SnackBar(content: Text('Successfully updated profile'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        })
            .catchError((error) {
        });
      },
    );
  }

  void editHeight() async {
    final TextEditingController heightController = TextEditingController();
    bool preferNotToSay = currentUser?.height == 'empty';

    await showEditDialog(
      context: context,
      title: 'Edit Height',
      content: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                enabled: !preferNotToSay,
                decoration: InputDecoration(
                  labelText: "Height (in cm)",
                ),
              ),
              Row(
                children: [
                  Text("Prefer not to say"),
                  Switch(
                    value: preferNotToSay,
                    onChanged: (bool value) {
                      setState(() {
                        preferNotToSay = value;
                      });
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
      onUpdate: () {
        int? height = int.tryParse(heightController.text);
        if (height != null && (height < 60 || height > 300) && !preferNotToSay) {
          final snackBar = SnackBar(content: Text('Input is out of range'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
          return;
        }
        if(!preferNotToSay && height == null){
          final snackBar = SnackBar(content: Text('Input is invalid'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
          return;
        }
        FirebaseFirestore.instance.collection('users').doc(currentUser?.id).update({
          'height': preferNotToSay ? 'empty' : height.toString(),
        }).then((_) {
          final snackBar = SnackBar(content: Text('Successfully updated profile'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        })
            .catchError((error) {
        });
      },
    );
  }

  void editDescription() async {
    final TextEditingController descriptionController = TextEditingController(text: currentUser?.description);

    bool isEditable = true;

    await showEditDialog(
      context: context,
      title: 'Edit Personal Description',
      content: TextField(
        controller: descriptionController,
        enabled: isEditable,
        maxLines: 3,
        maxLength: 200,
        decoration: InputDecoration(
          labelText: "Personal Description",
        ),
      ),
      onUpdate: () {
        if (descriptionController.text.length > 200) {
          final snackBar = SnackBar(content: Text('Description cannot exceed 200 chars!'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
          return;
        }

        setState(() {
          isEditable = false;
        });

        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.id)
            .update({'description': descriptionController.text}).then((_) {
          final snackBar = SnackBar(content: Text('Successfully updated profile'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        })
            .catchError((error) {
        });
      },
    );
  }

  void editInterests() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 200),)),
              SizedBox(width: 20),
              Text("Fetching options..")
            ],
          ),
        );
      },
    );

    final interestsDocs = await FirebaseFirestore.instance
        .collection('interestOptions')
        .get();

    List<String> allInterests = interestsDocs.docs.map((doc) => doc.id).toList();
    List<String> selectedInterests = currentUser?.interests?.split(',') ?? [];
    String searchText = '';

    Navigator.of(context).pop();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Interests'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {

              List<String> filterInterests() {
                return allInterests
                    .where((interest) =>
                    interest.toLowerCase().contains(searchText.toLowerCase()))
                    .toList();
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Search an interest...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchText = value;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10.0,
                        runSpacing: 10.0,
                        children: filterInterests()
                            .map((interest) => FilterChip(
                          label: Text(interest, style: TextStyle(color: selectedInterests.length < 9 || selectedInterests.contains(interest) ? Colors.white : Colors.grey)),
                          backgroundColor: selectedInterests.length < 9 || selectedInterests.contains(interest) ? Theme.of(context).cardColor : Colors.grey[400],
                          selectedColor: Colors.orange,
                          checkmarkColor: Colors.white,
                          selected: selectedInterests.contains(interest),
                          onSelected: (selected) {
                            if (selectedInterests.length < 9 || selectedInterests.contains(interest)) {
                              setState(() {
                                if (selected) {
                                  selectedInterests.add(interest);
                                } else {
                                  selectedInterests.remove(interest);
                                }
                              });
                            }
                          },
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () {
                if (selectedInterests.length <= 9) {
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser?.id)
                      .update({'interests': selectedInterests.join(',')}).then((_) {
                    final snackBar = SnackBar(content: Text('Successfully updated profile'));
                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  })
                      .catchError((error) {
                  });
                  Navigator.of(context).pop();
                } else {
                  final snackBar = SnackBar(content: Text('You can select up to 9 interests'));
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                }
              },
            ),
          ],
        );
      },
    );
  }

}

class AddSocialAccountDialog extends StatefulWidget {
  final String userId;
  const AddSocialAccountDialog(this.userId, {Key? key}) : super(key: key);

  @override
  State<AddSocialAccountDialog> createState() => _AddSocialAccountDialogState();
}

class _AddSocialAccountDialogState extends State<AddSocialAccountDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Map<String, String> platformDisplayNames = {
    'whatsapp': 'WhatsApp',
    'instagram': 'Instagram',
    'line': 'LINE',
    'tiktok': 'TikTok',
    'pinterest': 'Pinterest',
    'discord': 'Discord',
    'snapchat': 'Snapchat',
    'youtube': 'YouTube',
    'twitch': 'Twitch',
    'steam': 'Steam',
    'roblox': 'Roblox',
    'facebook': 'Facebook',
    'twitter': 'Twitter/X',
    'custom': 'Custom Text'
  };

  Map<String, String> platformGuidelines = {
    'whatsapp': 'For best experience, enter your phone number registered in WhatsApp in the format of (Ext)(Number). So if you have a number \'081199786565\' in Indonesia, you need to input 6281199786565.',
    'instagram': 'For best experience, enter your Instagram username without the \'@\' in front. So if your username is \'@joe.n\', you need to input \'joe.n\'',
    'line': 'There is no specific guidelines for this platform.',
    'tiktok': 'For best experience, enter your TikTok username without the \'@\' in front. So if your username is \'@joe2\', you need to input \'joe2\'',
    'pinterest': 'For best experience, enter your Pinterest username without the \'@\' in front. So if your username is \'@joe2\', you need to input \'joe2\'',
    'discord': 'There is no specific guidelines for this platform',
    'snapchat': 'There is no specific guidelines for this platform',
    'youtube': 'For best experience, enter your YouTube Channel Handle, you can find it in your channel page. It starts with an \'@\', but do not include the \'@\' in here',
    'twitch': 'For best experience, enter your exact Twitch username in here',
    'steam': 'There is no specific guidelines for this platform',
    'roblox': 'There is no specific guidelines for this platform',
    'facebook': 'There is no specific guidelines for this platform',
    'twitter': 'For best experience, enter your Twitter/X username without the \'@\' in front. So if your username is \'@joe2\', you need to input \'joe2\'',
    'custom': 'This is a custom text meant for other platforms that is not listed here, you can simply mention the name of the platform alongside your identifiable ID/username'
  };

  Map<String, String> platformHints = {
    'whatsapp': 'Phone, ex: \'628177656653\'',
    'instagram': 'Username, ex: \'john.doe\'',
    'line': 'Username, ex: \'johndoe1\'',
    'tiktok': 'Username, ex: \'johndoe_tiktok\'',
    'pinterest': 'Username, ex: \'johndoe3\'',
    'discord': 'Username, ex: \'johndoe_\'',
    'snapchat': 'Username, ex: \'j0hndoe\'',
    'youtube': 'Handle, ex: \'johndoe1827\'',
    'twitch': 'Username, ex: \'johndoe_streams\'',
    'steam': 'Profile Name, ex: \'John Doe Gaming\'',
    'roblox': 'Username, ex: \'JohnDoe123\'',
    'facebook': 'Name, ex: \'John Doe\'',
    'twitter': 'Username, ex: \'john_doe\'',
    'custom': 'Text, ex: \'PlatformName: johndoe_1\''
  };

  String selectedPlatform = 'instagram'; // Default value
  String accountId = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Text('Add ${platformDisplayNames[selectedPlatform]}'),
          const SizedBox(width: 15),
          SvgPicture.asset('assets/icon_${selectedPlatform}.svg', height: 30),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DropdownButtonFormField<String>(
              value: selectedPlatform,
              hint: Text('Select Platform'),
              onChanged: (newValue) {
                setState(() {
                  selectedPlatform = newValue!;
                });
              },
              items: platformDisplayNames.entries.map<DropdownMenuItem<String>>((MapEntry<String, String> entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: '${platformHints[selectedPlatform]}',
                      hintText: 'Tap on the (i) info icon for guide',
                      hintMaxLines: 3,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter account ID';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      accountId = value!;
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.info_outline, size: 25),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text('Guidelines for ${platformDisplayNames[selectedPlatform]}'),
                          content: Text(platformGuidelines[selectedPlatform] ?? 'No guidelines available', style: TextStyle(fontSize: 14)),
                          actions: <Widget>[
                            TextButton(
                              child: Text('OK'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text('Add'),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              Navigator.of(context).pop();
              await ProfileState.addSocialAccountToFirestore(widget.userId, SocialAccount(platform: selectedPlatform, id: accountId));
            }
          },
        ),
      ],
    );
  }
}