import 'package:BeeFriends/matchmake_page.dart';
import 'package:BeeFriends/utils/display_utils.dart';
import 'package:BeeFriends/utils/notification_manager.dart';
import 'package:BeeFriends/utils/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:BeeFriends/main.dart';

class MatchRequestsPage extends StatefulWidget {
  @override
  _MatchRequestsPageState createState() => _MatchRequestsPageState();
}

class _MatchRequestsPageState extends State<MatchRequestsPage> with TickerProviderStateMixin{
  late TabController _tabController;
  late CompleteUser? currentUser = null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Matching Requests"),
        bottom: TabBar(
          controller: _tabController,
          tabs: <Widget>[
            Tab(
              icon: Icon(Icons.send, color: Colors.white),
              child: Text("Sent", style: TextStyle(color: Colors.white)),
            ),
            Tab(
              icon: Icon(Icons.inbox, color: Colors.white),
              child: Text("Received", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSentTab(),
          _buildReceivedTab(),
        ],
      ),
    );
  }

  Widget _buildSentTab() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection('sentRequests').orderBy('timestamp', descending: true).snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: SizedBox(
              width: 50.0,
              height: 50.0,
              child: SizedBox(height: 100, child: SpinKitWave(color: Colors.white70, duration: Duration(milliseconds: 400))),
            ),
          );
        }

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.outgoing_mail,
                    color: Colors.black54,
                    size: 60.0,
                  ),
                  SizedBox(height: 20.0),
                  Text(
                    'No requests yet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text(
                    'Uh-oh! It seems like you haven\'t sent any matching requests yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var request = snapshot.data!.docs[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(request.id).get(),
              builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.done && userSnapshot.hasData) {
                  var user = userSnapshot.data!;
                  String gender = user['gender'].toString().capitalizeFirst;
                  String studentDetails = 'B${user['studentNumber'].substring(0, 2)}, ${user['major']}';
                  String requestTimeAgo = "Requested ${_getTimeAgo(request['timestamp'])}";

                  return Container(
                    color: Colors.black.withAlpha(index % 2 == 0 ? 5 : 10),
                    child: ListTile(
                      title: Text("$gender, $studentDetails"),
                      subtitle: Text(requestTimeAgo),
                      onTap: () => _showRequestDetails(request, 'sent'),
                      leading: Icon(
                        user['gender'] == 'male' ? Icons.male : Icons.female,
                        color: user['gender'] == 'male' ? Colors.blue : Colors.pink,
                        size: 40,
                      ),
                    ),
                  );
                } else if (userSnapshot.connectionState == ConnectionState.none) {
                  return Text('Something went wrong');
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      // Square on the left for the icon
                      Container(
                        width: 40.0,
                        height: 40.0,
                        color: Colors.white.withAlpha(50),
                      ),
                      SizedBox(width: 20.0),
                      // Vertical stack for text placeholders
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bigger rectangle for upper text
                            Container(
                              width: double.infinity,
                              height: 20.0,
                              color: Colors.white.withAlpha(50),
                              margin: EdgeInsets.only(bottom: 5.0),
                            ),
                            // Smaller rectangle for the caption
                            Container(
                              width: 150.0,
                              height: 15.0,
                              color: Colors.white.withAlpha(50),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            );
          },
        );

      },
    );
  }

  Widget _buildReceivedTab() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection('matchingRequests').orderBy('timestamp', descending: true).snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: SizedBox(
              width: 50.0,
              height: 50.0,
              child: SizedBox(height: 100, child: SpinKitWave(color: Colors.white70, duration: Duration(milliseconds: 400))),
            ),
          );
        }

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.email_outlined,
                    color: Colors.black54,
                    size: 60.0,
                  ),
                  SizedBox(height: 20.0),
                  Text(
                    'No requests yet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text(
                    'Uh-oh! It seems like you haven\'t received any matching requests yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var request = snapshot.data!.docs[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(request.id).get(),
              builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.done && userSnapshot.hasData) {
                  var user = userSnapshot.data!;
                  String gender = user['gender'].toString().capitalizeFirst;
                  String studentDetails = 'B${user['studentNumber'].substring(0, 2)}, ${user['major']}';
                  String requestTimeAgo = "Received ${_getTimeAgo(request['timestamp'])}";

                  return Container(
                    color: Colors.black.withAlpha(index % 2 == 0 ? 5 : 10),
                    child: ListTile(
                      title: Text("$gender, $studentDetails"),
                      subtitle: Text(requestTimeAgo),
                      onTap: () => _showRequestDetails(request, 'received'),
                      leading: Icon(
                        user['gender'] == 'male' ? Icons.male : Icons.female,
                        color: user['gender'] == 'male' ? Colors.blue : Colors.pink,
                        size: 40,
                      ),
                    ),
                  );
                } else if (userSnapshot.connectionState == ConnectionState.none) {
                  return Text('Something went wrong');
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      // Square on the left for the icon
                      Container(
                        width: 40.0,
                        height: 40.0,
                        color: Colors.white.withAlpha(50),
                      ),
                      SizedBox(width: 20.0),
                      // Vertical stack for text placeholders
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bigger rectangle for upper text
                            Container(
                              width: double.infinity,
                              height: 20.0,
                              color: Colors.white.withAlpha(50),
                              margin: EdgeInsets.only(bottom: 5.0),
                            ),
                            // Smaller rectangle for the caption
                            Container(
                              width: 150.0,
                              height: 15.0,
                              color: Colors.white.withAlpha(50),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            );
          },
        );

      },
    );
  }


  String _getTimeAgo(Timestamp timestamp) {
    final currentTime = DateTime.now();
    final requestTime = timestamp.toDate();
    print(currentTime);
    print(requestTime);
    final difference = currentTime.difference(requestTime);

    if(difference.inSeconds < 0){
      return 'on unknown (Your device time is invalid)';
    }

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      // Return the full date
      return 'on ${requestTime.day} ${monthNames[requestTime.month - 1]} ${requestTime.year}, at ${requestTime.hour}:${requestTime.minute.toString().padLeft(2, '0')}';
    }
  }

