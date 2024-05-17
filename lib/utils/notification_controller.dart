import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:BeeFriends/main.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:BeeFriends/utils/notification_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:BeeFriends/main.dart';

import 'data_manager.dart';
import 'notification_manager.dart';

///  *********************************************
///     NOTIFICATION CONTROLLER
///  *********************************************

class NotificationController extends ChangeNotifier {
  /// *********************************************
  ///   SINGLETON PATTERN
  /// *********************************************

  static final NotificationController _instance =
  NotificationController._internal();

  factory NotificationController() {
    return _instance;
  }

  NotificationController._internal();

  /// *********************************************
  ///  OBSERVER PATTERN
  /// *********************************************

  String _firebaseToken = '';
  String get firebaseToken => _firebaseToken;

  String _nativeToken = '';
  String get nativeToken => _nativeToken;

  ReceivedAction? initialAction;

  /// *********************************************
  ///   INITIALIZATION METHODS
  /// *********************************************

  static Future<void> initializeLocalNotifications(
      {required bool debug}) async {
    await AwesomeNotifications().initialize(
      null, //'resource://drawable/res_app_icon',//
      [
        NotificationChannel(
            channelKey: 'alerts',
            channelName: 'Alerts',
            channelDescription: 'All general notifications',
            playSound: true,
            importance: NotificationImportance.High,
            defaultPrivacy: NotificationPrivacy.Private,
            defaultColor: Colors.deepPurple,
            ledColor: Colors.deepPurple)
      ],
      debug: debug,
      languageCode: 'en',
    );

    // Get initial notification action is optional
    _instance.initialAction = await AwesomeNotifications()
        .getInitialNotificationAction(removeFromActionEvents: false);
  }


  static Future<void> startListeningNotificationEvents() async {
    AwesomeNotifications()
        .setListeners(onActionReceivedMethod: onActionReceivedMethod);
  }

  static ReceivePort? receivePort;
  static Future<void> initializeIsolateReceivePort() async {
    receivePort = ReceivePort('Notification action port in main isolate')
      ..listen(
              (silentData) => onActionReceivedImplementationMethod(silentData)
      );

    IsolateNameServer.registerPortWithName(
        receivePort!.sendPort,
        'notification_action_port'
    );
  }

  ///  *********************************************
  ///     LOCAL NOTIFICATION EVENTS
  ///  *********************************************

  static Future<void> getInitialNotificationAction() async {
    ReceivedAction? receivedAction = await AwesomeNotifications()
        .getInitialNotificationAction(removeFromActionEvents: true);
    if (receivedAction == null) return;

    // Fluttertoast.showToast(
    //     msg: 'Notification action launched app: $receivedAction',
    //   backgroundColor: Colors.deepPurple
    // );
    print('App launched by a notification action: $receivedAction');
  }

  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    print('Notification Action Received. Button key: ' + receivedAction.buttonKeyPressed);
    if(receivedAction.buttonKeyPressed == 'REPLY'){
      Map<String, String?>? payload = receivedAction.payload;

      await NotificationManager.sendRemoteReplyMessage(payload!['senderId']!, payload['recipientId']!, receivedAction.buttonKeyInput, payload['chatRoomId']!, payload['type']!);
      print('Message sent via notification input: "${receivedAction.buttonKeyInput}"');
      return;
    }
    else {
      if (receivePort == null){
        // onActionReceivedMethod was called inside a parallel dart isolate.
        SendPort? sendPort = IsolateNameServer.lookupPortByName(
            'notification_action_port'
        );

        if (sendPort != null){
          // Redirecting the execution to main isolate process (this process is
          // only necessary when you need to redirect the user to a new page or
          // use a valid context)
          sendPort.send(receivedAction);
          return;
        }
      }

      //Enabling the below line will result in a local notification being popped when the FCM notification is clicked
      // print('On any msg (unified notifications)');
      // await NotificationManager.handleFCMBackgroundMessage(receivedAction.payload);
    }

