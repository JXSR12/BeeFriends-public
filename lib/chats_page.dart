import 'package:BeeFriends/utils/data_manager.dart';
import 'package:BeeFriends/utils/nickname_manager.dart';
import 'package:BeeFriends/utils/user_provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_notification/in_app_notification.dart';
import 'package:intl/intl.dart';

import 'chat_room.dart';
import 'package:BeeFriends/main.dart';

class ChatsPage extends StatefulWidget {
  @override
  _ChatsPageState createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> with TickerProviderStateMixin {
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
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 2),
                blurRadius: 4.0,
              ),
            ],
          ),
          child: TabBar(
            indicatorColor: Colors.orange.shade900,
            controller: _tabController,
            tabs: <Widget>[
              Tab(
                icon: Icon(Icons.star),
                child: Text("Matches", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Tab(
                icon: Icon(Icons.group),
                child: Text("Friends", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white30, // Set the background color to white
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMatchesTab(),
                _buildFriendsTab(),
              ],
            ),
          )
        ),
      ],
    );
  }

  Widget _buildMatchesTab() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection('matches').orderBy('lastMessageTimestamp', descending: true).snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: SizedBox(
              width: 50.0,
              height: 50.0,
              child: SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 200))),
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
                    Icons.heart_broken_outlined,
                    color: Colors.black54,
                    size: 60.0,
                  ),
                  SizedBox(height: 20.0),
                  Text(
                    'No matches yet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text(
                    'Click the heart shaped icon in the navigation and find a match to chat with them.',
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
            var match = snapshot.data!.docs[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(match.id).get(),
              builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.done && userSnapshot.hasData) {
                  var user = userSnapshot.data!;
                  String gender = user['gender'].toString().capitalizeFirst;
                  String studentDetails = 'B${user['studentNumber'].substring(0, 2)}, ${user['major']}';
                  String matchTimeAgo = "Matched ${_getTimeAgo(match['timestamp'])}";

                  return Container(
                    padding: EdgeInsets.only(top: 10, bottom: 5),
                    color: Colors.black.withAlpha(index % 2 == 0 ? 5 : 10),
                    child: ListTile(
                      title: Text(NicknameManager.getNickname(match.id, "$gender, $studentDetails"), style: TextStyle(fontSize: 16),),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(matchTimeAgo, style: TextStyle(fontSize: 12)),
                          SizedBox(height: 5,),
                          _buildLastMessage(match)
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ChatRoom(
                              chatRoomId: match['chatRoomId'],
                              recipientId: match.id,
                              chatRoomType: 'match',
                            ),
                          ),
                        );
                      },
                      onLongPress: () {
                        showModalBottomSheet(
                          constraints: BoxConstraints.tight(Size.fromHeight(200)),
                          context: context,
                          builder: (context) {
                            return _buildChatOptionsBuilder(match, false);
                          },
                        );
                      },
                      leading: Icon(
                        user['gender'] == 'male' ? Icons.male : Icons.female,
                        color: user['gender'] == 'male' ? Colors.blue : Colors.pink,
                        size: 40,
                      ),
                      trailing: _buildTrailingInfo(match),
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

  Widget _buildFriendsTab() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection('friends').orderBy('lastMessageTimestamp', descending: true).snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: SizedBox(
              width: 50.0,
              height: 50.0,
              child: SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 200))),
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
                    Icons.group_add_outlined,
                    color: Colors.black54,
                    size: 60.0,
                  ),
                  SizedBox(height: 20.0),
                  Text(
                    'No friends yet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text(
                    'Add friends from your matches first to see them here.',
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
            var match = snapshot.data!.docs[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(match.id).get(),
              builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.done && userSnapshot.hasData) {
                  var user = userSnapshot.data!;
                  String name = formatName(user['name']);

                  return Container(
                      padding: EdgeInsets.only(top: 10, bottom: 5),
                      color: Colors.black.withAlpha(index % 2 == 0 ? 5 : 10),
                      child: ListTile(
                        title: Text(name, style: TextStyle(fontSize: 18),),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 5,),
                            _buildLastMessage(match)
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ChatRoom(
                                chatRoomId: match['chatRoomId'],
                                recipientId: match.id,
                                chatRoomType: 'friend',
                              ),
                            ),
                          );
                        },
                        onLongPress: () {
                          showModalBottomSheet(
                            constraints: BoxConstraints.tight(Size.fromHeight(200)),
                            context: context,
                            builder: (context) {
                              return _buildChatOptionsBuilder(match, true);
                            },
                          );
                        },
                        leading: user['pictures'] != null && user['pictures']['default'] != null
                            ? CircleAvatar(backgroundImage: NetworkImage(user['pictures']['default']))
                            : Icon(
                          Icons.account_circle,
                          size: 40,
                          color: Colors.grey,
                        ),
                        trailing: _buildTrailingInfo(match),
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

  Widget _buildChatOptionsBuilder(QueryDocumentSnapshot<Object?> match, bool isFriend){
    return FutureBuilder<bool>(
      future: DataManager.isChatMuted(currentUser?.id ?? 'null', match['chatRoomId']),
      builder: (context, snapshot) {
        return Column(children: [
          if (snapshot.connectionState == ConnectionState.done)
            if (snapshot.hasData && snapshot.data == true)
              ListTile(
                trailing: Icon(Icons.notifications_active),
                title: Text("Unmute Notifications"),
                onTap: () {
                  DataManager.toggleMuteOption(currentUser?.id ?? 'null', match['chatRoomId']);
                  Navigator.pop(context);
                },
              )
            else
              ListTile(
                trailing: Icon(Icons.notifications_off),
                title: Text("Mute Notifications"),
                onTap: () {
                  DataManager.toggleMuteOption(currentUser?.id ?? 'null', match['chatRoomId']);
                  Navigator.pop(context);
                },
              )
          else
            Container(
              constraints: BoxConstraints(maxHeight: 80.0),
              child: Center(child: SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 200))),),
            )
          ,
          if(!isFriend)
            ListTile(
              trailing: Icon(Icons.drive_file_rename_outline_rounded),
              title: Text("Change Nickname"),
              onTap: () async {
                final TextEditingController nicknameController = TextEditingController();
                String initialNickname = '';

                // Fetching the initial nickname from Firestore
                final doc = await FirebaseFirestore.instance
                    .collection('userNicknames')
                    .doc(currentUser?.id)
                    .collection('match.id')
                    .doc(match.id)
                    .get();

                if (doc.exists && doc.data()?['nickname'] != null) {
                  initialNickname = doc.data()!['nickname'];
                  nicknameController.text = initialNickname;
                }

                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text('Change Nickname'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nicknameController,
                            maxLength: 30,
                            decoration: InputDecoration(
                              hintText: 'Enter a nickname for this match',
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'This nickname will be shown for this match on message notifications and displayed in many part of the app replacing the usual characteristic combination phrase.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            // Reset Nickname
                            NicknameManager.deleteNickname(currentUser?.id ?? 'UNKNOWN', match.id).then((value) {
                              setState(() {

                              });
                            });
                            Navigator.of(context).pop();
                          },
                          child: Text('Reset Nickname'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final newNickname = nicknameController.text.trim();
                            if (newNickname.isNotEmpty && newNickname != initialNickname) {
                              Navigator.of(context).pop();
                              NicknameManager.setNickname(currentUser?.id ?? 'UNKNOWN', match.id, newNickname).then((value) {
                                setState(() {

                                });
                              });
                            }else{
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text("Nickname cannot be empty"),
                                    content: Text("Please enter a valid nickname for this match"),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text("OK"),
                                        onPressed: () => Navigator.of(context).pop(),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          },
                          child: Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ListTile(
            trailing: Icon(Icons.flag_outlined, color: Colors.red),
            title: Text("Report User", style: TextStyle(color: Colors.red)),
            onTap: () async {
              TextEditingController titleController = TextEditingController();
              TextEditingController detailsController = TextEditingController();

              await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Report User'),
                    content: SingleChildScrollView(
                      child: ListBody(
                        children: <Widget>[
                          TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              hintText: 'Why are you reporting this chat?',
                            ),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: detailsController,
                            decoration: const InputDecoration(
                              hintText: 'Tell us more about what happened',
                            ),
                            maxLines: 6,
                            maxLength: 1000,
                          ),
                        ],
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: Text('Submit Report'),
                        onPressed: () {
                          if(titleController.text.trim().isEmpty ||
                              detailsController.text.trim().isEmpty) return;

                          final reportData = {
                            'reporterId': currentUser?.id,
                            'reportedId': match.id,
                            'title': titleController.text.trim(),
                            'details': detailsController.text.trim(),
                            'timestamp': FieldValue.serverTimestamp(),
                            'status': 'PENDING_REVIEW',
                          };

                          FirebaseFirestore.instance
                              .collection('userViolationReports')
                              .doc('chats')
                              .collection('reports')
                              .add(reportData)
                              .then((_) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Your violation report has been submitted and is pending review from our moderation team. Thank you for contributing to a safer community.'),
                              ),
                            );
                          });
                        },
                      ),
                    ],
                  );
                },
              );
            },
          )

        ],);
      },
    );
  }

  Widget _buildLastMessage(DocumentSnapshot match) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(match['chatRoomId'])
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> messageSnapshot) {
        if (messageSnapshot.connectionState == ConnectionState.active && messageSnapshot.hasData && messageSnapshot.data!.docs.isNotEmpty) {
          var message = messageSnapshot.data!.docs.first;
          String content = _getMessageContentDisplay(message);
          return Text(content, overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
        } else if (messageSnapshot.connectionState == ConnectionState.active && (messageSnapshot.data == null || messageSnapshot.data!.docs.isEmpty)) {
          return Text('Start chatting now!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade800));
        } else {
          return SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, size: 25, duration: Duration(milliseconds: 200)));
        }
      },
    );
  }

  String _getMessageContentDisplay(QueryDocumentSnapshot message){
    switch(message['messageType']){
      case 'DELETED':
        return "This message has been deleted";
      case 'TEXT':
        return message['content'];
      case 'REPLY':
        return message['content'];
      case 'IMAGE':
        if(message['authorId'] == currentUser?.id){
          return "You sent a photo";
        }else{
          return "You received a photo";
        }
      case 'VIDEO':
        if(message['authorId'] == currentUser?.id){
          return "You sent a video";
        }else{
          return "You received a video";
        }
      case 'AUDIO':
        if(message['authorId'] == currentUser?.id){
          return "You sent an audio";
        }else{
          return "You received an audio";
        }
      case 'VOICE_NOTE':
        if(message['authorId'] == currentUser?.id){
          return "You sent a voice note";
        }else{
          return "You received a voice note";
        }
    }

    return "";
  }

  Widget _buildTrailingInfo(DocumentSnapshot match) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(match['chatRoomId'])
          .collection('unreadCounts')
          .doc(currentUser?.id)
          .snapshots(),
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> unreadSnapshot) {
        if (unreadSnapshot.connectionState == ConnectionState.active && unreadSnapshot.hasData) {
          int unreadCount = unreadSnapshot.data!.get('count');
          return StreamBuilder<bool>(
            stream: DataManager.isChatMutedStream(currentUser?.id ?? 'null', match['chatRoomId']),
            builder: (BuildContext context, AsyncSnapshot<bool> muteSnapshot) {
              bool isMuted = muteSnapshot.data ?? false;

              return StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(match['chatRoomId'])
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> messageSnapshot) {
                  if (messageSnapshot.connectionState == ConnectionState.active && messageSnapshot.hasData && messageSnapshot.data!.docs.isNotEmpty) {
                    var message = messageSnapshot.data!.docs.first;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_getTimeString(message['timestamp'] ?? Timestamp.now()), maxLines: 1, style: TextStyle(fontSize: 11)),
                        SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isMuted)
                              Icon(Icons.notifications_off_outlined),
                            if (unreadCount > 0)
                              CircleAvatar(
                                backgroundColor: Colors.red,
                                radius: 12,
                                child: Text("$unreadCount", style: TextStyle(color: Colors.white, fontSize: 14)),
                              ),
                          ],
                        )
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isMuted)
                              Icon(Icons.notifications_off_outlined),
                            Icon(Icons.arrow_forward_outlined)
                          ],
                        )
                      ],
                    );
                  }
                },
              );
            },
          );
        } else if (unreadSnapshot.connectionState == ConnectionState.done && !unreadSnapshot.hasData) {
          return SizedBox.shrink();  // Return an empty widget if there's no unread messages
        } else {
          return SizedBox.shrink(); // While waiting for the query to complete
        }
      },
    );
  }


  String formatName(String name) {
    List<String> parts = name.split(' ');
    if (parts.length == 1) {
      return parts[0].capitalizeFirstLowerElse;
    }

    String formattedName = parts[0].capitalizeFirstLowerElse;

    for (int i = 1; i < parts.length; i++) {
      formattedName += ' ' + parts[i][0].toUpperCase() + '.';
    }

    return formattedName;
  }

String _getTimeAgo(Timestamp timestamp) {
    final currentTime = DateTime.now();
    final requestTime = timestamp.toDate();
    final difference = currentTime.difference(requestTime);

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
      return 'on ${requestTime.day} ${monthNames[requestTime.month - 1]} ${requestTime.year}, at ${requestTime.hour}:${requestTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _getTimeString(Timestamp timestamp) {
    final requestTime = timestamp.toDate();
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));

    if (requestTime.day == now.day && requestTime.month == now.month && requestTime.year == now.year) {
      return DateFormat('HH:mm').format(requestTime);
    } else if (requestTime.day == yesterday.day && requestTime.month == yesterday.month && requestTime.year == yesterday.year) {
      return "Yesterday";
    } else if (now.year == requestTime.year) {
      return DateFormat('MM/dd').format(requestTime);
    } else {
      return DateFormat('MM/dd/yyyy').format(requestTime);
    }
  }

  final monthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

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
  String get capitalizeFirstLowerElse {
    if (this.isEmpty) {
      return this;
    }
    return this[0].toUpperCase() + this.substring(1).toLowerCase();
  }
}
