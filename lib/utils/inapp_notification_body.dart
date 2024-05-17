import 'dart:ui';

import 'package:BeeFriends/chats_page.dart';
import 'package:BeeFriends/main_page.dart';
import 'package:BeeFriends/match_requests_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:in_app_notification/in_app_notification.dart';
import 'package:microsoft_graph_api/models/calendar/calendar_models.dart';

import '../chat_room.dart';
import 'display_utils.dart';

class NotificationBody extends StatelessWidget {
  final int count;
  final double minHeight;

  NotificationBody({
    Key? key,
    this.count = 0,
    this.minHeight = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final minHeight = this.minHeight < MediaQuery.of(context).size.height ?
      this.minHeight :
      MediaQuery.of(context).size.height;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 12,
                blurRadius: 16,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    width: 1.4,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'One of your matching request has been accepted. Click here to view your new match!',
                      style: TextStyle(fontSize: 16, color: Colors.white)
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MessageNotificationBody extends StatelessWidget {
  final String senderName;
  final String type; // should be 'friend' or 'match'
  final String chatRoomId;
  final String senderId;
  final String message;
  final double minHeight;

  MessageNotificationBody({
    Key? key,
    required this.senderName,
    required this.type,
    required this.chatRoomId,
    required this.senderId,
    required this.message,
    this.minHeight = 100.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color notificationColor = type == 'friend' ? Colors.blue : Colors.red;
    IconData typeIcon = type == 'friend' ? Icons.person : Icons.favorite;
    String displayType = type[0].toUpperCase() + type.substring(1);

    return GestureDetector(
      onTap: () {
        InAppNotification.dismiss(context: context);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatRoom(
              chatRoomId: chatRoomId,
              recipientId: senderId,
              chatRoomType: type,
            ),
          ),
        );
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: notificationColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    typeIcon,
                    size: 40,
                    color: Colors.white,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$senderName ($displayType)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap to view',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BeetsClaimNotificationBody extends StatelessWidget {
  final String message;
  final bool success;
  final double minHeight;

  BeetsClaimNotificationBody({
    Key? key,
    required this.message,
    required this.success,
    this.minHeight = 60.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color notificationColor = success ? Colors.lightGreen : Colors.red;

    return GestureDetector(
      onTap: () {
        InAppNotification.dismiss(context: context);
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: notificationColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SvgPicture.asset('assets/beets_icon.svg', height: 25, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Beets Claim',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'You can do this again in 24 hours.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BeetsPurchaseNotificationBody extends StatelessWidget {
  final int amount;
  final double minHeight;
  final bool log;
  final Timestamp? timestamp;

  BeetsPurchaseNotificationBody({
    Key? key,
    required this.amount,
    this.minHeight = 60.0,
    this.log = false,
    this.timestamp
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color notificationColor = Color.fromARGB(255, 46, 93, 248);

    return GestureDetector(
      onTap: () {
        if(log) return;
        InAppNotification.dismiss(context: context);
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: notificationColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SvgPicture.asset('assets/beets_icon.svg', height: 40, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Beets Top Up',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Successfully purchased $amount Beets. $amount Beets have been added to your account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        SizedBox(height: 8),
                        Text(
                          log ? formatDate(timestamp ?? Timestamp.now()) : 'Thank you for your purchase. Contact our user support if any problem persists',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumSubscribeNotificationBody extends StatelessWidget {
  final double minHeight;
  final bool log;
  final Timestamp? timestamp;

  PremiumSubscribeNotificationBody({
    Key? key,
    this.minHeight = 60.0,
    this.log = false,
    this.timestamp
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color notificationColor = const Color.fromARGB(255, 52, 38, 94);

    return GestureDetector(
      onTap: () {
        if (log) return;
        InAppNotification.dismiss(context: context);
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: notificationColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(Icons.workspace_premium_rounded, size: 40, color: Colors.amber,),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium Subscription',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'You have successfully subscribed as a Premium member. Welcome aboard the golden hive!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        SizedBox(height: 8),
                        Text(
                          log ? formatDate(timestamp ?? Timestamp.now()) : 'Please wait a while if your membership is not updated yet. If necessary, contact user support for further assistance.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MatchRequestNotificationBody extends StatelessWidget {
  final double minHeight;
  final String paidMessage;
  final bool log;
  final Timestamp? timestamp;

  MatchRequestNotificationBody({
    Key? key,
    required this.paidMessage,
    this.minHeight = 60.0,
    this.log = false,
    this.timestamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color notificationColor = Colors.cyan;

    return GestureDetector(
      onTap: () {
        if(log) return;
        InAppNotification.dismiss(context: context);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MatchRequestsPage(),
          ),
        );
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: notificationColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    Icons.forward_to_inbox_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Matching Request',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          paidMessage.isEmpty ? 'You have just received a new matching request, check it out!' : 'You have just received a new matching request, the sender says: $paidMessage',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        SizedBox(height: 8),
                        Text(
                          log ? formatDate(timestamp ?? Timestamp.now()) : 'Tap to view your match requests',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatDate(Timestamp timestamp) {
  final DateTime date = timestamp.toDate();
  final String formattedDate = "${date.day} ${DisplayUtils.monthNames[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

  return formattedDate;
}

class MatchStatusNotificationBody extends StatelessWidget {
  final double minHeight;
  final String status;
  final String chatRoomId;
  final String recipientId;
  final bool log;
  final Timestamp? timestamp;

  MatchStatusNotificationBody({
    Key? key,
    required this.status,
    required this.chatRoomId,
    required this.recipientId,
    this.minHeight = 60.0,
    this.log = false,
    this.timestamp
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isAccepted = status == 'accepted';

    Color notificationColor = isAccepted ? Colors.lightGreen : Colors.redAccent;

    return GestureDetector(
      onTap: () {
        if(log) return;
        InAppNotification.dismiss(context: context);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => isAccepted ? ChatRoom(
                chatRoomId: chatRoomId,
                recipientId: recipientId,
                chatRoomType: 'match') :
            MatchRequestsPage(),
          ),
        );
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: notificationColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    isAccepted ? Icons.check_circle_outline_rounded : Icons.block_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Matching Request ${isAccepted ? 'Accepted' : 'Declined'}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          isAccepted ? 'Yay! one of your matching request has been accepted!' : 'Oh no! One of your matching request has been declined',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        SizedBox(height: 8),
                        Text(
                          log ? formatDate(timestamp ?? Timestamp.now()) : isAccepted ? 'Tap to chat with your new match' : 'Tap to review your match requests',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FriendRequestNotificationBody extends StatelessWidget {
  final double minHeight;
  final String chatRoomId;
  final String senderId;
  final bool log;
  final Timestamp? timestamp;

  FriendRequestNotificationBody({
    Key? key,
    required this.senderId,
    required this.chatRoomId,
    this.minHeight = 60.0,
    this.log = false,
    this.timestamp
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color notificationColor = Colors.deepPurpleAccent;

    return GestureDetector(
      onTap: () {
        if(log) return;
        InAppNotification.dismiss(context: context);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatRoom(
                chatRoomId: chatRoomId,
                recipientId: senderId,
                chatRoomType: 'match'),
          ),
        );
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: notificationColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Incoming Friend Request',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'One of your matches has requested to be a friend',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        SizedBox(height: 8),
                        Text(
                          log ? formatDate(timestamp ?? Timestamp.now()) : 'Tap to open your chat with them',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum RelationshipChange { MATCH_TO_FRIEND, MATCH_TO_NONE, FRIEND_TO_NONE }
class RelationshipChangeNotificationBody extends StatelessWidget {
  final double minHeight;
  final String senderId;
  final String senderName;
  final String chatRoomId;
  final String oldRelationship;
  final String newRelationship;
  final bool log;
  final Timestamp? timestamp;

  RelationshipChangeNotificationBody({
    Key? key,
    required this.senderId,
    required this.senderName,
    required this.chatRoomId,
    required this.oldRelationship,
    required this.newRelationship,
    this.minHeight = 60.0,
    this.log = false,
    this.timestamp
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    RelationshipChange change = oldRelationship == 'match' && newRelationship == 'none' ? RelationshipChange.MATCH_TO_NONE : oldRelationship == 'match' && newRelationship == 'friend' ? RelationshipChange.MATCH_TO_FRIEND : RelationshipChange.FRIEND_TO_NONE;
    Color notificationColor = Colors.orange;

    String titleText = '';
    if(change == RelationshipChange.MATCH_TO_NONE){
      titleText = 'Removed From Matches';
    }else if(change == RelationshipChange.FRIEND_TO_NONE){
      titleText = 'Removed From Friends';
    }else{
      titleText = 'New Friend';
    }

    String mainText = '';
    if(change == RelationshipChange.MATCH_TO_NONE){
      mainText = 'Oops! You have been removed as match by one of your previous matches';
    }else if(change == RelationshipChange.FRIEND_TO_NONE){
      mainText = 'Oh no! ${ChatRoomState.formatName(senderName)} has removed you from their friends list';
    }else{
      mainText = 'You just got a new friend! Get to know ${ChatRoomState.formatName(senderName)}';
    }

    return GestureDetector(
      onTap: () {
        if(log) return;
        InAppNotification.dismiss(context: context);
        if(change == RelationshipChange.MATCH_TO_FRIEND){
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) =>
                    ChatRoom(
                        chatRoomId: chatRoomId,
                        recipientId: senderId,
                        chatRoomType: 'friend'
                    )
            ),
          );
        }
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: notificationColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    Icons.published_with_changes_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          mainText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        SizedBox(height: 8),
                        Text(
                          log ? formatDate(timestamp ?? Timestamp.now()) : change == RelationshipChange.MATCH_TO_FRIEND ? 'Tap to chat with your new friend' : 'You can no longer see their profile',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
