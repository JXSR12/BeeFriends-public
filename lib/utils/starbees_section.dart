import 'package:BeeFriends/matchmake_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import 'display_utils.dart';
import 'notification_manager.dart';

class StarbeesSection extends StatefulWidget {
  final CompleteUser currentUser;

  StarbeesSection({Key? key, required this.currentUser}) : super(key: key);

  @override
  StarbeesSectionState createState() => StarbeesSectionState(currentUser);
}

class StarbeesSectionState extends State<StarbeesSection> {
  final CompleteUser currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _current = 0;
  final CarouselController _carouselController = CarouselController();

  StarbeesSectionState(this.currentUser);

  Future<String?> _getActiveTimeSlotId() async {
    DocumentSnapshot snapshot = await _firestore.collection('globalPlatformState').doc('activeStarbeeTimeSlot').get();
    return snapshot['id'];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('globalPlatformState').doc('activeStarbeeTimeSlot').snapshots(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> timeSlotSnapshot) {
        if (timeSlotSnapshot.hasData && timeSlotSnapshot.data != null) {
          String? activeTimeSlotId = timeSlotSnapshot.data!.get('id');
          Timestamp activeDateTimestamp = timeSlotSnapshot.data!.get('activeDate');
          DateTime activeDate = activeDateTimestamp.toDate();
          DateTime startDate = DateTime(activeDate.year, activeDate.month, activeDate.day);
          DateTime endDate = DateTime(activeDate.year, activeDate.month, activeDate.day + 1);

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('starbeesPool')
                .where('timeSlotId', isEqualTo: activeTimeSlotId)
                .where('date', isGreaterThanOrEqualTo: startDate)
                .where('date', isLessThan: endDate)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                List<DocumentSnapshot> documents = snapshot.data!.docs;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => showStarbeesInfo(context),
                      child: Chip(
                        padding: EdgeInsets.only(left: 5, right: 5),
                        elevation: 5,
                        backgroundColor: Colors.green.withOpacity(0.1),
                        avatar: Icon(Icons.star_rounded, color: Colors.amber),
                        label: Text('Hottest Profiles at the Moment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                      ),
                    ),
                    CarouselSlider.builder(
                      itemCount: documents.length,
                      itemBuilder: (context, index, realIndex) {
                        var profile = documents[index];
                        return _buildProfileCard(profile);
                      },
                      options: CarouselOptions(
                        enlargeFactor: 0.2,
                        autoPlay: true,
                        autoPlayInterval: Duration(seconds: 7),
                        enlargeCenterPage: true,
                        onPageChanged: (index, reason) {
                          setState(() {
                            _current = index;
                          });
                        },
                      ),
                      carouselController: _carouselController,
                    ),
                  ],
                );
              } else if (snapshot.hasData && snapshot.data!.docs.isEmpty) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => showStarbeesInfo(context),
                      child: Chip(
                        padding: EdgeInsets.only(left: 5, right: 5),
                        elevation: 5,
                        backgroundColor: Colors.green.withOpacity(0.1),
                        avatar: Icon(Icons.info_outline_rounded, color: Colors.amber),
                        label: Text('The Starbees Program', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: 180,
                      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.black, Colors.green.shade900],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.5),
                            spreadRadius: 1,
                            blurRadius: 2,
                            offset: Offset(1, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_outline_rounded, size: 48, color: Colors.amber),
                          SizedBox(height: 10),
                          Text(
                            'No Starbees to show',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'You can be here for the next time slot by purchasing it on the bottom section of your profile page.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                // Show loading indicator when waiting for data
                return SizedBox(height: 30, child: SpinKitWave(color: Colors.white60, duration: Duration(milliseconds: 300),));
              }
            },
          );
        } else {
          return Center(child: Text('No active time slot found'));
        }
      },
    );
  }

  Widget _buildProfileCard(DocumentSnapshot profile) {
    IconData genderIcon = profile['gender'] == 'Male' ? Icons.male_rounded : Icons.female_rounded;
    String promotionMessage = profile['promotionMessage'];
    int cost = (profile['requestCost'] as num).toInt();

    return GestureDetector(
      onTap: () {
        FirebaseFirestore.instance.collection('starbeesPool').doc(profile.id)
            .update({'views': FieldValue.increment(1)});
        _showProfileDetails(context, profile);
      },
      child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 3, horizontal: 10),
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: _buildBoxDecoration(),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(padding: EdgeInsets.only(top: 0, bottom: 5),
                            child:
                            Icon(genderIcon, size: 25, color: profile['gender'] == 'Male' ? Colors.blue : Colors.pink)
                        ),
                        Text("${profile['fgy']}, ${profile['gender']}, ${profile['major']}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),),
                        SizedBox(height: 10),
                        Card(
                          color: Colors.white.withOpacity(0.2),
                          elevation: 4,
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Text(promotionMessage, style: TextStyle(fontStyle: FontStyle.normal, fontSize: 11, color: Colors.green.shade200), maxLines: 2, overflow: TextOverflow.ellipsis,),
                          ),
                        ),
                        _buildSendRequestButton(cost, profile),
                      ],
                    ),
                  ),
                ],
              ),
                SizedBox(height: 5,),
                Text('Tap to view profile details', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white54),)
              ]
          )
      ),
    );
  }

  Future<void> _showProfileDetails(BuildContext context, DocumentSnapshot profile) async {
    final candidate = await MatchmakePageState.getCandidateDetails(profile.id);
    final beetsCost = await (profile['requestCost'] as num).toInt();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:  Card(
          color: Colors.black54,
          elevation: 2.0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5.0)
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              'Starbee Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Image.asset('assets/unknown_avatar.png', width: 60, height: 60),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      candidate?['gender'] == 'male' ? Icons.male : Icons.female,
                      color: candidate?['gender'] == 'male' ? Colors.blue : Colors.pink,
                    ),
                    SizedBox(width: 5),
                    Text(candidate?['gender'] == 'male' ? 'Male' : 'Female'),
                  ],
                ),
              ),
              SizedBox(height: 10,),
              ElevatedButton.icon(
                icon: Icon(Icons.help_outline),
                label: Text('Relative Age Information'),
                onPressed: () {
                  if (currentUser?.birthDate != null && candidate?['birthDate'] != null) {
                    DateTime currentUserBirthDate = DateTime.parse(currentUser?.birthDate ?? '1990-01-01T00:00:00');
                    DateTime candidateBirthDate = DateTime.parse(candidate?['birthDate'] ?? '1990-01-01T00:00:00');

                    int ageDifference = MatchmakePageState.calculateAgeDifference(currentUserBirthDate, candidateBirthDate);
                    String ageMessage;
                    if (ageDifference.abs() > 1) {
                      ageMessage = "This person is about ${ageDifference.abs()} years ${ageDifference > 0 ? 'older' : 'younger'} than you";
                    } else if (ageDifference == 0) {
                      ageMessage = "This person is about the same age as you";
                    } else {
                      ageMessage = "This person is about 1 year ${ageDifference > 0 ? 'older' : 'younger'} than you";
                    }

                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Relative Age Information'),
                          content: Text(ageMessage),
                          actions: <Widget>[
                            TextButton(
                              child: Text('Dismiss'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Relative Age Information'),
                          content: Text('Sorry, but we are unable to retrieve age information at this time'),
                          actions: <Widget>[
                            TextButton(
                              child: Text('Dismiss'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
              ),
              SizedBox(height: 10),
              Text('B${candidate?['studentNumber'].substring(0, 2)}, ${candidate?['major']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.black, fontFamily: GoogleFonts.quicksand().fontFamily),
                  children: [
                    TextSpan(text: 'Campus location: '),
                    TextSpan(text: '${candidate?['campus']}', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.black, fontFamily: GoogleFonts.quicksand().fontFamily),
                  children: [
                    TextSpan(text: 'Religion: '),
                    TextSpan(text: '${candidate?['religion']}', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.black, fontFamily: GoogleFonts.quicksand().fontFamily),
                  children: [
                    TextSpan(text: 'Looking for '),
                    TextSpan(text: '${candidate!['lookingFor'] == 0 ? 'friends' : candidate!['lookingFor'] == 1 ? 'a partner' : 'both friends and partner'}', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.black, fontFamily: GoogleFonts.quicksand().fontFamily),
                  children: [
                    TextSpan(text: 'Height: '),
                    TextSpan(
                        text: candidate?['height'] == 'empty' ? 'Prefer not to say' : '${candidate?['height']} cm',
                        style: TextStyle(fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Card(
                color: Colors.white.withOpacity(0.7),
                elevation: 4.0,
                margin: EdgeInsets.symmetric(horizontal: 20.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: SingleChildScrollView(child: Text('${candidate?['description']}')),
                ),
              ),
              SizedBox(height: 10),
              Text('Interested in'),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 100,
                ),
                child: SingleChildScrollView(scrollDirection: Axis.horizontal, child:
                Wrap(
                  runSpacing: 2.0,
                  spacing: 2.0,
                  children: DisplayUtils.displayInterestsForMap(candidate),
                ),
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black),
                        children: [
                          TextSpan(
                            text: ' If you choose to \'Send Request\' to this Starbee, ',
                          ),
                          WidgetSpan(
                            child: SvgPicture.asset('assets/beets_icon.svg', height: 15, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                          ),
                          TextSpan(
                            text: ' $beetsCost Beets',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: ' will be consumed and will NOT be refunded even if the Starbee declines your matching request.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildBoxDecoration() {
    return BoxDecoration(
      color: Colors.amber[50],
      borderRadius: BorderRadius.circular(10),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.black, Colors.green.shade900],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.green.withOpacity(0.5),
          spreadRadius: 1,
          blurRadius: 2,
          offset: Offset(1, 2),
        ),
      ],
    );
  }

  Future<bool> checkIfMatchOrFriend(DocumentSnapshot profile) async {
    var userId = currentUser?.id;// Assuming currentUser holds the current user's data
    var profileUserId = profile.id;

    var friendDoc = await FirebaseFirestore.instance
        .doc('users/$userId/friends/$profileUserId')
        .get();
    var matchDoc = await FirebaseFirestore.instance
        .doc('users/$userId/matches/$profileUserId')
        .get();
    var sentReqDoc = await FirebaseFirestore.instance
        .doc('users/$userId/sentRequests/$profileUserId')
        .get();
    var incReqDoc = await FirebaseFirestore.instance
        .doc('users/$userId/matchingRequests/$profileUserId')
        .get();

    return friendDoc.exists || matchDoc.exists || sentReqDoc.exists || incReqDoc.exists;
  }

  Widget _buildSendRequestButton(int cost, DocumentSnapshot profile) {
    return FutureBuilder<bool>(
      future: checkIfMatchOrFriend(profile),
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.only(left: 4, right: 4),
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, disabledBackgroundColor: Colors.green.shade900, disabledForegroundColor: Colors.grey),
                onPressed: null,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Loading relationship..'),
                  ],
                )
            ),
          );
        }

        bool isMatchOrFriend = snapshot.data ?? false;

        if(currentUser?.id == profile.id) isMatchOrFriend = true;

        return Padding(
          padding: EdgeInsets.only(left: 4, right: 4),
          child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, disabledBackgroundColor: Colors.green.shade900, disabledForegroundColor: Colors.redAccent),
              onPressed: isMatchOrFriend ? null : () {
                FirebaseFirestore.instance.collection('starbeesPool').doc(profile.id)
                    .update({'views': FieldValue.increment(1)});
                _requestMatch(cost, profile);
              },
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isMatchOrFriend ? 'Already in your match or friend list' : 'Send Request for $cost '),
                  if(!isMatchOrFriend)
                    SvgPicture.asset('assets/beets_icon.svg', height: 14, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                ],
              )
          ),
        );
      },
    );
  }

  Future<void> _requestMatch(int cost, DocumentSnapshot starbee) async {
    // Check if the user is already a match or friend or a request is pending
    bool isMatchOrFriend = await checkIfMatchOrFriend(starbee);
    if (currentUser?.id == starbee.id) isMatchOrFriend = true;

    if (isMatchOrFriend) {
      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text("Request Not Allowed"),
            content: Text("You are already a friend or match of this profile or a request is already pending."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Dismiss")
              )
            ],
          )
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SpecialMessageDialog(initialBeetsCost: cost, isStarbee: true),
    ) ?? {'proceed': false};

    final shouldProceed = result['proceed'] as bool;
    final addedMessage = result['message'] as String;
    final updatedBeetsCost = result['beetsCost'] as int;

    if (shouldProceed) {
      final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser?.id);
      DocumentSnapshot userSnapshot = await userRef.get();
      int? currentBeets = (userSnapshot.get('beets') as num).toInt();

      if (currentBeets == null || currentBeets < updatedBeetsCost) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Insufficient Beets"),
              content: Text("You do not have enough Beets to send a matching request."),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text("Dismiss")
                )
              ],
            );
          },
        );
        return;
      }

      await userRef.update({
        'beets': FieldValue.increment(-1 * updatedBeetsCost),
      });

      final candidateRef = FirebaseFirestore.instance.collection('users').doc(starbee.id);
      final matchingRequestCollection = candidateRef.collection('matchingRequests');

      await matchingRequestCollection.doc(currentUser?.id).set({
        'timestamp': FieldValue.serverTimestamp(),
        'paidMessage': addedMessage,
        'beetsCost': cost,
      });

      final sentRequestsCollection = userRef.collection('sentRequests');
      await sentRequestsCollection.doc(starbee.id).set({
        'timestamp': FieldValue.serverTimestamp(),
        'paidMessage': addedMessage,
        'beetsCost': cost,
      });

      FirebaseFirestore.instance.collection('starbeesPool').doc(starbee.id)
          .update({'requests': FieldValue.increment(1)});

      NotificationManager.addMatchRequestNotification(currentUser?.id ?? 'UNKNOWN', candidateRef.id, addedMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Match request has been sent."),
          backgroundColor: Colors.black54,
        ),
      );
    }

    Navigator.pop(context);
  }

  static void showStarbeesInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'The Starbees', style: TextStyle(fontWeight: FontWeight.bold),),
          content: Text(
              'These same profiles are shown to all BeeFriends users, refreshed once every three hours. \n\nGet your profile up here to gain more visibility and increase potential incoming match requests. \n\nYou can purchase the slot for The Starbees on the bottom section of your Profile page.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

    static void showStarbeesInfoAlt(BuildContext context) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('The Starbees', style: TextStyle(fontWeight: FontWeight.bold),),
            content: Text('The starbee profiles are shown to all BeeFriends users, refreshed once every three hours. \n\nGet your profile up there to gain more visibility and increase potential incoming match requests. \n\nYou can purchase a slot now by tapping on the Purchase button or check if you have any active Starbee bookings here.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
}
