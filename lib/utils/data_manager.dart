import 'package:BeeFriends/utils/notification_controller.dart';
import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'helper_classes.dart';

class DataManager {
  static Future<bool> isMatch(String? userId1, String? userId2) async {
    if (userId1 == null || userId2 == null) return false;

    try {
      DocumentSnapshot user1MatchDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId1)
          .collection('matches')
          .doc(userId2)
          .get();

      DocumentSnapshot user2MatchDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId2)
          .collection('matches')
          .doc(userId1)
          .get();

      bool isMatch = user1MatchDoc.exists && user2MatchDoc.exists;

      if (isMatch) {
        await repairRelationshipDocuments(userId1, userId2, 'matches');
      }

      return isMatch;
    } catch (e) {
      print(e.toString());
      return false;
    }
  }

  static Future<bool> isFriend(String? userId1, String? userId2) async {
    if (userId1 == null || userId2 == null) return false;

    try {
      DocumentSnapshot user1FriendDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId1)
          .collection('friends')
          .doc(userId2)
          .get();

      DocumentSnapshot user2FriendDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId2)
          .collection('friends')
          .doc(userId1)
          .get();

      bool isFriend = user1FriendDoc.exists && user2FriendDoc.exists;

      if (isFriend) {
        await repairRelationshipDocuments(userId1, userId2, 'friends');
      }

      return isFriend;
    } catch (e) {
      print(e.toString());
      return false;
    }
  }

  static Future<void> repairRelationshipDocuments(String? userId1, String? userId2, String collectionName) async{
    if(userId1 == null || userId1.isEmpty || userId2 == null || userId2.isEmpty) return;
    try {
      DocumentReference docRef1 = FirebaseFirestore.instance.collection('users').doc(userId1).collection(collectionName).doc(userId2);
      DocumentReference docRef2 = FirebaseFirestore.instance.collection('users').doc(userId2).collection(collectionName).doc(userId1);

      DocumentSnapshot docSnap1 = await docRef1.get();
      DocumentSnapshot docSnap2 = await docRef2.get();

      // If both documents exist or none exist, nothing to repair
      if ((docSnap1.exists && docSnap2.exists) || (!docSnap1.exists && !docSnap2.exists)) {
        return;
      }

      // If doc1 exists but doc2 does not, create doc2 with doc1's data
      if (docSnap1.exists && !docSnap2.exists) {
        await docRef2.set(docSnap1.data()!);
      }

      // If doc2 exists but doc1 does not, create doc1 with doc2's data
      if (docSnap2.exists && !docSnap1.exists) {
        await docRef1.set(docSnap2.data()!);
      }

    } catch (e) {
      print("An error occurred: $e");
    }
  }

  static Future<void> removeChat(String chatId) async {
    try {
      final QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('messageType', isEqualTo: 'IMAGE')
          .get();

      for (QueryDocumentSnapshot messageDoc in messagesSnapshot.docs) {
        String fileUrl = messageDoc['content'];
        Reference ref = FirebaseStorage.instance.refFromURL(fileUrl);
        await ref.delete();
      }

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .delete();

    } catch (e) {
      print("An error occurred: $e");
    }
  }

  static Future<void> removeMatch(String? userId1, String? userId2) async {
    if(userId1!.isEmpty || userId2!.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId1).collection('matches').doc(userId2).delete();
      await FirebaseFirestore.instance.collection('users').doc(userId2).collection('matches').doc(userId1).delete();
    } catch (e) {
      print("An error occurred: $e");
    }
  }

  static Future<void> removeFriend(String? userId1, String? userId2) async {
    if(userId1!.isEmpty || userId2!.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId1).collection('friends').doc(userId2).delete();
      await FirebaseFirestore.instance.collection('users').doc(userId2).collection('friends').doc(userId1).delete();
    } catch (e) {
      print("An error occurred: $e");
    }
  }

  static Future<void> changeMatchToFriend(String? chatRoomId, String? userId1, String? userId2) async {
    if(chatRoomId!.isEmpty || userId1!.isEmpty || userId2!.isEmpty) return;
    try{
      //Add to user's friend list
      await FirebaseFirestore.instance.collection('users').doc(userId1).collection('friends').doc(userId2).set({
        'chatRoomId': chatRoomId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      //Add to recipient's friend list
      await FirebaseFirestore.instance.collection('users').doc(userId2).collection('friends').doc(userId1).set({
        'chatRoomId': chatRoomId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Remove from the user's matches
      await FirebaseFirestore.instance.collection('users').doc(userId1).collection('matches').doc(userId2).delete();

      // Remove from the recipient's matches
      await FirebaseFirestore.instance.collection('users').doc(userId2).collection('matches').doc(userId1).delete();

    }catch (e) {
      print("An error occured: $e");
    }
  }

  static Future<void> saveFcmToken(String? userId) async {
    if (userId != null) {
      print("User ID is not null");
      String? newFcmToken = NotificationController().firebaseToken;
      if (newFcmToken != null) {
        print("new FCM token is not null");
        final fcmTokenDoc = FirebaseFirestore.instance.collection('fcmTokens').doc(userId);
        final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);

        DocumentSnapshot fcmTokenDocSnapshot = await fcmTokenDoc.get();

        if (fcmTokenDocSnapshot.exists) {
          Map<String, dynamic> fcmTokenData = fcmTokenDocSnapshot.data() as Map<String, dynamic>;
          String? currentFcmToken = fcmTokenData['token'];

          if (newFcmToken != currentFcmToken) {
            print("new FCM token is not the same");

            // if (currentFcmToken != null) {
            //   try {
            //     await signOutFromDevice(currentFcmToken);
            //   } catch (e) {
            //     print("Error signing out from device: $e");
            //     // Continue execution even if sign out fails
            //   }
            // }

            await fcmTokenDoc.set({'token': newFcmToken}, SetOptions(merge: true));
            await userDoc.set({'triggers': FieldValue.increment(1)}, SetOptions(merge: true));
          }
        } else {
          // Document does not exist, so create a new one with the FCM token
          await fcmTokenDoc.set({'token': newFcmToken});
        }
      }
    }
  }



  static Future<void> signOutFromDevice(String fcmToken) async {
    HttpsCallable callable = FirebaseFunctions.instance.httpsCallableFromUrl('https://asia-southeast2-beefriends-a1c17.cloudfunctions.net/signoutfcmtoken');
    final results = await callable.call(<String, dynamic>{
      'fcmToken': fcmToken,
    });

    print(results.data);
  }


  static Future<int> claimDailyBeets(String userId) async {
    int two = 2;
    int five = 5;
    int three = 3;
    int premiumBeetsCount = three * two * five * two; //Mini obfuscation == 60
    int regularBeetsCount = two * two * five; //Mini obfuscation == 20

    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final functions = FirebaseFunctions.instance;

    // Call the Cloud Function to get the server timestamp
    final HttpsCallable callable = functions.httpsCallableFromUrl('https://asia-southeast2-beefriends-a1c17.cloudfunctions.net/servertimestamp');
    final response = await callable.call();
    Timestamp serverTimestamp = Timestamp.fromMillisecondsSinceEpoch(
        response.data['timestamp']['_seconds'] * 1000
    );

    return FirebaseFirestore.instance.runTransaction<int>((transaction) async {
      DocumentSnapshot userSnapshot = await transaction.get(userRef);
      Map<String, dynamic> userData = userSnapshot.data() as Map<String, dynamic>;

      // Check the account type
      var accountType = userData['accountType'] ?? 'REGULAR';
      if (accountType != 'PREMIUM' && accountType != 'REGULAR') {
        // Set to REGULAR if accountType is not found or invalid
        accountType = 'REGULAR';
        transaction.update(userRef, {'accountType': accountType});
      }

      // Get the timestamp of the last beets claim
      Timestamp? lastBeetsClaim = userData['lastBeetsClaim'] as Timestamp?;

      int beetsIncrement = accountType == 'PREMIUM' ? premiumBeetsCount : regularBeetsCount;

      // Use the serverTimestamp from the Cloud Function
      if (lastBeetsClaim == null || serverTimestamp.seconds - lastBeetsClaim.seconds >= 86400) {
        // Increment the beets
        int currentBeets = (userData['beets'] as num).toInt() ?? 0;
        transaction.update(userRef, {
          'beets': currentBeets + beetsIncrement,
          'lastBeetsClaim': serverTimestamp
        });
        return beetsIncrement;
      } else {
        return -1;
      }
    }).catchError((error) {
      print('Error claiming daily beets: $error');
      return -1;
    });
  }

  static Future<void> toggleMuteOption(String userId, String chatRoomId) async {
    try {
      DocumentReference muteOptionRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .collection('muteOptions')
          .doc(userId);

      DocumentSnapshot muteOptionSnapshot = await muteOptionRef.get();

      if (muteOptionSnapshot.exists) {
        bool currentMuteValue = (muteOptionSnapshot.data() as Map<String, dynamic>)['isMuted'] ?? false;
        await muteOptionRef.update({'isMuted': !currentMuteValue});
      } else {
        await muteOptionRef.set({'isMuted': true});
      }
    } catch (e) {
      print("An error occurred while toggling mute option: $e");
    }
  }

  static Future<bool> isChatMuted(String userId, String chatRoomId) async {
    try {
      DocumentReference muteOptionRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .collection('muteOptions')
          .doc(userId);

      DocumentSnapshot muteOptionSnapshot = await muteOptionRef.get();

      if (muteOptionSnapshot.exists) {
        bool currentMuteValue = (muteOptionSnapshot.data() as Map<String, dynamic>)['isMuted'] ?? false;
        return currentMuteValue;
      } else {
        return false;
      }
    } catch (e) {
      print("An error occurred while toggling mute option: $e");
      return false;
    }
  }

  static Stream<bool> isChatMutedStream(String userId, String chatRoomId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatRoomId)
        .collection('muteOptions')
        .doc(userId)
        .snapshots()
        .map<bool>((DocumentSnapshot documentSnapshot) {
      if (documentSnapshot.exists && documentSnapshot.data() is Map<String, dynamic>) {
        return (documentSnapshot.data() as Map<String, dynamic>)['isMuted'] ?? false;
      }
      return false;
    })
        .handleError((error) {
      print("An error occurred while listening to mute option: $error");
      // You may want to handle this error differently depending on your application's needs
      return false;
    });
  }

  static Future<List<SocialAccount>> getSocialAccounts(String userId) async {
    CollectionReference userSocialAccounts = FirebaseFirestore.instance.collection('userSocialAccounts');
    DocumentSnapshot snapshot = await userSocialAccounts.doc(userId).get();

    if (!snapshot.exists) {
      return [];
    }

    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    List<SocialAccount> accounts = [];

    data.forEach((platform, platformData) {
      if (platformData is Map<String, dynamic> && platformData['accounts'] is List<dynamic>) {
        accounts.addAll(
          List.from(platformData['accounts']).map((id) => SocialAccount(platform: platform, id: id)),
        );
      }
    });

    return accounts;
  }

}