// List of month names to use in date formatting
  final monthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];


  void _showRequestDetails(DocumentSnapshot request, String type) {
    FirebaseFirestore.instance.collection('users').doc(request.id).get().then((DocumentSnapshot candidate) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title:  Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              if((request.data() as Map<String, dynamic>)['paidMessage'] != null && (request.data() as Map<String, dynamic>)['paidMessage'].toString().isNotEmpty)
              Card(
                color: Colors.black54,
                elevation: 2.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text(
                    'Special Message',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if((request.data() as Map<String, dynamic>)['paidMessage'] != null && (request.data() as Map<String, dynamic>)['paidMessage'].toString().isNotEmpty)
              Card(
                color: Colors.white.withOpacity(0.7),
                elevation: 4.0,
                margin: EdgeInsets.symmetric(horizontal: 20.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: SingleChildScrollView(child: Text('${request['paidMessage']}')),
                ),
              ),
              if((request.data() as Map<String, dynamic>)['paidMessage'] != null && (request.data() as Map<String, dynamic>)['paidMessage'].toString().isNotEmpty)
              const SizedBox(height: 8,),
              Card(
                color: Colors.black54,
                elevation: 2.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text(
                    'Candidate Details',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            ],),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  SizedBox(height: 5),
                  Image.asset('assets/unknown_avatar.png', width: 60, height: 60),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          candidate['gender'] == 'male' ? Icons.male : Icons.female,
                          color: candidate['gender'] == 'male' ? Colors.blue : Colors.pink,
                        ),
                        SizedBox(width: 5),
                        Text(candidate['gender'] == 'male' ? 'Male' : 'Female'),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: Icon(Icons.help_outline),
                    label: Text('Relative Age Information'),
                    onPressed: () {
                      if (currentUser?.birthDate != null && candidate['birthDate'] != null) {
                        DateTime currentUserBirthDate = DateTime.parse(currentUser?.birthDate ?? '1990-01-01T00:00:00');
                        DateTime candidateBirthDate = DateTime.parse(candidate['birthDate'] ?? '1990-01-01T00:00:00');

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
                  Text('B${candidate['studentNumber'].substring(0, 2)}, ${candidate['major']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.black, fontFamily: GoogleFonts.quicksand().fontFamily),
                      children: [
                        TextSpan(text: 'Campus location: '),
                        TextSpan(text: '${candidate['campus']}', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.black, fontFamily: GoogleFonts.quicksand().fontFamily),
                      children: [
                        TextSpan(text: 'Religion: '),
                        TextSpan(text: '${candidate['religion']}', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            text: candidate['height'] == 'empty' ? 'Prefer not to say' : '${candidate['height']} cm',
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
                      child: SingleChildScrollView(child: Text('${candidate['description']}')),
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
                      children: DisplayUtils.displayInterests(candidate),
                    ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              if (type == 'sent')
              Container(
                width: double.infinity,
                child: ButtonTheme(
                  minWidth: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Confirmation"),
                          content: Text("If you withdraw the request, the candidate would not be able to respond to it anymore, and the Beets that you have spent for this request will NOT be refunded. Proceed to withdraw?"),
                          actions: <Widget>[
                            ElevatedButton(
                              onPressed: () async {
                                // Removing from the sender's sentRequests
                                await FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection('sentRequests').doc(candidate.id).delete();
                                // Removing from the receiver's matchingRequests
                                await FirebaseFirestore.instance.collection('users').doc(candidate.id).collection('matchingRequests').doc(currentUser?.id).delete();

                                Navigator.pop(context);  // Close the confirmation dialog
                                Navigator.pop(context);  // Close the request details dialog
                              },
                              child: Text('Yes'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('No'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text('Withdraw Request'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, textStyle: TextStyle(color: Colors.white)),
                  ),
                ),
              )else
              if (type == 'received')
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final requestRef = FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection('matchingRequests').doc(candidate.id);

                        DocumentSnapshot requestSnapshot = await requestRef.get();
                        Map<String, dynamic>? requestData = requestSnapshot.data() as Map<String, dynamic>?;

                        if (requestData == null) return;

                        final requestBeetsCost = requestData['beetsCost'];
                        final beetsCost = 5 - requestBeetsCost;

                        final shouldProceed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Confirmation'),
                            content: RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 14, color: Colors.black),
                                children: [
                                  TextSpan(
                                    text: 'By pressing the \'Confirm\' button below, you will have to spend ',
                                  ),
                                  WidgetSpan(
                                    child: SvgPicture.asset('assets/beets_icon.svg', height: 15, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                                  ),
                                  TextSpan(
                                    text: ' $beetsCost Beets',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: ', and you will accept this candidate as your match.',
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: Text('Confirm'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: Text('Cancel'),
                              ),
                            ],
                          ),
                        ) ?? false;

                        if (shouldProceed){
                          final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser?.id);
                          DocumentSnapshot userSnapshot = await userRef.get();
                          int? currentBeets = (userSnapshot.get('beets') as num).toInt();

                          if (currentBeets == null || currentBeets < beetsCost) {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text("Insufficient Beets"),
                                  content: Text("You do not have enough Beets to accept this request."),
                                  actions: [
                                    ElevatedButton(
                                        onPressed: () {
                                          // Navigate to purchase page or initiate the purchase flow
                                          // For now, we'll just pop the dialog.
                                          Navigator.pop(context);
                                        },
                                        child: Text("Purchase Beets")
                                    ),
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
                            'beets': FieldValue.increment(-1 * beetsCost),
                          });

                          // Deleting from the receiver's matchingRequests
                          await FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection('matchingRequests').doc(candidate.id).delete();

                          // Deleting from the sender's sentRequests
                          await FirebaseFirestore.instance.collection('users').doc(candidate.id).collection('sentRequests').doc(currentUser?.id).delete();

                          // Creating the match
                          DocumentReference chatRoom = await FirebaseFirestore.instance.collection('chats').add({});

                          String chatRoomId = chatRoom.id;

                          // Adding unread counts for each user in the newly created chat room
                          await chatRoom.collection('unreadCounts').doc(currentUser?.id).set({
                            'count': 0
                          });

                          await chatRoom.collection('unreadCounts').doc(candidate.id).set({
                            'count': 0
                          });

                          // Updating both users' matches subcollection
                          FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection('matches').doc(candidate.id).set({
                            'timestamp': FieldValue.serverTimestamp(),
                            'chatRoomId': chatRoom.id,
                          });

                          FirebaseFirestore.instance.collection('users').doc(candidate.id).collection('matches').doc(currentUser?.id).set({
                            'timestamp': FieldValue.serverTimestamp(),
                            'chatRoomId': chatRoom.id,
                          });

                          NotificationManager.addMatchStatusNotification(candidate.id, currentUser?.id ?? 'UNKNOWN', chatRoomId, 'accepted');
                        }


                        Navigator.pop(context);  // Close the request details dialog
                      },
                      child: Text('Accept Request'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        // Deleting from the receiver's matchingRequests
                        await FirebaseFirestore.instance..collection('users').doc(currentUser?.id).collection('matchingRequests').doc(candidate.id).delete();

                        // Deleting from the sender's sentRequests
                        await FirebaseFirestore.instance..collection('users').doc(candidate.id).collection('sentRequests').doc(currentUser?.id).delete();

                        NotificationManager.addMatchStatusNotification(candidate.id, currentUser?.id ?? 'UNKNOWN', 'DECLINED_NO_CHATROOM', 'declined');

                        Navigator.pop(context);
                      },
                      child: Text('Decline Request'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ],
                )
            ],
          );
        },
      );
    });
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

}

extension StringExtension on String {
  String get capitalizeFirst {
    if (this.isEmpty) {
      return this;
    }
    return this[0].toUpperCase() + this.substring(1);
  }
}

