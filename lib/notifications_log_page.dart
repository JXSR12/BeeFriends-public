import 'package:BeeFriends/utils/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:BeeFriends/utils/inapp_notification_body.dart';

import 'main.dart';

class NotificationsLogPage extends StatefulWidget {
  @override
  _NotificationsLogPageState createState() => _NotificationsLogPageState();
}

class _NotificationsLogPageState extends State<NotificationsLogPage> {
  late CompleteUser? currentUser = null;
  final int _itemsPerPage = 10;
  List<DocumentSnapshot> _notifications = [];
  bool _isLoading = false;
  bool _hasMoreData = true;
  String? _selectedFilter;

  static const Map<String, String> _filterOptions = {
    'NEW_MATCH_REQUEST': 'Incoming Match Request',
    'RESPONSE_MATCH_STATUS': 'Match Request Accepted/Rejected',
    'NEW_FRIEND_REQUEST': 'Incoming Friend Request',
    'CHANGE_RELATIONSHIP': 'Relationship Changes',
    'PURCHASE_BEETS': 'Beets Purchase',
    'PURCHASE_PREMIUM': 'Premium Membership Subscription'
  };

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newUser = UserProviderState.userOf(context);
    if (newUser != currentUser) {
      setState(() {
        currentUser = newUser;
        _loadNotifications();
      });
    }
  }

  void _loadNotifications() async {
    if (_isLoading || !_hasMoreData) return;

    Query query = FirebaseFirestore.instance
        .collection('notifications/${currentUser?.id ?? 'UNKNOWN'}/eventNotifications')
        .orderBy('timestamp', descending: true);

    if (_selectedFilter != null) {
      query = query.where('notifType', isEqualTo: _selectedFilter);
    }

    if (_notifications.isNotEmpty) {
      query = query.startAfterDocument(_notifications.last);
    }

    QuerySnapshot querySnapshot = await query
        .limit(_itemsPerPage)
        .get();

    if (querySnapshot.docs.length < _itemsPerPage) _hasMoreData = false;

    setState(() {
      _notifications.addAll(querySnapshot.docs);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notifications History')),
      body: Column(
        children: [
          _buildFilterDropdown(),
          const SizedBox(height: 20),
          Expanded(
            child: _notifications.isEmpty && !_isLoading
                ? Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off,
                      color: Colors.black54,
                      size: 60.0,
                    ),
                    SizedBox(height: 20.0),
                    Text(
                      'No Notifications Yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 10.0),
                    Text(
                      'All your notifications will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                if (index >= _notifications.length - 1 && _hasMoreData) {
                  _loadNotifications();
                }
                return _buildNotificationItem(_notifications[index]);
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
      margin: EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Theme.of(context).indicatorColor, width: 2),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(
            'Filter by Type',
            style: TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.bold,
            ),
          ),
          value: _selectedFilter,
          icon: Icon(Icons.arrow_drop_down_rounded, color: Theme.of(context).indicatorColor),
          iconSize: 30.0,
          isExpanded: true,
          dropdownColor: Colors.white,
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('Show All'),
            ),
            ..._filterOptions.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
          ],
          onChanged: (String? newValue) {
            setState(() {
              _selectedFilter = newValue;
              _notifications.clear();
              _hasMoreData = true;
              _loadNotifications();
            });
          },
        ),
      ),
    );
  }



  Widget _buildNotificationItem(DocumentSnapshot message) {
    switch (message['notifType']) {
      case 'NEW_MATCH_REQUEST':
        return MatchRequestNotificationBody(log: true, paidMessage: message['paidMessage'], timestamp: message['timestamp'],);
      case 'RESPONSE_MATCH_STATUS':
        return MatchStatusNotificationBody(log: true, status: message['status'], chatRoomId: message['chatRoomId'], recipientId: message['recipientId'], timestamp: message['timestamp']);
      case 'NEW_FRIEND_REQUEST':
        return FriendRequestNotificationBody(log: true, senderId: message['senderId'], chatRoomId: message['chatRoomId'], timestamp: message['timestamp']);
      case 'CHANGE_RELATIONSHIP':
        return RelationshipChangeNotificationBody(log: true, senderId: message['senderId'], senderName: message['senderName'], chatRoomId: message['chatRoomId'], oldRelationship: message['oldRelationship'], newRelationship: message['newRelationship'], timestamp: message['timestamp']);
      case 'PURCHASE_PREMIUM':
        return PremiumSubscribeNotificationBody(log: true, timestamp: message['timestamp'],);
      case 'PURCHASE_BEETS':
        return BeetsPurchaseNotificationBody(log: true, amount: message['beetsAmount'] is String ? int.parse(message['beetsAmount']) : (message['beetsAmount'] as num).toInt(), timestamp: message['timestamp']);
      default:
        return SizedBox.shrink();
    }
  }
}