    return onActionReceivedImplementationMethod(receivedAction);
  }

  static Future<void> onActionReceivedImplementationMethod(
      ReceivedAction receivedAction
      ) async {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/notification-page',
            (route) =>
        (route.settings.name != '/notification-page') || route.isFirst,
        arguments: receivedAction);

    //NAVIGATE BASED ON NOTIFICATION TYPE
  }

  /// Use this method to detect when a new fcm token is received
  @pragma("vm:entry-point")
  static Future<void> myFcmTokenHandle(String token) async {
    print('Received firebase token: $token');
    if (token.isNotEmpty){
      debugPrint('Firebase Token:"$token"');
    }
    else {
      debugPrint('Firebase Token deleted');
    }

    _instance._firebaseToken = token;
    _instance.notifyListeners();
  }

  @pragma("vm:entry-point")
  static Future<void> mySilentDataHandle(FcmSilentData silentData) async {
    if (silentData.createdLifeCycle != NotificationLifeCycle.Foreground) {
      print("BACKGROUND SILENT DATA RECEIVED");
      print('On background msg');
      await NotificationManager.handleFCMBackgroundMessage(silentData.data);
    } else {
      print("FOREGROUND SILENT DATA RECEIVED");
      print('On background msg');
      await NotificationManager.handleFCMForegroundMessage(silentData.data, navigatorKey.currentContext!);
    }
  }

  /// Use this method to detect when a new native token is received
  @pragma("vm:entry-point")
  static Future<void> myNativeTokenHandle(String token) async {
    // Fluttertoast.showToast(
    //     msg: 'Native token received',
    //     backgroundColor: Colors.blueAccent,
    //     textColor: Colors.white,
    //     fontSize: 16);
    debugPrint('Native Token:"$token"');

    _instance._nativeToken = token;
    _instance.notifyListeners();
  }

  ///  *********************************************
  ///     BACKGROUND TASKS TEST
  ///  *********************************************

  static Future<void> executeLongTaskInBackground() async {
    print("starting long task");
    await Future.delayed(const Duration(seconds: 4));
    final url = Uri.parse("http://google.com");
    final re = await get(url);
    print(re.body);
    print("long task done");
  }

  ///  *********************************************
  ///     REQUEST NOTIFICATION PERMISSIONS
  ///  *********************************************

  static Future<bool> displayNotificationRationale() async {
    bool userAuthorized = false;
    BuildContext context = navigatorKey.currentContext!;
    await showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: Text('Enable notifications',
                style: Theme.of(context).textTheme.titleLarge),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Icon(Icons.notifications_active_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                    'Allow BeeFriends to send notifications in order to get the full functionality of the app'),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: Text(
                    'Deny',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.red),
                  )),
              ElevatedButton(
                  onPressed: () async {
                    userAuthorized = true;
                    Navigator.of(ctx).pop();
                  },
                  child: Text(
                    'Allow',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white),
                  )),
            ],
          );
        });
    return userAuthorized &&
        await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  ///  *********************************************
  ///     LOCAL NOTIFICATION CREATION METHODS
  ///  *********************************************

  static Future<void> createNewNotification() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      isAllowed = await displayNotificationRationale();
    }

    if (!isAllowed) return;

    await AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: -1,
            channelKey: 'alerts',
            summary: 'New message from your match',
            title: 'Female, B26, Computer Science (~Goodmatch01)',
            body:
            "A small step for a man, but a giant leap to Flutter's community!",
            bigPicture: 'https://storage.googleapis.com/cms-storage-bucket/d406c736e7c4c57f5f61.png',
            largeIcon: 'https://storage.googleapis.com/cms-storage-bucket/0dbfcc7a59cd1cf16282.png',
            notificationLayout: NotificationLayout.Messaging,
            category: NotificationCategory.Message,
            payload: {'notificationId': '1234567890'}),
        actionButtons: [
          NotificationActionButton(key: 'REDIRECT', label: 'Redirect'),
          NotificationActionButton(
              key: 'REPLY',
              label: 'Reply Message',
              requireInputText: true,

              actionType: ActionType.SilentAction
          ),
          NotificationActionButton(
              key: 'DISMISS',
              label: 'Dismiss',
              actionType: ActionType.DismissAction,
              isDangerousOption: true)
        ]);
  }

  static Future<void> cancelMessageNotification(String messageId) async {
    await cancelNotification(messageId.hashCode);
  }

  static Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  static Future<void> createNewMessageNotification({required String id, required String title, required String summary, required String body, required String chatRoomId, required String type, required String senderId, required String recipientId}) async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      isAllowed = await displayNotificationRationale();
    }

    if (!isAllowed) return;

    await AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: id.hashCode,
            channelKey: 'alerts',
            groupKey: chatRoomId,
            summary: summary,
            title: title,
            body: body,
            showWhen: true,
            notificationLayout: NotificationLayout.Messaging,
            category: NotificationCategory.Message,
            payload: {'chatRoomId': chatRoomId, 'type': type, 'senderId': senderId, 'recipientId': recipientId, 'content': body}),
        actionButtons: [
          NotificationActionButton(
              key: 'REPLY',
              label: 'Reply Message',
              requireInputText: true,
              actionType: ActionType.SilentAction,
          ),
          NotificationActionButton(
              key: 'DISMISS',
              label: 'Dismiss',
              actionType: ActionType.DismissAction,
              isDangerousOption: true
          )
        ]);
    await AwesomeNotifications().incrementGlobalBadgeCounter();
  }

  static Future<void> createNewMatchRequestNotification({required String title, required String summary, required String body}) async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      isAllowed = await displayNotificationRationale();
    }

    if (!isAllowed) return;

    await AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: DateTime.now().hashCode,
            channelKey: 'alerts',
            groupKey: 'STATIC_KEY:MATCH_REQUESTS',
            summary: summary,
            title: title,
            body: body,
            notificationLayout: NotificationLayout.BigText,
            category: NotificationCategory.Event,
            payload: {'content': body})
    );
    await AwesomeNotifications().incrementGlobalBadgeCounter();
  }

  static Future<void> createNewMatchStatusNotification({required String title, required String summary, required String body}) async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      isAllowed = await displayNotificationRationale();
    }

    if (!isAllowed) return;

    await AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: DateTime.now().hashCode,
            channelKey: 'alerts',
            groupKey: 'STATIC_KEY:MATCH_STATUSES',
            summary: summary,
            title: title,
            body: body,
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Status,
            payload: {'content': body})
    );
    await AwesomeNotifications().incrementGlobalBadgeCounter();
  }

  static Future<void> createNewRelationshipChangeNotification({required String changeType, required String title, required String summary, required String body}) async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      isAllowed = await displayNotificationRationale();
    }

    if (!isAllowed) return;

    await AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: DateTime.now().hashCode,
            channelKey: 'alerts',
            groupKey: 'STATIC_KEYS:$changeType',
            summary: summary,
            title: title,
            body: body,
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Status,
            payload: {'content': body})
    );
    await AwesomeNotifications().incrementGlobalBadgeCounter();
  }

  static Future<void> createNewFriendRequestNotification({required String title, required String summary, required String body}) async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      isAllowed = await displayNotificationRationale();
    }

    if (!isAllowed) return;

    await AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: DateTime.now().hashCode,
            channelKey: 'alerts',
            groupKey: 'STATIC_KEYS:FRIEND_REQUESTS',
            summary: summary,
            title: title,
            body: body,
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Status,
            payload: {'content': body})
    );
    await AwesomeNotifications().incrementGlobalBadgeCounter();
  }

  static Future<void> createNewPremiumMembershipNotification({required String title, required String summary, required String body}) async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      isAllowed = await displayNotificationRationale();
    }

    if (!isAllowed) return;

    await AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: DateTime.now().hashCode,
            channelKey: 'alerts',
            groupKey: 'STATIC_KEYS:PREMIUM_MEMBERSHIP',
            summary: summary,
            title: title,
            body: body,
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Status,
            payload: {'content': body})
    );
    await AwesomeNotifications().incrementGlobalBadgeCounter();
  }

  static Future<void> createNewPurchaseBeetsNotification({required String title, required String summary, required String body}) async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      isAllowed = await displayNotificationRationale();
    }

    if (!isAllowed) return;

    await AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: DateTime.now().hashCode,
            channelKey: 'alerts',
            groupKey: 'STATIC_KEYS:PURCHASE_BEETS',
            summary: summary,
            title: title,
            body: body,
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Status,
            payload: {'content': body})
    );
    await AwesomeNotifications().incrementGlobalBadgeCounter();
  }

  static Future<void> resetBadge() async {
    await AwesomeNotifications().resetGlobalBadge();
  }
}