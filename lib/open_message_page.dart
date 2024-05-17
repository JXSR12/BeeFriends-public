import 'dart:io';

import 'package:BeeFriends/chats_page.dart';
import 'package:BeeFriends/main.dart';
import 'package:BeeFriends/match_requests_page.dart';
import 'package:BeeFriends/profile_page.dart';
import 'package:BeeFriends/utils/common_bottom_app_bar.dart';
import 'package:BeeFriends/utils/display_utils.dart';
import 'package:BeeFriends/utils/inapp_notification_body.dart';
import 'package:BeeFriends/utils/notification_controller.dart';
import 'package:BeeFriends/utils/notification_manager.dart';
import 'package:BeeFriends/utils/tips_carousel.dart';
import 'package:BeeFriends/utils/user_provider.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:animated_button_bar/animated_button_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path/path.dart' as Path;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_button/flutter_swipe_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_notification/in_app_notification.dart';
import 'package:transparent_image/transparent_image.dart';

import 'home.dart';
import 'login_page.dart';
import 'main_page.dart';
import 'notifications_log_page.dart';

class OpenMessagePage extends StatefulWidget {
  @override
  _OpenMessageState createState() => _OpenMessageState();
}

class _OpenMessageState extends State<OpenMessagePage> with WidgetsBindingObserver {
  late CompleteUser? currentUser = null;
  final ScrollController _scrollController = ScrollController();
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  List<DocumentSnapshot> _confessions = [];

  final ScrollController _myConfessionsScrollController = ScrollController();
  DocumentSnapshot? _myLastDocument;
  bool _myIsLoading = false;
  List<DocumentSnapshot> _myConfessions = [];

  Map<String, Map<String, dynamic>> _confessionVoteData = {};

  bool _showingMyConfessions = false;

  String _selectedFilter = 'Latest';

  final ValueNotifier<bool> _isUploading = ValueNotifier<bool>(false);

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

  final TextEditingController _confessionController = TextEditingController();

  static final Config config = Config(
      tenant: 'common',
      clientId: 'b89cc19d-4587-4170-9b80-b39204b74380',
      scope: 'openid profile offline_access User.Read',
      redirectUri: 'https://beefriends-a1c17.firebaseapp.com/__/auth/handler',
      navigatorKey: navigatorKey,
      loader: SizedBox());
  final AadOAuth oauth = AadOAuth(config);

