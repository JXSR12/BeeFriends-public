import 'package:BeeFriends/firebase_options.dart';
import 'package:BeeFriends/utils/nickname_manager.dart';
import 'package:BeeFriends/utils/static_global_keys.dart';
import 'package:BeeFriends/utils/user_provider.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:in_app_notification/in_app_notification.dart';

import '../chat_room.dart';
import '../login_page.dart';
import '../main.dart';
import '../main_page.dart';
import '../profile_page.dart';
import 'inapp_notification_body.dart';
import 'notification_controller.dart';

class NotificationManager {
  static final Config config = Config(
      tenant: 'common',
      clientId: 'b89cc19d-4587-4170-9b80-b39204b74380',
      scope: 'openid profile offline_access User.Read',
      redirectUri: 'https://beefriends-a1c17.firebaseapp.com/__/auth/handler',
      navigatorKey: navigatorKey,
      loader: SizedBox());
  static final AadOAuth oauth = AadOAuth(config);

  static Future<bool> sendRemoteReplyMessage(String recipientId, String senderId, String content, String chatRoomId, String relType) async {
    if(Firebase.apps.isEmpty){
      var app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    DocumentReference messageRef = await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).collection('messages').add({
      'content': content,
      'authorId': senderId,
      'timestamp': FieldValue.serverTimestamp(),
      'reads': [senderId],
      'messageType': 'TEXT',
      'replyingTo': null,
    });

    var documentRef = FirebaseFirestore.instance.collection('chats').doc(chatRoomId).collection('unreadCounts').doc(recipientId);
    await documentRef.set({
      'count': FieldValue.increment(1)
    }, SetOptions(merge: true));

    var senderData = await FirebaseFirestore.instance.collection('users').doc(senderId).get();

    String gender = senderData.data()?['gender'] == 'male' ? 'Male' : 'Female';
    String? displayName = relType == 'friend' ? senderData.data()!['displayName'] : '$gender, B${senderData.data()?['studentNumber'].substring(0, 2)}, ${senderData.data()?['major']}';

    // Use the messageRef.id as the document ID for the notification
    NotificationManager.addMessageNotification(messageRef.id, displayName ?? 'Unknown', recipientId, relType, content, chatRoomId, senderId);

    return true;
  }


  static Future<void> addMessageNotification(String id, String senderName, String recipientId, String type, String message, String chatRoomId, String senderId) async {
    DocumentReference muteOptionRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatRoomId)
        .collection('muteOptions')
        .doc(recipientId);

    DocumentSnapshot muteOptionSnapshot = await muteOptionRef.get();

    if (muteOptionSnapshot.exists && (muteOptionSnapshot.data() as Map<String, dynamic>)['isMuted'] == true) {
      return;
    }

