import 'package:BeeFriends/match_requests_page.dart';
import 'package:BeeFriends/profile_page.dart';
import 'package:BeeFriends/utils/common_bottom_app_bar.dart';
import 'package:BeeFriends/utils/display_utils.dart';
import 'package:BeeFriends/utils/notification_manager.dart';
import 'package:BeeFriends/utils/typing_text.dart';
import 'package:BeeFriends/utils/user_provider.dart';
import 'package:animated_gradient/animated_gradient.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_button/flutter_swipe_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:particles_flutter/particles_flutter.dart';
import 'package:BeeFriends/main.dart';
import 'main_page.dart';
import 'matchmaking_settings_page.dart';

class MatchmakePage extends StatefulWidget{
  @override
  MatchmakePageState createState() => MatchmakePageState();
}

class MatchmakePageState extends State<MatchmakePage> with TickerProviderStateMixin {
  late CompleteUser? currentUser = null;

  int? lookingFor;
  String? genderRestriction;
  String? religionPreference;
  String? campusPreference;
  int? heightLowerBound;
  int? heightUpperBound;
  bool isLoading = false;
  String loadingText = "";

  late AnimationController _flyIconAnimationController;
  late Animation<Offset> _flyIconAnimation;
  OverlayEntry? _flyingIconOverlay;
  GlobalKey _buttonKey = GlobalKey();

  late AnimationController _buttonHighlightAnimationController;
  Animation<Color?>? _buttonBackgroundColor;

