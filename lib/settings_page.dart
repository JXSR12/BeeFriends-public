import 'package:BeeFriends/utils/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main.dart';
import 'matchmaking_settings_page.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, bool> booleanSettings = {
    // 'in_app_new_match_message': true,
    // 'in_app_new_friend_message': true,
    // 'in_app_new_matchrequest': true,
    // 'in_app_new_matchresponse': true,
    // 'in_app_new_friendrequest': true,
    // 'in_app_change_relationship': true,
    'push_new_match_message': true,
    'push_new_friend_message': true,
    'push_new_matchrequest': true,
    'push_new_matchresponse': true,
    'push_new_friendrequest': true,
    'push_change_relationship': true,
    'show_read_receipts': true,
  };

  bool isPremiumAccount = false;
  late CompleteUser? currentUser = null;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newUser = UserProviderState.userOf(context);

    if (newUser != currentUser) {
      setState(() {
        currentUser = newUser;
        _initializeSettings();
      });
    }
  }

  void _initializeSettings() async {
    setState(() {
      isPremiumAccount = currentUser?.accountType == "PREMIUM";
      print('is Premium check? $isPremiumAccount');
    });

    FirebaseFirestore.instance
        .collection('userSettings')
        .doc(currentUser?.id)
        .get()
        .then((doc) {
      if (doc.exists) {
        doc.data()?.forEach((key, value) {
          if (booleanSettings.containsKey(key)) {
            setState(() {
              booleanSettings[key] = value;
            });
          }
        });
      }
    });
  }

  void _updateSetting(String settingKey, bool value) {
    setState(() {
      booleanSettings[settingKey] = value;
    });

    FirebaseFirestore.instance
        .collection('userSettings')
        .doc(currentUser?.id)
        .set({settingKey: value}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          // _buildNotificationSettings('In-app Notifications', 'in_app'),
          _buildNotificationSettings('Push Notifications', 'push'),
          _buildChatSettings(),
          _buildMatchingPreferences(),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings(String title, String notifTypePrefix) {
    return Card(
      color: Theme.of(context).primaryColorLight,
      child: ExpansionTile(
        title: Text(title),
        children: [
          _buildSwitchListTile(
            title: 'Chat messages from your matches',
            settingKey: '${notifTypePrefix}_new_match_message',
          ),
          _buildSwitchListTile(
            title: 'Chat messages from your friends',
            settingKey: '${notifTypePrefix}_new_friend_message',
          ),
          _buildSwitchListTile(
            title: 'Incoming matching requests',
            settingKey: '${notifTypePrefix}_new_matchrequest',
          ),
          _buildSwitchListTile(
            title: 'Response to your matching requests',
            settingKey: '${notifTypePrefix}_new_matchresponse',
          ),
          _buildSwitchListTile(
            title: 'Friend request from your matches',
            settingKey: '${notifTypePrefix}_new_friendrequest',
          ),
          _buildSwitchListTile(
            title: 'Changes in the relation of your matches and friends with you',
            settingKey: '${notifTypePrefix}_change_relationship',
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchListTile({
    required String title,
    required String settingKey,
  }) {
    return SwitchListTile(
      title: Text(title),
      value: booleanSettings[settingKey] ?? true,
      onChanged: (val) => _updateSetting(settingKey, val),
    );
  }

  Widget _buildRestrictedSwitchListTile({
    required String title,
    required String settingKey,
    required bool changeAllowed,
  }) {
    return SwitchListTile(
      title: Text(title),
      value: booleanSettings[settingKey] ?? true,
      onChanged: changeAllowed ? (val) {
        _updateSetting(settingKey, val);
      } : null,
    );
  }

  Widget _buildChatSettings() {
    return Card(
      color: Theme.of(context).primaryColorLight,
      child: ExpansionTile(
        title: Text('Chat Settings'),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: EdgeInsets.all(20),
                child:
                  Column(children: [
                    RichText(
                      text: TextSpan(
                        children: <TextSpan>[
                          TextSpan(
                            text: 'Read Receipts',
                            style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: ' (Premium only)',
                            style: TextStyle(
                              color: Colors.deepOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 5,),
                    Text(
                      'Enable others to see the read indicator on chat messages to show that you have read a message. Disabling this would prevent the other user to know whether you have read their message or not. If you disable this, you would still be able to see others\' checkmark',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],)
              ),
              _buildRestrictedSwitchListTile(
                title: 'Show read receipts in your chats',
                settingKey: 'show_read_receipts',
                changeAllowed: isPremiumAccount
              ),
            ],
          )
        ],
      ),
    );
  }



  Widget _buildMatchingPreferences() {
    return Card(
      color: Theme.of(context).primaryColorLight,
      child: ListTile(
        title: Text('Matching Preferences'),
        subtitle: Text('Configure your matching preferences'),
        trailing: Icon(Icons.arrow_forward),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => MatchmakingSettingsPage()), // Define this page separately
          );
        },
      ),
    );
  }
}