    CollectionReference notifications = FirebaseFirestore.instance.collection('notifications');
    await notifications.doc(recipientId).collection('messageNotifications').add({
      'id': id,
      'notifType': 'NEW_MESSAGE',
      'timestamp': FieldValue.serverTimestamp(),
      'senderName': senderName,
      'type': type,
      'message': message,
      'chatRoomId': chatRoomId,
      'recipientId': recipientId,
      'senderId': senderId
    });
  }


  static Future<void> addMatchRequestNotification(String senderId, String recipientId, String paidMessage) async {
    CollectionReference notifications = FirebaseFirestore.instance.collection('notifications');
    await notifications.doc(recipientId).collection('eventNotifications').add({
      'notifType': 'NEW_MATCH_REQUEST',
      'timestamp': FieldValue.serverTimestamp(),
      'recipientId': recipientId,
      'senderId': senderId,
      'paidMessage': paidMessage.isEmpty ? '' : paidMessage,
    });
  }

  static Future<void> addMatchStatusNotification(String senderId, String recipientId, String chatRoomId, String status) async {
    //Status can be either 'accepted' or 'declined'
    CollectionReference notifications = FirebaseFirestore.instance.collection('notifications');
    await notifications.doc(senderId).collection('eventNotifications').add({
      'notifType': 'RESPONSE_MATCH_STATUS',
      'timestamp': FieldValue.serverTimestamp(),
      'recipientId': recipientId,
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'status': status
    });
  }

  static Future<void> addFriendRequestNotification(String senderId, String recipientId, String chatRoomId) async {
    CollectionReference notifications = FirebaseFirestore.instance.collection('notifications');
    await notifications.doc(recipientId).collection('eventNotifications').add({
      'notifType': 'NEW_FRIEND_REQUEST',
      'timestamp': FieldValue.serverTimestamp(),
      'recipientId': recipientId,
      'chatRoomId': chatRoomId,
      'senderId': senderId,
    });
  }

  static Future<void> addRelationshipChangeNotification(String senderId, String recipientId, String oldRelationship, String newRelationship, String chatRoomId, String senderName) async {
    //oldRelationship and newRelationship can be either 'none', 'match', or 'friend'
    CollectionReference notifications = FirebaseFirestore.instance.collection('notifications');
    await notifications.doc(recipientId).collection('eventNotifications').add({
      'notifType': 'CHANGE_RELATIONSHIP',
      'timestamp': FieldValue.serverTimestamp(),
      'recipientId': recipientId,
      'senderId': senderId,
      'senderName': senderName,
      'chatRoomId': chatRoomId,
      'oldRelationship': oldRelationship,
      'newRelationship': newRelationship
    });
  }

  static Future<void> addPremiumPurchaseNotification(String userId) async {
    CollectionReference notifications = FirebaseFirestore.instance.collection('notifications');
    await notifications.doc(userId).collection('eventNotifications').add({
      'notifType': 'PURCHASE_PREMIUM',
      'timestamp': FieldValue.serverTimestamp(),
      'userId': userId,
    });
  }

  static Future<void> addBeetsPurchaseNotification(String userId, int beetsAmount) async {
    CollectionReference notifications = FirebaseFirestore.instance.collection('notifications');
    await notifications.doc(userId).collection('eventNotifications').add({
      'notifType': 'PURCHASE_BEETS',
      'timestamp': FieldValue.serverTimestamp(),
      'userId': userId,
      'beetsAmount': beetsAmount.toString()
    });
  }

  static Future<void> unsendMessageNotification(String userId, String messageId) async {
    CollectionReference notifications = FirebaseFirestore.instance.collection('notifications');
    await notifications.doc(userId).collection('eventNotifications').add({
      'notifType': 'UNSEND_MESSAGE',
      'id': messageId,
    });
  }

  static Future<void> handleFCMForegroundMessage(Map<String, dynamic>? message, BuildContext context) async {
    print('Foreground message received');
    print('Local notifications are deprecated in this version of BeeFriends. Only push notifications are served now.');
    // if(message?['forceNoInApp'] != null && message?['forceNoInApp'] == 'ENABLED') return;
    // if (message?['notifType'] == 'NEW_MESSAGE') {
    //   if (!_isUserInChatRoom(message?['chatRoomId'])) {
    //     _showMessageInAppNotification(
    //       senderName: message?['senderName'],
    //       type: message?['type'],
    //       notificationMessage: message?['message'],
    //       senderId: message?['senderId'],
    //       context: context,
    //       chatRoomId: message?['chatRoomId'],
    //     );
    //   }
    // }else if(message?['notifType'] == 'NEW_MATCH_REQUEST'){
    //   _showMatchRequestInAppNotification(paidMessage: message?['paidMessage'], context: context);
    // }else if(message?['notifType'] == 'RESPONSE_MATCH_STATUS'){
    //   _showMatchStatusInAppNotification(status: message?['status'], chatRoomId: message?['chatRoomId'], recipientId: message?['recipientId'], context: context);
    // }else if(message?['notifType'] == 'NEW_FRIEND_REQUEST'){
    //   _showFriendRequestInAppNotification(senderId: message?['senderId'], chatRoomId: message?['chatRoomId'], context: context);
    // }else if(message?['notifType'] == 'CHANGE_RELATIONSHIP'){
    //   _showRelationshipChangeInAppNotification(senderId: message?['senderId'], chatRoomId: message?['chatRoomId'], senderName: message?['senderName'], oldRelationship: message?['oldRelationship'], newRelationship: message?['newRelationship'], context: context);
    // }else if(message?['notifType'] == 'PURCHASE_PREMIUM'){
    //   _showPremiumSubscriptionInAppNotification(context: context);
    // }else if(message?['notifType'] == 'PURCHASE_BEETS'){
    //   showPurchaseBeetsInAppNotification(message?['beetsAmount'] is String ? int.parse(message?['beetsAmount']) : (message?['beetsAmount'] as num).toInt(), context: context);
    // }
    // else if(message?['notifType'] == 'UNSEND_MESSAGE'){
    //   NotificationController.cancelMessageNotification(message?['id']);
    // }else if (message?['signout'] == 'true') {
    //   await oauth.logout();
    //   await ProfileState.removeUserInfoFromSharedPreferences();
    //   checkLoginStatus(true);
    // }
  }

  @pragma('vm:entry-point')
  static Future<void> handleFCMBackgroundMessage(Map<String, dynamic>? message) async {
    print('Background message received');
    print('Local notifications are deprecated in this version of BeeFriends. Only push notifications are served now.');
    // if(message?['forceNoPush'] != null && message?['forceNoPush'] == 'ENABLED') return;
    // if(message?['notifType'] == 'NEW_MESSAGE'){
    //   _showMessagePushNotification(
    //       id: message?['id'],
    //       senderName: message?['senderName'],
    //       type: message?['type'],
    //       notificationMessage: message?['message'],
    //       chatRoomId: message?['chatRoomId'],
    //       senderId: message?['senderId'],
    //       recipientId: message?['recipientId']
    //   );
    // }else if(message?['notifType'] == 'NEW_MATCH_REQUEST'){
    //   _showMatchRequestPushNotification(paidMessage: message?['paidMessage']);
    // }else if(message?['notifType'] == 'RESPONSE_MATCH_STATUS'){
    //   _showMatchStatusPushNotification(status: message?['status'], chatRoomId: message?['chatRoomId'], recipientId: message?['recipientId']);
    // }else if(message?['notifType'] == 'NEW_FRIEND_REQUEST'){
    //   _showFriendRequestPushNotification(chatRoomId: message?['chatRoomId'], senderId: message?['senderId']);
    // }else if(message?['notifType'] == 'CHANGE_RELATIONSHIP'){
    //   _showRelationshipChangePushNotification(senderId: message?['senderId'], chatRoomId: message?['chatRoomId'], senderName: message?['senderName'], oldRelationship: message?['oldRelationship'], newRelationship: message?['newRelationship']);
    // }else if(message?['notifType'] == 'PURCHASE_PREMIUM'){
    //   _showPremiumSubscriptionPushNotification();
    // }else if(message?['notifType'] == 'PURCHASE_BEETS'){
    //   _showPurchaseBeetsPushNotification(amount: (message?['beetsAmount'] as num).toInt());
    // }
    // else if(message?['notifType'] == 'UNSEND_MESSAGE'){
    //   NotificationController.cancelMessageNotification(message?['id']);
    // }else if (message?['signout'] == 'true') {
    //   await oauth.logout();
    //   await ProfileState.removeUserInfoFromSharedPreferences();
    //   checkLoginStatus(true);
    // }
  }

  static bool _isUserInChatRoom(String chatRoomId) {
    var chatRoomState = chatRoomKey.currentState;
    if (chatRoomState != null && chatRoomState.mounted && chatRoomState.widget.chatRoomId == chatRoomId) {
      return true;
    }
    return false;
  }


  static void _showMessageInAppNotification({required String senderName, required String type, required String notificationMessage, required String chatRoomId, required String senderId, required BuildContext context}) {
    InAppNotification.show(
      child: MessageNotificationBody(senderName: type == 'match' ? NicknameManager.getNickname(senderId, senderName) : senderName, type: type, chatRoomId: chatRoomId, senderId: senderId, message: notificationMessage),
      context: context,
      onTap: () {},
      duration: Duration(milliseconds: 2000),
    );
  }

  static void _showMatchRequestInAppNotification({required String paidMessage, required BuildContext context}) {
    InAppNotification.show(
      child: MatchRequestNotificationBody(paidMessage: paidMessage),
      context: context,
      onTap: () {},
      duration: Duration(milliseconds: 3000),
    );
  }

  static void _showMatchStatusInAppNotification({required String status, required String chatRoomId, required String recipientId, required BuildContext context}) {
    InAppNotification.show(
      child: MatchStatusNotificationBody(status: status, chatRoomId: chatRoomId, recipientId: recipientId),
      context: context,
      onTap: () {},
      duration: Duration(milliseconds: 3000),
    );
  }

  static void _showRelationshipChangeInAppNotification({required String senderId, required String senderName, required String chatRoomId, required String oldRelationship, required String newRelationship, required BuildContext context}) {
    InAppNotification.show(
      child: RelationshipChangeNotificationBody(senderId: senderId, senderName: senderName, chatRoomId: chatRoomId, oldRelationship: oldRelationship, newRelationship: newRelationship),
      context: context,
      onTap: () {},
      duration: Duration(milliseconds: 3000),
    );
  }

  static void _showFriendRequestInAppNotification({required String senderId, required String chatRoomId, required BuildContext context}) {
    InAppNotification.show(
      child: FriendRequestNotificationBody(senderId: senderId, chatRoomId: chatRoomId),
      context: context,
      onTap: () {},
      duration: Duration(milliseconds: 3000),
    );
  }

  static void showPurchaseBeetsInAppNotification(int amount, {required BuildContext context}){
    InAppNotification.show(
      child: BeetsPurchaseNotificationBody(amount: amount),
      context: context,
      onTap: () {},
      duration: Duration(milliseconds: 2000),
    );
  }

  static void _showPremiumSubscriptionInAppNotification({required BuildContext context}){
    InAppNotification.show(
      child: PremiumSubscribeNotificationBody(),
      context: context,
      onTap: () {},
      duration: Duration(milliseconds: 2000),
    );
  }

  static void _showPurchaseBeetsPushNotification({required int amount}) {
    String summary = '$amount Beets was added to your account';

    NotificationController.createNewPurchaseBeetsNotification(title: 'Beets purchase successful', summary: summary, body: 'Your purchase of $amount Beets was successful. It has been added to your account. Should there be any problem regarding the purchase, contact our user support.');
  }

  static void _showPremiumSubscriptionPushNotification() {
    String summary = 'Premium membership activated';

    NotificationController.createNewPurchaseBeetsNotification(title: 'Premium membership active', summary: summary, body: 'You have successfully activated monthly BeeFriends Premium membership. You will start to receive benefits soon. If any problem persists, please contact our user support.');
  }

  static void _showMessagePushNotification({required String id, required String senderName, required String type, required String notificationMessage, required String chatRoomId, required String senderId, required String recipientId}) {
    String summary = 'A new message from your ${type == 'friend' ? 'friend' : 'match'}';
    NotificationController.createNewMessageNotification(id: id, title: type == 'match' ? NicknameManager.getNickname(senderId, senderName) : senderName, summary: summary, body: notificationMessage, chatRoomId: chatRoomId, type: type, senderId: senderId, recipientId: recipientId);
  }

  static void _showMatchRequestPushNotification({required String paidMessage}) {
    String summary = paidMessage.isEmpty ? 'You have received a new matching request' : 'You have received a new matching request, the sender says';

    NotificationController.createNewMatchRequestNotification(title: 'New Matching Request', summary: summary, body: paidMessage.isEmpty ? 'Come and check it out!' : 'The sender says: $paidMessage');
  }

  static void _showMatchStatusPushNotification({required String status, required String chatRoomId, required String recipientId}) {
    bool isAccepted = status == 'accepted';
    String summary = 'Your matching request has been ${isAccepted ? 'accepted' : 'declined'}';

    NotificationController.createNewMatchStatusNotification(title: 'Matching Request ${isAccepted ? 'Accepted' : 'Declined'}', summary: summary, body: isAccepted ? 'Yay! One of your matching requests has been accepted. Come and have a chat with your new match!' : 'Oh no! One of your matching requests has been declined. Don\'t worry, you can try again with another one!');
  }

  static void _showFriendRequestPushNotification({required String chatRoomId, required String senderId}) {
    String summary = 'You have received a new friend request';

    NotificationController.createNewMatchStatusNotification(title: 'Incoming Friend Request', summary: summary, body: 'One of your matches has requested to become friends');
  }

  static void _showRelationshipChangePushNotification({required String senderName, required String oldRelationship, required String newRelationship, required String chatRoomId, required String senderId}) {
    String changeType = 'NONE_TO_NONE';

    if(oldRelationship == 'match' && newRelationship == 'none') changeType = 'MATCH_TO_NONE';
    else if(oldRelationship == 'friend' && newRelationship == 'none') changeType = 'FRIEND_TO_NONE';
    else if(oldRelationship == 'match' && newRelationship == 'friend') changeType = 'MATCH_TO_FRIEND';

    String titleText = '';
    if(changeType == 'MATCH_TO_NONE'){
      titleText = 'Removed From Matches';
    }else if(changeType == 'FRIEND_TO_NONE'){
      titleText = 'Removed From Friends';
    }else{
      titleText = 'New Friend';
    }

    String mainText = '';
    if(changeType == 'MATCH_TO_NONE'){
      mainText = 'Oops! You have been removed as match by one of your previous matches. (${NicknameManager.getNickname(senderId, 'No nickname set')})';
    }else if(changeType == 'FRIEND_TO_NONE'){
      mainText = 'Oh no! ${ChatRoomState.formatName(senderName)} has removed you from their friends list';
    }else{
      mainText = 'You just got a new friend! Get to know ${ChatRoomState.formatName(senderName)}';
    }

    NotificationController.createNewRelationshipChangeNotification(changeType: changeType, title: titleText, summary: 'Relationship change', body: mainText);
  }

}