  late AnimationController _rotationAnimationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _initializeFlyIconAnimation();
    _initializeButtonHighlightAnimation();
  }

  void _initializeFlyIconAnimation() {
    _flyIconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _rotationAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * 3.14,  // Two full rotations
    ).animate(CurvedAnimation(
      parent: _rotationAnimationController,
      curve: Curves.linear,
    ));
    _flyIconAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero, // Will be set dynamically
    ).animate(_flyIconAnimationController)
      ..addListener(() {
        _flyingIconOverlay?.markNeedsBuild();
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _removeFlyingIcon();
          _highlightButton();
        }
      });
  }

  void _initializeButtonHighlightAnimation() {
    _buttonHighlightAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _buttonBackgroundColor = ColorTween(
      begin: Colors.pink.shade400,
      end: Colors.yellow, // Highlight color
    ).animate(_buttonHighlightAnimationController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _buttonHighlightAnimationController.reverse();
        }
      });
  }

  void _startIconFlyAnimation() {
    if (_buttonKey.currentContext == null) {
      return;
    }

    RenderBox buttonRenderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    Offset buttonPosition = buttonRenderBox.localToGlobal(Offset.zero);

    Size screenSize = MediaQuery.of(context).size;
    Offset startingPosition = Offset(screenSize.width / 2, screenSize.height / 2);

    _flyIconAnimationController.reset();
    _rotationAnimationController.reset();

    setState(() {
      _flyIconAnimation = Tween<Offset>(
        begin: startingPosition,
        end: buttonPosition,
      ).animate(_flyIconAnimationController);
    });

    _flyingIconOverlay = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: Listenable.merge([_flyIconAnimationController, _rotationAnimationController]),
          builder: (context, child) {
            return Positioned(
              left: _flyIconAnimation.value.dx,
              top: _flyIconAnimation.value.dy,
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: Icon(Icons.send_rounded, size: 30.0, color: Colors.white,),
              ),
            );
          },
        );
      },
    );
    Overlay.of(context)?.insert(_flyingIconOverlay!);
    _flyIconAnimationController.forward();
    _rotationAnimationController.forward();
  }


  void _removeFlyingIcon() {
    _flyingIconOverlay?.remove();
    _flyingIconOverlay = null;
  }

  void _highlightButton() {
    _removeFlyingIcon();
    _buttonHighlightAnimationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newUser = UserProviderState.userOf(context);
    if (newUser != currentUser) {
      setState(() {
        currentUser = newUser;
        lookingFor = currentUser?.lookingFor;
      });
    }
  }

  @override
  void dispose() {
    _removeFlyingIcon();
    _flyIconAnimationController.dispose();
    _buttonHighlightAnimationController.dispose();
    _rotationAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedGradient(colors: isLoading
            ? [Colors.pink, Colors.pinkAccent]
            : [Theme.of(context).primaryColor, Colors.orange.shade300],child: Stack(
        children: [
          Positioned.fill(
            child: CircularParticle(
              awayRadius: 50,
              numberOfParticles: 500,
              speedOfParticles: isLoading ? 8 : 1,
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              onTapAnimation: true,
              particleColor: Colors.white.withAlpha(10),
              awayAnimationDuration: Duration(milliseconds: 600),
              maxParticleSize: 1,
              isRandSize: false,
              isRandomColor: true,
              randColorList: [
                Colors.white.withAlpha(20),
              ],
              awayAnimationCurve: Curves.easeOutQuint,
              enableHover: true,
              hoverColor: Colors.deepOrange,
              hoverRadius: 60,
              connectDots: true,
            ),
          ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AnimatedBuilder(
                  animation: _buttonHighlightAnimationController,
                  builder: (context, child) {
                    return ElevatedButton.icon(
                      key: _buttonKey,
                      icon: Icon(Icons.send_rounded),
                      label: Text('Requests'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MatchRequestsPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _buttonBackgroundColor?.value ?? Colors.pink.shade400,
                      ),
                    );
                  },
                ),
                SizedBox(width: 10,),
                ElevatedButton.icon(
                  icon: Icon(Icons.settings_applications),
                  label: Text('Preferences'),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchmakingSettingsPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink.shade400),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    !isLoading
                        ? FloatingActionButton.extended(
                      onPressed: _findMatch,
                      icon: Icon(Icons.search),
                      label: Row(
                        children: [
                          Text('Find me a ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          TypingText(colors: [Colors.cyanAccent, Colors.limeAccent, Colors.yellow, Colors.lightGreenAccent, Colors.orangeAccent, Colors.greenAccent], fontSize: 24),
                        ],
                      ),
                      splashColor: Colors.pink,
                      elevation: 10.0,
                      backgroundColor: Colors.pinkAccent,
                    )
                        : Container(),
                    SizedBox(height: 30),
                    isLoading
                        ? Column(
                      children: [
                        SpinKitWaveSpinner(color: Colors.white, size: 70, trackColor: Colors.pink.shade100, waveColor: Colors.pink.shade300),
                        SizedBox(height: 40),
                        Text(loadingText, style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    )
                        : Container(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
        ],
      ),
      );
  }



  Future<void> _findMatch() async {
    _removeFlyingIcon();
    setState(() {
      isLoading = true;
      loadingText = "Please wait..";
    });
    await Future.delayed(Duration(seconds: currentUser?.accountType == "PREMIUM" ? 1 : 3));

    setState(() {
      loadingText = "Connecting to matchmaking service..";
    });
    await Future.delayed(Duration(seconds: 1));

    setState(() {
      loadingText = "Finding you a match..";
    });

    // Call to your cloud function for matchmaking
    var match = await _callMatchmakingFunction();

    if (match == null) {
      setState(() {
        isLoading = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title:  Card(
            color: Colors.black54,
            elevation: 2.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5.0), // Optional: if you want rounded corners
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Adjust padding for spacing
              child: Text(
                'Matching Result',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          content: Text(
              'Sorry, but we cannot find you a suitable match at the moment. Consider changing your preferences or try again another time.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        isLoading = false;
      });
      if (match != null) {
        final candidate = await getCandidateDetails(match);
        final beetsCost = await _calculateBeetsCost();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title:  Card(
              color: Colors.black54,
              elevation: 2.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.0)
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Text(
                  'Matching Result',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text('We have found a potential match for you!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 5),
                  Image.asset('assets/unknown_avatar.png', width: 60, height: 60),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          candidate?['gender'] == 'male' ? Icons.male : Icons.female,
                          color: candidate?['gender'] == 'male' ? Colors.blue : Colors.pink,
                        ),
                        SizedBox(width: 5),
                        Text(candidate?['gender'] == 'male' ? 'Male' : 'Female'),
                      ],
                    ),
                  ),
                  SizedBox(height: 10,),
                  ElevatedButton.icon(
                    icon: Icon(Icons.help_outline),
                    label: Text('Relative Age Information'),
                    onPressed: () {
                      if (currentUser?.birthDate != null && candidate?['birthDate'] != null) {
                        DateTime currentUserBirthDate = DateTime.parse(currentUser?.birthDate ?? '1990-01-01T00:00:00');
                        DateTime candidateBirthDate = DateTime.parse(candidate?['birthDate'] ?? '1990-01-01T00:00:00');

                        int ageDifference = calculateAgeDifference(currentUserBirthDate, candidateBirthDate);
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
                  Text('B${candidate?['studentNumber'].substring(0, 2)}, ${candidate?['major']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.black, fontFamily: GoogleFonts.quicksand().fontFamily),
                      children: [
                        TextSpan(text: 'Campus location: '),
                        TextSpan(text: '${candidate?['campus']}', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.black, fontFamily: GoogleFonts.quicksand().fontFamily),
                      children: [
                        TextSpan(text: 'Religion: '),
                        TextSpan(text: '${candidate?['religion']}', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            text: candidate?['height'] == 'empty' ? 'Prefer not to say' : '${candidate?['height']} cm',
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
                      child: SingleChildScrollView(child: Text('${candidate?['description']}')),
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
                      children: DisplayUtils.displayInterestsForMap(candidate),
                    ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {_acceptCandidate(match);},
                    child: Text('Accept candidate'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  ElevatedButton(
                    onPressed: _rejectCandidate,
                    child: Text('Reject candidate'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Flexible(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black),
                            children: [
                              TextSpan(
                                text: ' If you choose to \'Accept\' this candidate, ',
                              ),
                              WidgetSpan(
                                child: SvgPicture.asset('assets/beets_icon.svg', height: 15, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                              ),
                              TextSpan(
                                text: ' $beetsCost Beets',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: ' will be consumed and will NOT be refunded even if the candidate declines your matching request.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
  }

  static int calculateAgeDifference(DateTime birthDate1, DateTime birthDate2) {
    int yearDiff = birthDate1.year - birthDate2.year;
    int monthDiff = birthDate1.month - birthDate2.month;
    int dayDiff = birthDate1.day - birthDate2.day;

    if (monthDiff < 0 || (monthDiff == 0 && dayDiff < 0)) {
      yearDiff--;
    }

    return yearDiff;
  }

  Future<void> _acceptCandidate(match) async {
    final beetsCost = await _calculateBeetsCost();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SpecialMessageDialog(initialBeetsCost: beetsCost),
    ) ?? {'proceed': false};

    final shouldProceed = result['proceed'] as bool;
    final addedMessage = result['message'] as String;
    final updatedBeetsCost = result['beetsCost'] as int;

    if (shouldProceed) {
      final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser?.id);
      DocumentSnapshot userSnapshot = await userRef.get();
      int? currentBeets = (userSnapshot.get('beets') as num).toInt();

      if (currentBeets == null || currentBeets < updatedBeetsCost) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Insufficient Beets"),
              content: Text("You do not have enough Beets to accept this candidate."),
              actions: [
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
        'beets': FieldValue.increment(-1 * updatedBeetsCost),
      });

      final candidateRef = FirebaseFirestore.instance.collection('users').doc(match);
      final matchingRequestCollection = candidateRef.collection('matchingRequests');

      await matchingRequestCollection.doc(currentUser?.id).set({
        'timestamp': FieldValue.serverTimestamp(),
        'paidMessage': addedMessage,
        'beetsCost': beetsCost,
      });

      final sentRequestsCollection = userRef.collection('sentRequests');
      await sentRequestsCollection.doc(match).set({
        'timestamp': FieldValue.serverTimestamp(),
        'paidMessage': addedMessage,
        'beetsCost': beetsCost,
      });

      NotificationManager.addMatchRequestNotification(currentUser?.id ?? 'UNKNOWN', candidateRef.id, addedMessage);

      Navigator.of(context).pop();
      setState(() {
        isLoading = false;
      });
      _startIconFlyAnimation();
    }
  }

  void _rejectCandidate() {
    Navigator.of(context).pop();
  }

  static Future<Map<String, dynamic>?> getCandidateDetails(String userId) async {
    final document = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return document.data();
  }

  Future<dynamic> _callMatchmakingFunction() async {
    final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2').httpsCallable('matchmake');

    final HttpsCallableResult response = await callable.call(<String, dynamic>{
      'userId': currentUser?.id,
    });

    print(response.data);

    return response.data;
  }

  Future<int> _calculateBeetsCost() async {
    double cost = 1.0;

    final userMatchingSettings = await FirebaseFirestore.instance.collection('userMatchingSettings').doc(currentUser?.id).get().then((doc) => doc.data()) ?? {};

    if (userMatchingSettings['heightPreference'] != null && userMatchingSettings['heightPreference'].isNotEmpty && userMatchingSettings['heightPreference'] != 'any') {
      cost += 1.0;
    }
    if (userMatchingSettings['religionPreference'] != null && userMatchingSettings['religionPreference'] != 'any') {
      cost += 0.5;
    }
    if (userMatchingSettings['campusPreference'] != null && userMatchingSettings['campusPreference'] != 'any') {
      cost += 0.5;
    }
    if (userMatchingSettings['genderRestriction'] != null && userMatchingSettings['genderRestriction'] != 'Any gender') {
      cost += 1.0;
    }

    return cost.floor();
  }
}

class SpecialMessageDialog extends StatefulWidget {
  final int initialBeetsCost;
  final bool isStarbee;

  const SpecialMessageDialog({Key? key, required this.initialBeetsCost, this.isStarbee = false}) : super(key: key);

  @override
  _SpecialMessageDialogState createState() => _SpecialMessageDialogState();
}

class _SpecialMessageDialogState extends State<SpecialMessageDialog> {
  bool _addSpecialMessage = false;
  TextEditingController _messageController = TextEditingController();
  int _beetsCost = 0;

  @override
  void initState() {
    super.initState();
    _beetsCost = widget.initialBeetsCost;
    _messageController.addListener(() {
      setState(() {
        _beetsCost = widget.initialBeetsCost + (_addSpecialMessage && _messageController.text.isNotEmpty ? 1 : 0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    String relativeNoun = widget.isStarbee ? 'Starbee' : 'candidate';
    return AlertDialog(
      title: Text('Confirmation'),
      content: SingleChildScrollView(
        child: ListBody(
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: Colors.black),
                children: [
                  TextSpan(
                    text: 'By pressing the \'Confirm\' button below, you will spend ',
                  ),
                  WidgetSpan(
                    child: SvgPicture.asset('assets/beets_icon.svg', height: 15, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
                  ),
                  TextSpan(
                    text: ' $_beetsCost Beets',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: ', and a matching request will be sent to this $relativeNoun.',
                  ),
                ],
              ),
            ),
            SwitchListTile(
              title: Text('Add special message (+1 Beet)'),
              value: _addSpecialMessage,
              onChanged: (bool value) {
                setState(() {
                  _addSpecialMessage = value;
                  _beetsCost = widget.initialBeetsCost + (_addSpecialMessage && _messageController.text.isNotEmpty ? 1 : 0);
                });
              },
            ),
            if (_addSpecialMessage)
              TextField(
                controller: _messageController,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'Enter your special message',
                ),
              ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop({'proceed': true, 'message': _addSpecialMessage && _messageController.text.isNotEmpty ? _messageController.text : '', 'beetsCost': _beetsCost}),
          child: Text('Confirm'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop({'proceed': false}),
          child: Text('Cancel'),
        ),
      ],
    );
  }
}