  @override
  void initState() {
    super.initState();
    _loadConfessions();
    _loadMyConfessions();
    _scrollController.addListener(_scrollListener);
    _myConfessionsScrollController.addListener(_myScrollListener);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkLoginStatus();
    }
  }

  void _checkLoginStatus() async {
    bool isLoggedIn = await oauth.hasCachedAccountInformation;
    print('Is logged in? $isLoggedIn');
    if (!isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginPage(
            onUserLoggedIn: () {
              navigatorKey.currentState?.pushReplacement(
                  MaterialPageRoute(builder: (context) => Home()));
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _myConfessionsScrollController.removeListener(_myScrollListener);
    _myConfessionsScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _clearMyConfessions() async {
    _myLastDocument = null;
    _myConfessions.clear();
    _myIsLoading = false;
  }

  Future<void> _clearConfessions() async {
    _lastDocument = null;
    _confessions.clear();
    _isLoading = false;
  }

  Future<void> _loadMyConfessions() async {
    if (_myIsLoading) return;
    _myIsLoading = true;

    QuerySnapshot querySnapshot;
    var baseQuery = FirebaseFirestore.instance.collection('confessions');
    var now = Timestamp.now();
    var startOfToday = DateTime(now.toDate().year, now.toDate().month, now.toDate().day);

    switch (_selectedFilter) {
      case 'Latest':
        querySnapshot = await _fetchLatestConfessions(baseQuery);
        break;
      case 'Top rated':
        querySnapshot = await _fetchTopConfessions(baseQuery);
        break;
      case 'Trending today':
        querySnapshot = await _fetchTopRangedConfessions(baseQuery, Timestamp.fromDate(startOfToday), now);
        break;
      case 'Trending this week':
        var startOfWeek = startOfToday.subtract(Duration(days: startOfToday.weekday - 1));
        querySnapshot = await _fetchTopRangedConfessions(baseQuery, Timestamp.fromDate(startOfWeek), now);
        break;
      case 'Trending this month':
        var startOfMonth = DateTime(now.toDate().year, now.toDate().month, 1);
        querySnapshot = await _fetchTopRangedConfessions(baseQuery, Timestamp.fromDate(startOfMonth), now);
        break;
      default:
        querySnapshot = await _fetchLatestConfessions(baseQuery);
    }



    for (var doc in querySnapshot.docs) {
      _confessionVoteData[doc.id] = doc.data() as Map<String, dynamic>;
    }

    if (querySnapshot.docs.isNotEmpty) {
      _myLastDocument = querySnapshot.docs.last;
      _myConfessions.addAll(querySnapshot.docs);
    }

    setState(() {
      _myIsLoading = false;
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !_isLoading) {
      _loadConfessions();
    }
  }

  void _myScrollListener(){
    if (_myConfessionsScrollController.position.pixels == _myConfessionsScrollController.position.maxScrollExtent && !_myIsLoading) {
      _loadMyConfessions();
    }
  }

  Future<void> _loadConfessions() async {
    if (_isLoading) return;
    _isLoading = true;

    QuerySnapshot querySnapshot;
    var baseQuery = FirebaseFirestore.instance.collection('confessions');
    var now = Timestamp.now();
    var startOfToday = DateTime(now.toDate().year, now.toDate().month, now.toDate().day);

    switch (_selectedFilter) {
      case 'Latest':
        querySnapshot = await _fetchLatestConfessions(baseQuery);
        break;
      case 'Top rated':
        querySnapshot = await _fetchTopConfessions(baseQuery);
        break;
      case 'Trending today':
        querySnapshot = await _fetchTopRangedConfessions(baseQuery, Timestamp.fromDate(startOfToday), now);
        break;
      case 'Trending this week':
        var startOfWeek = startOfToday.subtract(Duration(days: startOfToday.weekday - 1));
        querySnapshot = await _fetchTopRangedConfessions(baseQuery, Timestamp.fromDate(startOfWeek), now);
        break;
      case 'Trending this month':
        var startOfMonth = DateTime(now.toDate().year, now.toDate().month, 1);
        querySnapshot = await _fetchTopRangedConfessions(baseQuery, Timestamp.fromDate(startOfMonth), now);
        break;
      default:
        querySnapshot = await _fetchLatestConfessions(baseQuery);
    }

    for (var doc in querySnapshot.docs) {
      _confessionVoteData[doc.id] = doc.data() as Map<String, dynamic>;
    }

    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
      setState(() {
        _confessions.addAll(querySnapshot.docs);
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<QuerySnapshot> _fetchLatestConfessions(Query baseQuery) async {
    Query query = baseQuery.orderBy('timestamp', descending: true).limit(10);
    DocumentSnapshot<Object?>? lastDoc = _showingMyConfessions ? _myLastDocument : _lastDocument;
    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }
    if(_showingMyConfessions){
      query = query.where('userId', isEqualTo: currentUser?.id ?? 'nonexistent');
    }
    return await query.get();
  }

  Future<QuerySnapshot> _fetchTopConfessions(Query baseQuery) async {
    Query query = baseQuery;

    if(_showingMyConfessions){
      query = query.where('userId', isEqualTo: currentUser?.id ?? 'nonexistent');
    }
    query = query.orderBy('totalvotes', descending: true);

    DocumentSnapshot<Object?>? lastDoc = _showingMyConfessions ? _myLastDocument : _lastDocument;

    query = query.limit(10);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    return await query.get();
  }


  Future<QuerySnapshot> _fetchTopRangedConfessions(Query baseQuery, Timestamp start, Timestamp end) async {
    Query query = baseQuery;

    //WIP -> Cannot sort based on timestamp and votes at a time
    if(_showingMyConfessions){
      query = query.where('userId', isEqualTo: currentUser?.id ?? 'nonexistent');
    }
    query = query.orderBy('totalvotes', descending: true);

    DocumentSnapshot<Object?>? lastDoc = _showingMyConfessions ? _myLastDocument : _lastDocument;

    query = query.limit(10);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    return await query.get();
  }


  @override
  Widget build(BuildContext context) {

    return Stack(children: [
      Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue, Colors.blue.shade700],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'OpenMessages',
                  textAlign: TextAlign.center, // Centers the text inside the container
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(1.0, 1.0),
                        blurRadius: 3.0,
                        color: Colors.deepPurple.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(width: 100,
                  child:
                  AnimatedButtonBar(
                    backgroundColor: Colors.white70,
                    foregroundColor: Colors.blue,
                    elevation: 2,
                    radius: 8.0,
                    padding: const EdgeInsets.all(2.0),
                    invertedSelection: true,
                    children: [
                      ButtonBarEntry(onTap: () {
                        _showingMyConfessions ? _toggleConfessionsMode(context) : null;
                      }, child: Icon(Icons.public)),
                      ButtonBarEntry(onTap: () {
                        !_showingMyConfessions ? _toggleConfessionsMode(context) : null;
                      }, child: Icon(Icons.person)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _showMakeConfessionDialog(context);
                  },
                  icon: Icon(Icons.add),
                  label: Text('Create'),
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).indicatorColor),
                ),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
                      decoration: BoxDecoration(
                        color: Colors.white, // Background color
                        border: Border.all(color: Colors.blue, width: 2.0), // Thin blue border
                        borderRadius: BorderRadius.circular(10.0), // Rounded corners
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 3), // Elevation effect
                          ),
                        ],
                      ),
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedFilter = newValue!;
                            _showingMyConfessions ? _clearMyConfessions() : _clearConfessions();
                            _showingMyConfessions ? _loadMyConfessions() : _loadConfessions();
                          });
                        },
                        items: <String>['Latest', 'Top rated'].map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: TextStyle(fontWeight: _selectedFilter == value ? FontWeight.bold : FontWeight.normal),),
                          );
                        }).toList(),
                        underline: Container(), // Removes default underline
                        isExpanded: false, // Expands to fill the container
                        dropdownColor: Colors.white, // Dropdown background color
                      ),
                    )
                ),
              ],
            ),
            SizedBox(height: 10),
            if(_showingMyConfessions && _myConfessions.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 120),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _myIsLoading ?
                      SpinKitCubeGrid(size: 40, color: Colors.black54, duration: Duration(milliseconds: 300),)
                          :
                      Icon(
                        Icons.textsms_outlined,
                        color: Colors.black54,
                        size: 40.0,
                      )
                      ,
                      SizedBox(height: 20.0),
                      Text(
                        _myIsLoading ? 'Loading..' : 'No OpenMessages yet',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: 10.0),
                      Text(
                        _myIsLoading ? 'Retrieving messages..' : 'You haven\'t made any public OpenMessages yet.',
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
            else if (!_showingMyConfessions && _confessions.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 120),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _isLoading ?
                      SpinKitCubeGrid(size: 40, color: Colors.black54, duration: Duration(milliseconds: 300),)
                          :
                      Icon(
                        Icons.textsms_outlined,
                        color: Colors.black54,
                        size: 40.0,
                      ),
                      SizedBox(height: 20.0),
                      Text(
                        _isLoading ? 'Loading..' : 'No OpenMessages yet',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: 10.0),
                      Text(
                        _isLoading ? 'Retrieving messages..' : 'There haven\'t been any public OpenMessages yet.',
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
            else
              Expanded(
                child: RefreshIndicator(
                    onRefresh: () async {
                      refreshConfessions();
                    },
                    child: _showingMyConfessions ? _myIsLoading ? Center(child: SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 200),)),) :
                    ListView.builder(
                      controller: _scrollController,
                      itemCount: _myConfessions.length,
                      physics: AlwaysScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        var confession = _myConfessions[index];
                        var message = confession['message'];
                        var imageUrl = (confession.data() as Map<String, dynamic>).containsKey('imageUrl') ? confession['imageUrl'] : null;
                        var timestamp = confession['timestamp'] as Timestamp?;
                        String formattedTime = _formatTimestamp(timestamp);
                        var confessionData = confession.data() as Map<String, dynamic>;

                        var voteData = _confessionVoteData[confession.id];

                        var upvoters = voteData?['upvoters'] ?? [];
                        var downvoters = voteData?['downvoters'] ?? [];

                        bool isUpvoted = (upvoters as List<dynamic>).contains(currentUser?.id);
                        bool isDownvoted = (downvoters as List<dynamic>).contains(currentUser?.id);

                        int upvotes = voteData?['upvotes'] ?? 0;
                        int downvotes = voteData?['downvotes'] ?? 0;

                        int totalVotes = upvotes - downvotes;


                        return InkWell(
                          child: Card(
                            elevation: 3,
                            margin: EdgeInsets.all(3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            color: Colors.blue[50],
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Check if imageUrl exists and is not null
                                          if (imageUrl != null)
                                            Stack(
                                              children: [
                                                Container(
                                                  height: 300, // Max height for image
                                                  width: double.infinity,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(6),
                                                    image: DecorationImage(
                                                      image: NetworkImage(imageUrl),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  left: 0,
                                                  right: 0,
                                                  child: Container(
                                                    padding: EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black87.withOpacity(0.7), // White semi-transparent overlay
                                                      borderRadius: BorderRadius.only(
                                                        bottomLeft: Radius.circular(6),
                                                        bottomRight: Radius.circular(6),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      message,
                                                      style: TextStyle(fontSize: 14, color: Colors.white), // Adjust text color if necessary
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (imageUrl == null)
                                            Container(
                                              width: double.infinity,
                                              padding: EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[100],
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                message,
                                                style: TextStyle(fontSize: 14),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          Divider(),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            children: [
                                              Text(
                                                'posted $formattedTime',
                                                style: TextStyle(color: Colors.grey, fontSize: 15),
                                              ),
                                              Spacer(),
                                              TextButton(
                                                  onPressed: () {
                                                    _showDeleteConfirmation(context, confession.id);
                                                  },
                                                  child: Text('Delete Message', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),)
                                              )
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.arrow_upward, color: isUpvoted ? Colors.blueAccent : Colors.black.withOpacity(0.6)),
                                        onPressed: () {
                                          _upvoteConfession(confession);
                                        },
                                      ),
                                      if (totalVotes != 0)
                                        Text("$totalVotes", style: TextStyle(color: Colors.black, fontSize: 15)),
                                      IconButton(
                                        icon: Icon(Icons.arrow_downward, color: isDownvoted ? Colors.redAccent : Colors.black.withOpacity(0.6)),
                                        onPressed: () {
                                          _downvoteConfession(confession);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          onTap: () {
                            _showFullConfession(context, confession.id, confession['userId'], message, timestamp!, imageUrl);
                          },
                        );

                      },
                    ) : _isLoading ? Center(child: SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 200),)),) : ListView.builder(
                      controller: _scrollController,
                      itemCount: _confessions.length,
                      physics: AlwaysScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        var confession = _confessions[index];
                        var message = confession['message'];
                        var imageUrl = (confession.data() as Map<String, dynamic>).containsKey('imageUrl') ? confession['imageUrl'] : null;
                        var timestamp = confession['timestamp'] as Timestamp?;
                        String formattedTime = _formatTimestamp(timestamp);
                        var confessionData = confession.data() as Map<String, dynamic>;

                        var voteData = _confessionVoteData[confession.id];

                        var upvoters = voteData?['upvoters'] ?? [];
                        var downvoters = voteData?['downvoters'] ?? [];

                        bool isUpvoted = (upvoters as List<dynamic>).contains(currentUser?.id);
                        bool isDownvoted = (downvoters as List<dynamic>).contains(currentUser?.id);

                        int upvotes = voteData?['upvotes'] ?? 0;
                        int downvotes = voteData?['downvotes'] ?? 0;

                        int totalVotes = upvotes - downvotes;

                        return InkWell(
                          child: Card(
                            elevation: 3,
                            margin: EdgeInsets.all(3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            color: Colors.blue[50],
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Check if imageUrl exists and is not null
                                          if (imageUrl != null)
                                            Stack(
                                              children: [
                                                Container(
                                                  height: 300,
                                                  width: double.infinity,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: FadeInImage.memoryNetwork(
                                                      placeholder: kTransparentImage,
                                                      image: imageUrl,
                                                      fit: BoxFit.cover,
                                                      height: 300,
                                                      width: double.infinity,
                                                      imageErrorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                                        return Container(
                                                          height: 300,
                                                          width: double.infinity,
                                                          decoration: BoxDecoration(
                                                            color: Colors.black.withOpacity(0.5),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Icon(
                                                            Icons.image_outlined,
                                                            color: Colors.white,
                                                            size: 100,
                                                          ),
                                                          alignment: Alignment.center,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  left: 0,
                                                  right: 0,
                                                  child: Container(
                                                    padding: EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black87.withOpacity(0.7), // White semi-transparent overlay
                                                      borderRadius: BorderRadius.only(
                                                        bottomLeft: Radius.circular(6),
                                                        bottomRight: Radius.circular(6),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      message,
                                                      style: TextStyle(fontSize: 14, color: Colors.white), // Adjust text color if necessary
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (imageUrl == null)
                                            Container(
                                              width: double.infinity,
                                              padding: EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[100],
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                message,
                                                style: TextStyle(fontSize: 14),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          Divider(),
                                          Text(
                                            'posted $formattedTime',
                                            style: TextStyle(color: Colors.grey, fontSize: 15),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.arrow_upward, color: isUpvoted ? Colors.blueAccent : Colors.black.withOpacity(0.6)),
                                        onPressed: () {
                                          _upvoteConfession(confession);
                                        },
                                      ),
                                      if (totalVotes != 0)
                                        Text("$totalVotes", style: TextStyle(color: Colors.black, fontSize: 15)),
                                      IconButton(
                                        icon: Icon(Icons.arrow_downward, color: isDownvoted ? Colors.redAccent : Colors.black.withOpacity(0.6)),
                                        onPressed: () {
                                          _downvoteConfession(confession);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          onTap: () {
                            _showFullConfession(context, confession.id, confession['userId'], message, timestamp!, imageUrl);
                          },
                        );
                      },
                    )
                ),
              ),
          ],
        ),
      ),
    ],);
  }

  void _upvoteConfession(DocumentSnapshot<Object?> confession) {
    var confessionId = confession.id;
    var userId = currentUser?.id;
    var voteData = _confessionVoteData[confessionId];

    // Check if the user has already upvoted
    var confessionData = confession.data() as Map<String, dynamic>;

    if ((voteData?['upvoters'] as List<dynamic>?)?.contains(userId) ?? false) {
      voteData?['upvotes'] = (voteData?['upvotes'] ?? 0) - 1;
      voteData?['upvoters'] = (voteData?['upvoters'] ?? [] as List).where((id) => id != userId).toList();

      setState(() {
        _confessionVoteData[confessionId] = voteData!;
      });
      _upvoteOpenMessage(confession);
      return;
    }

    // Increment upvotes and add userId to upvoters list
    voteData?['upvotes'] = (voteData?['upvotes'] ?? 0) + 1;
    voteData?['upvoters'] = [...(voteData?['upvoters'] ?? []), userId];

    // Check if the user was previously a downvoter
    if ((voteData?['downvoters'] as List<dynamic>?)?.contains(userId) ?? false) {
      voteData?['downvotes'] = (voteData?['downvotes']  ?? 0) - 1;
      voteData?['downvoters'] = (voteData?['downvoters'] ?? [] as List).where((id) => id != userId).toList();
    }

    // Update the UI
    setState(() {
      _confessionVoteData[confessionId] = voteData!;
    });
    _upvoteOpenMessage(confession);
  }


  void _downvoteConfession(DocumentSnapshot<Object?> confession) {
    var confessionId = confession.id;
    var userId = currentUser?.id;
    var voteData = _confessionVoteData[confessionId];

    var confessionData = confession.data() as Map<String, dynamic>;
    // Check if the user has already downvoted
    if ((voteData?['downvoters'] as List<dynamic>?)?.contains(userId) ?? false) {
      voteData?['downvotes'] = (voteData?['downvotes'] ?? 0) - 1;
      voteData?['downvoters'] = (voteData?['downvoters'] ?? [] as List).where((id) => id != userId).toList();

      setState(() {
        _confessionVoteData[confessionId] = voteData!;
      });
      _downvoteOpenMessage(confession);
      return;
    }

    // Increment downvotes and add userId to downvoters list
    voteData?['downvotes'] = (voteData?['downvotes'] ?? 0) + 1;
    voteData?['downvoters'] = [...(voteData?['downvoters'] ?? []), userId];

    // Check if the user was previously an upvoter
    if ((voteData?['upvoters'] as List<dynamic>?)?.contains(userId) ?? false) {
      voteData?['upvotes'] = (voteData?['upvotes'] ?? 0) - 1;
      voteData?['upvoters'] = (voteData?['upvoters'] ?? [] as List).where((id) => id != userId).toList();
    }

    // Update the UI
    setState(() {
      _confessionVoteData[confessionId] = voteData!;
    });
    _downvoteOpenMessage(confession);
  }



  Future<void> _upvoteOpenMessage(DocumentSnapshot<Object?> confession) async {
    var confessionId = confession.id;
    var userId = currentUser?.id;

    var confessionRef = FirebaseFirestore.instance.collection('confessions').doc(confessionId);
    var currentConfession = await confessionRef.get();
    var confessionData = currentConfession.data() as Map<String, dynamic>;

    var batch = FirebaseFirestore.instance.batch();

    if ((confessionData['upvoters'] as List<dynamic>?)?.contains(userId) ?? false) {
      // Remove user ID from downvoters and decrement downvote count
      batch.update(confessionRef, {
        'upvoters': FieldValue.arrayRemove([userId]),
        'upvotes': FieldValue.increment(-1),
        'totalvotes': FieldValue.increment(-1)
      });
      await batch.commit();
      return;
    }

    // Check if the user has already downvoted
    if ((confessionData['downvoters'] as List<dynamic>?)?.contains(userId) ?? false) {
      // Remove user ID from downvoters and decrement downvote count
      batch.update(confessionRef, {
        'downvoters': FieldValue.arrayRemove([userId]),
        'downvotes': FieldValue.increment(-1),
        'totalvotes': FieldValue.increment(1)
      });
    }

    // Add user ID to upvoters and increment upvote count
    batch.update(confessionRef, {
      'upvoters': FieldValue.arrayUnion([userId]),
      'upvotes': FieldValue.increment(1),
      'totalvotes': FieldValue.increment(1)
    });

    await batch.commit();
  }



  Future<void> _downvoteOpenMessage(DocumentSnapshot<Object?> confession) async {
    var confessionId = confession.id;
    var userId = currentUser?.id;

    var confessionRef = FirebaseFirestore.instance.collection('confessions').doc(confessionId);
    var currentConfession = await confessionRef.get();
    var confessionData = currentConfession.data() as Map<String, dynamic>;

    var batch = FirebaseFirestore.instance.batch();

    if ((confessionData['downvoters'] as List<dynamic>?)?.contains(userId) ?? false) {
      // Remove user ID from downvoters and decrement downvote count
      batch.update(confessionRef, {
        'downvoters': FieldValue.arrayRemove([userId]),
        'downvotes': FieldValue.increment(-1),
        'totalvotes': FieldValue.increment(1)
      });
      await batch.commit();
      return;
    }

    // Check if the user has already upvoted
    if ((confessionData['upvoters'] as List<dynamic>?)?.contains(userId) ?? false) {
      // Remove user ID from upvoters and decrement upvote count
      batch.update(confessionRef, {
        'upvoters': FieldValue.arrayRemove([userId]),
        'upvotes': FieldValue.increment(-1),
        'totalvotes': FieldValue.increment(-1)
      });
    }

    // Add user ID to downvoters and increment downvote count
    batch.update(confessionRef, {
      'downvoters': FieldValue.arrayUnion([userId]),
      'downvotes': FieldValue.increment(1),
      'totalvotes': FieldValue.increment(-1)
    });

    await batch.commit();
  }




  Future<void> refreshConfessions() async {
    setState(() {
      if(_showingMyConfessions){
        _clearMyConfessions();
        _loadMyConfessions();
      }else{
        _clearConfessions();
        _loadConfessions();
      }
    });
  }

  String _formatTimestamp(Timestamp? timestamp) {
    DateTime date = timestamp?.toDate() ?? DateTime.now();
    DateTime currentDate = DateTime.now();
    int differenceInMinutes = currentDate.difference(date).inMinutes;

    if (differenceInMinutes.floor() < 1) {
      return 'just now';
    } else if (differenceInMinutes < 60) {
      return '${differenceInMinutes}m ago';
    } else if (differenceInMinutes < 1440) {
      return '${(differenceInMinutes / 60).floor()}h ago';
    } else if (differenceInMinutes < 10080) {
      return '${(differenceInMinutes / 1440).floor()}d ago';
    } else {
      return '${(differenceInMinutes / 10080).floor()}w ago';
    }
  }

  void _showMakeConfessionDialog(BuildContext context) {
    final functions = FirebaseFunctions.instance;
    final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser?.id);
    _confessionController.clear();

    bool isFetchingCost = true;
    bool hasImageAttached = false;

    XFile? pickedFile = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 200),)),
              SizedBox(width: 20),
              Text('Fetching cost..'),
            ],
          ),
        );
      },
    );

    File? attachedImageFile;
    final ImagePicker _picker = ImagePicker();

    // Fetch the current cost
    functions.httpsCallableFromUrl('https://asia-southeast2-beefriends-a1c17.cloudfunctions.net/getOpenMessageCost').call({
      'userId': currentUser?.id,
    }).then((result) {
      isFetchingCost = false;
      Navigator.of(context).pop();

      int cost = result.data['cost'];

      showModalBottomSheet<dynamic>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Padding(
                padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
              child:
              Stack(
                  children: [
                    Container(
                      color: Colors.blue[50], // Color scheme
                      padding: EdgeInsets.all(15),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Create an OpenMessage',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
                              ElevatedButton(
                                onPressed: () {
                                  if (_confessionController.text.trim().isNotEmpty) {
                                    _confirmAndPostConfession(context, cost, hasImageAttached, pickedFile);
                                  }
                                },
                                child:  Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(cost == 0 ? 'Post for Free' : 'Post for $cost '),
                                    if(cost > 0)
                                      SvgPicture.asset('assets/beets_icon.svg', height: 20, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 5),
                          Divider(),
                          SizedBox(height: 5),
                          // TextField and other UI elements
                          Card(
                              elevation: 4.0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(padding: EdgeInsets.only(bottom: 10, top: 12),
                                child:
                                TextField(
                                  controller: _confessionController,
                                  maxLines: 4,
                                  maxLength: 600,
                                  decoration: InputDecoration(
                                    hintText: 'Type your thoughts here.',
                                    fillColor: Colors.white,
                                    border: UnderlineInputBorder(),
                                    filled: true,
                                  ),
                                ),
                              )
                          ),

                          SizedBox(height: 10),
                          Text('OpenMessages will remain anonymous to everyone, but you will still be responsible if the content violates our content restrictions.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
                          SizedBox(height: 15),
                          GestureDetector(
                            onTap: () async {
                              if (attachedImageFile == null) {
                                pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                                if (pickedFile != null) {
                                  attachedImageFile = File(pickedFile!.path);
                                  hasImageAttached = true;
                                  cost += 1;
                                  setModalState(() {});
                                }
                              }
                            },
                            child:  Card(
                              color: Colors.white,
                              elevation: 4.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                width: double.infinity,
                                height: 150,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: attachedImageFile != null
                                      ? DecorationImage(
                                    image: FileImage(attachedImageFile!),
                                    fit: BoxFit.cover,
                                  )
                                      : null,
                                ),
                                child: attachedImageFile == null
                                    ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_rounded, size: 50, color: Colors.black54,),
                                      SizedBox(height: 10,),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'You can add one picture for 1 ',
                                              style: TextStyle(fontSize: 12, color: Colors.black54),
                                            ),
                                            WidgetSpan(
                                              child: SvgPicture.asset(
                                                'assets/beets_icon.svg',
                                                height: 12,
                                                colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    ])
                                    : Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5), // Overlay for cancel icon
                                        borderRadius: BorderRadius.only(
                                            bottomLeft: Radius.circular(12),
                                            topRight: Radius.circular(12)
                                        ),
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.cancel, color: Colors.red[300]),
                                        onPressed: () {
                                          pickedFile = null;
                                          attachedImageFile = null;
                                          hasImageAttached = false;
                                          cost -= 1;
                                          setModalState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isUploading,
                      builder: (context, isUploading, child) {
                        if (!isUploading) return SizedBox.shrink();

                        return Positioned.fill(
                          child: Container(
                            color: Colors.black45,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(height: 30, child: SpinKitWave(color: Colors.white60, duration: Duration(milliseconds: 800),)),
                                  SizedBox(height: 20),
                                  Text('Uploading image and posting..', style: TextStyle(color: Colors.white),)
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ])
              );
            },
          );
        },
      );
    });
  }

  Future<void> _confirmAndPostConfession(BuildContext context, int cost, bool hasImage, XFile? pickedFile) async {
    final functions = FirebaseFunctions.instance;
    final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser?.id);

    String? imageUrl;

    DocumentSnapshot userSnapshot = await userRef.get();
    int? currentBeets = (userSnapshot.get('beets') as num).toInt();

    if (currentBeets == null || currentBeets < cost) {
      // Show insufficient beets alert
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Insufficient Beets"),
            content: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: Colors.black),
                children: [
                  TextSpan(text: "You do not have enough "),
                  WidgetSpan(
                    child: SvgPicture.asset('assets/beets_icon.svg', height: 20, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                  ),
                  TextSpan(text: " Beets to post an OpenMessage. Please collect more beets and try again."),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("Dismiss"),
              ),
            ],
          );
        },
      );
    } else {
      // Show confirmation dialog
      final shouldPost = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirmation'),
          content: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.black),
              children: [
                TextSpan(text: "By confirming, you will spend $cost "),
                WidgetSpan(
                  child: SvgPicture.asset('assets/beets_icon.svg', height: 20, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                ),
                TextSpan(text: " in order to post this OpenMessage."),
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

      if (shouldPost) {
        _isUploading.value = true;
        if (pickedFile != null) {
          XFile? xfile = await FlutterImageCompress.compressAndGetFile(
            pickedFile.path,
            '${Path.dirname(pickedFile.path)}/${Path.basenameWithoutExtension(pickedFile.path)}_compressed.jpg',
            quality: 30,
          );

          File file = File(xfile!.path);

          Reference storageRef = FirebaseStorage.instance.ref().child('openmessage_pictures/${currentUser?.id}/${Path.basename(file.path)}');
          UploadTask uploadTask = storageRef.putFile(file);

          TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
          imageUrl = await snapshot.ref.getDownloadURL();
        }

        String content = _confessionController.text.trim();
        Navigator.of(context).pop();
        _confessionController.clear();

        _isUploading.value = false;

        final res = await functions.httpsCallableFromUrl('https://asia-southeast2-beefriends-a1c17.cloudfunctions.net/postOpenMessage').call({
          'userId': currentUser?.id,
          'message': content,
          'hasImage': hasImage.toString(),
          'imageUrl': imageUrl
        }).catchError((error) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Failed to Post OpenMessage"),
                content: Text("A server side error has occured while trying to post your OpenMessage. No Beets are spent, please try again later."),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text("Dismiss"),
                  ),
                ],
              );
            },
          );
        });

        if (res.data()['success'] != true){
          throw Error();
        }
        refreshConfessions();
      }
    }
  }

  Future<void> _toggleConfessionsMode(BuildContext context) async {
    setState(() {
      _showingMyConfessions = !_showingMyConfessions;
      refreshConfessions();
    });
  }

  void _showDeleteConfirmation(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete OpenMessage'),
          content: Text('Are you sure you want to delete this OpenMessage?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the delete confirmation dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                FirebaseFirestore.instance.collection('confessions').doc(docId).get().then((documentSnapshot) {
                  if (documentSnapshot.exists) {
                    String ownerId = documentSnapshot.data()?['userId'] ?? '';
                    if (currentUser?.id == ownerId) {
                      FirebaseFirestore.instance.collection('confessions').doc(docId).delete().then((value) {
                        Navigator.of(context).pop();
                        refreshConfessions();
                      }).catchError((error) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error deleting OpenMessage. Please try again later.')),
                        );
                      });
                    } else {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('You do not have permission to delete this OpenMessage.')),
                      );
                    }
                  } else {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('OpenMessage not found.')),
                    );
                  }
                }).catchError((error) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error fetching OpenMessage details.')),
                  );
                });
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }


  void _showFullConfession(BuildContext context, String docId, String authorId, String message, Timestamp timestamp, String? imageUrl) {
    final DateTime date = timestamp.toDate();
    final String formattedDate = "${date.day} ${DisplayUtils.monthNames[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      showDragHandle: false,
      builder: (BuildContext context) {
        return Container(
          height: 650,
          color: Colors.blue[50],
          padding: EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Divider(
                thickness: 4,
                height: 30,
                color: Colors.blue[100], // Changed color for the drag handle
                indent: 165,
                endIndent: 165,
              ),
              SizedBox(height: 10),
              Expanded(
                child: Card(
                  color: Colors.white,
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: Padding(
                        padding: EdgeInsets.all(15.0),
                        child: SingleChildScrollView(
                          child: Text(
                            message,
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      ),
                      if (imageUrl != null) // Check if imageUrl is not null
                        InkWell(
                          onTap: () {
                            DisplayUtils.openImageDialog(context, [imageUrl], 0); // Open image dialog
                          },
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.blue[100], // Notch background color
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(15.0),
                                bottomRight: Radius.circular(15.0),
                              ),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility, color: Colors.blueAccent), // View icon
                                SizedBox(width: 8),
                                Text('View attached picture', style: TextStyle(color: Colors.blueAccent)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height:15),
              Container(
                alignment: Alignment.center,
                width: double.infinity,
                child:
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontWeight: FontWeight.w300,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Divider(thickness: 1,),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Replies', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Long press a reply to report it', style: TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add_box_rounded),
                    label: Text('Make a reply', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlueAccent),
                    onPressed: () async {
                      TextEditingController replyController = TextEditingController();
                      bool isButtonEnabled = false;
                      await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: Colors.white,
                            title: Text('Reply to OpenMessage'),
                            content: SingleChildScrollView(
                              child: TextField(
                                controller: replyController,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter a short reply here',
                                ),
                                maxLines: 5,
                                maxLength: 100,
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: Text('Post Reply'),
                                onPressed: () {
                                  if(replyController.text.trim().isEmpty) return;

                                  final reportData = {
                                    'userId': currentUser?.id,
                                    'message': replyController.text.trim(),
                                    'timestamp': FieldValue.serverTimestamp(),
                                  };

                                  FirebaseFirestore.instance
                                      .collection('confessions')
                                      .doc(docId)
                                      .collection('replies')
                                      .add(reportData)
                                      .then((_) {
                                    Navigator.of(context).pop();
                                  });
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),

              SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('confessions')
                      .doc(docId)
                      .collection('replies')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 200),)),);
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading replies.'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.chat_bubble_outline, size: 50, color: Colors.black54),
                            SizedBox(height: 10),
                            Text("No replies yet", style: TextStyle(color: Colors.black54, fontSize: 14)),
                          ],
                        ),
                      );
                    }

                    return ListView(
                      children: snapshot.data!.docs.map((DocumentSnapshot document) {
                        Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
                        DateTime replyDate = (data['timestamp'] as Timestamp).toDate();
                        String formattedReplyDate = "${replyDate.day} ${DisplayUtils.monthNames[replyDate.month - 1]} ${replyDate.year}, ${replyDate.hour.toString().padLeft(2, '0')}:${replyDate.minute.toString().padLeft(2, '0')}";

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            highlightColor: Colors.blue[200],
                            splashColor: Colors.blue[200],
                            onLongPress: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  TextEditingController detailsController = TextEditingController();
                                  return AlertDialog(
                                    title: Text('Report Reply'),
                                    content: SingleChildScrollView(
                                      child: TextField(
                                        controller: detailsController,
                                        decoration: InputDecoration(
                                          hintText: 'Why do you think this content is violating our policy?',
                                        ),
                                        maxLines: 3,
                                        maxLength: 1000,
                                      ),
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text('Submit Report'),
                                        onPressed: () {
                                          if (detailsController.text.trim().isEmpty) return;

                                          final reportData = {
                                            'reporterId': currentUser?.id,
                                            'parentMessageId': docId,
                                            'reportedReplyId': document.id,
                                            'reportedMessageContent': data['message'],
                                            'details': detailsController.text.trim(),
                                            'timestamp': FieldValue.serverTimestamp(),
                                            'status': 'PENDING_REVIEW',
                                          };

                                          FirebaseFirestore.instance
                                              .collection('userViolationReports')
                                              .doc('openMessages')
                                              .collection('reports')
                                              .add(reportData)
                                              .then((_) {
                                            Navigator.of(context).pop(); // Close the report dialog
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
                            child: Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Card(
                              color: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              margin: EdgeInsets.symmetric(vertical: 5),
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child:
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child:
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(data['message'], style: TextStyle(fontSize: 14), maxLines: 5, overflow: TextOverflow.ellipsis,),
                                          SizedBox(height: 5),
                                          Text(formattedReplyDate, style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    if(document['userId'] == currentUser?.id)
                                      IconButton(
                                        iconSize: 30,
                                        onPressed: () {
                                          // Show confirmation dialog
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                title: Text('Delete this reply?'),
                                                content: Text('Are you sure you want to delete this reply? This action cannot be undone.'),
                                                actions: <Widget>[
                                                  TextButton(
                                                    child: Text('No'),
                                                    onPressed: () {
                                                      Navigator.of(context).pop(); // Close the dialog without doing anything
                                                    },
                                                  ),
                                                  TextButton(
                                                    child: Text('Yes'),
                                                    onPressed: () {
                                                      // Delete the document from Firestore
                                                      FirebaseFirestore.instance
                                                          .collection('confessions')
                                                          .doc(docId)
                                                          .collection('replies')
                                                          .doc(document.id)
                                                          .delete()
                                                          .then((_) {
                                                        Navigator.of(context).pop(); // Close the confirmation dialog
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('Reply deleted successfully.'),
                                                          ),
                                                        );
                                                      })
                                                          .catchError((error) {
                                                        Navigator.of(context).pop(); // Close the confirmation dialog
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('Error deleting reply: $error'),
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
                                        icon: Icon(Icons.delete_forever, color: Colors.red),
                                      )
                                  ],
                                )
                              ),
                            ),
                            )
                          ),
                        );

                      }).toList(),
                    );
                  },
                ),
              ),
              Divider(thickness: 1,),
              SizedBox(height:10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.flag_outlined),
                    label: Text('Report OpenMessage', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () async {
                      TextEditingController detailsController = TextEditingController();
                      bool isButtonEnabled = false;
                      await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Report OpenMessage'),
                            content: SingleChildScrollView(
                              child: TextField(
                                controller: detailsController,
                                decoration: InputDecoration(
                                  hintText: 'Why did you think this content is violating our policy?',
                                ),
                                maxLines: 3,
                                maxLength: 1000,
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: Text('Submit Report'),
                                onPressed: () {
                                  if(detailsController.text.trim().isEmpty) return;

                                  final reportData = {
                                    'reporterId': currentUser?.id,
                                    'reportedOpenMessageId': docId,
                                    'reportedAuthorId': authorId,
                                    'reportedMessageContent': message,
                                    'details': detailsController.text.trim(),
                                    'timestamp': FieldValue.serverTimestamp(),
                                    'status': 'PENDING_REVIEW',
                                  };

                                  FirebaseFirestore.instance
                                      .collection('userViolationReports')
                                      .doc('openMessages')
                                      .collection('reports')
                                      .add(reportData)
                                      .then((_) {
                                    Navigator.of(context).pop(); // Close the report dialog
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
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Close'),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}
