import 'package:BeeFriends/utils/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart';

class UserStatusWidget extends StatefulWidget {
  final Function upgradeAction;
  final double hPadding;
  @override
  _UserStatusWidgetState createState() => _UserStatusWidgetState();

  UserStatusWidget({
    Key? key,
    required this.upgradeAction,
    required this.hPadding,
  }) : super(key: key);
}

class _UserStatusWidgetState extends State<UserStatusWidget> {
  String accountType = 'REGULAR';
  late CompleteUser? currentUser = null;

  @override
  void initState() {
    super.initState();
    _checkAccountType();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newUser = UserProviderState.userOf(context);

    if (newUser != currentUser) {
      setState(() {
        currentUser = newUser;
        _checkAccountType();
      });
    }
  }

  Future<void> _checkAccountType() async {
    String userId = currentUser?.id ?? '';

    setState(() {
      accountType =  currentUser?.accountType ?? 'REGULAR';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: widget.hPadding),
      decoration: BoxDecoration(
        color: Colors.amber[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: accountType == 'PREMIUM' ? _buildPremiumUserContent() : _buildRegularUserContent(),
    );
  }

  Widget _buildRegularUserContent() {
    return Column(
      children: [
        Text(
          'Premium BeeFriends users get 3x more daily Beets',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            widget.upgradeAction();
            },
          child: Text('Upgrade Now'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
        ),
      ],
    );
  }

  Widget _buildPremiumUserContent() {
    return Column(
      children: [
        Text(
          'You are a premium member',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              Text(' Subscription Active', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        SizedBox(height: 10),
        Text(
          'You are currently receiving 3x daily beets',
          style: TextStyle(color: Colors.black45), textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
