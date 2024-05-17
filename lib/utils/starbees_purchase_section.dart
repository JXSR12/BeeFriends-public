import 'dart:math';

import 'package:BeeFriends/utils/user_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_button/flutter_swipe_button.dart';
import 'package:intl/intl.dart';

import '../main.dart';

class StarbeePurchaseSection extends StatefulWidget {
  final CompleteUser currentUser;

  StarbeePurchaseSection({Key? key, required this.currentUser}) : super(key: key);

  @override
  _StarbeePurchaseSectionState createState() => _StarbeePurchaseSectionState(currentUser);
}

class _StarbeePurchaseSectionState extends State<StarbeePurchaseSection> {
  final CompleteUser currentUser;
  int _currentStep = 0;
  bool _isPrefaceState = true;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  int? _beetsCost;
  bool _isDateChosen = false;
  bool _isTimeSlotChosen = false;
  bool _isPurchaseCompleted = false;
  int _userBeets = 0;
  String _promotionMessage = 'Come and connect with me!';
  double _requestCost = 1;

  _StarbeePurchaseSectionState(this.currentUser);

  final _promotionMessageController = TextEditingController();
  final _promotionMessageFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _promotionMessageController.addListener(_onPromotionMessageChanged);
  }

  @override
  void dispose() {
    _promotionMessageController.dispose();
    super.dispose();
  }

  void _onPromotionMessageChanged() {
    if (_promotionMessageController.text != _promotionMessage) {
      setState(() {
        _promotionMessage = _promotionMessageController.text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _userBeets = currentUser.beets!;

    if (_isPrefaceState) {
      return _buildPrefaceState();
    }

    return Theme(
      data: ThemeData(
        primarySwatch: Colors.green,
        colorScheme: ColorScheme.light(
          primary: Colors.green,
          onPrimary: Colors.white,
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: Colors.green,
          textTheme: ButtonTextTheme.primary,
        ),
      ),
      child: Stepper(
        physics: NeverScrollableScrollPhysics(),
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: _currentStep < 4 ? () => setState(() => _currentStep++) : null,
        onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep--) : () => setState(() {
          _isPrefaceState = true;
        }),
        controlsBuilder: (BuildContext context, ControlsDetails details) {
          return Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Row(
            children: <Widget>[
              ElevatedButton(
                onPressed: details.onStepContinue,
                child: Text('CONTINUE', style: TextStyle(color: Colors.white)),
                style: TextButton.styleFrom(backgroundColor: Colors.green),
              ),
              TextButton(
                onPressed: details.onStepCancel,
                child: Text('BACK', style: TextStyle(color: Colors.grey.shade300)),
              ),
            ],
          ));
        },
        steps: [
          Step(
            title: Text('Select a Date', style: TextStyle(color: Colors.white),),
            content: _buildDateSelection(),
            isActive: _currentStep >= 0,
            state: _isDateChosen ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text('Select a Time Slot', style: TextStyle(color: Colors.white),),
            content: _buildTimeSlotSelection(),
            isActive: _currentStep >= 1,
            state: _isTimeSlotChosen ? StepState.complete : StepState.indexed,
          ),
          _buildPromotionMessageStep(),
          _buildRequestCostStep(),
          Step(
            title: Text('Confirm Purchase', style: TextStyle(color: Colors.white),),
            content: _buildPurchaseConfirmation(),
            isActive: _currentStep >= 2,
            state: _isPurchaseCompleted ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
    );

  }

  Widget _buildPrefaceState() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isPrefaceState = false;
              });
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart, size: 48, color: Colors.white),
                SizedBox(height: 10),
                Text('Purchase a slot', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ),
        VerticalDivider(color: Colors.grey, width: 1, thickness: 1),
        Expanded(
          child: GestureDetector(
            onTap: _viewActiveBooking,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility, size: 48, color: Colors.white),
                SizedBox(height: 10),
                Text('View active booking', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }



  void _viewActiveBooking() async {
    var activeBooking = await FirebaseFirestore.instance
        .collection('starbeesPool')
        .doc(currentUser.id)
        .get();

    if (!activeBooking.exists) {
      _showBookingInfo('No active bookings found', null, null, null, null, null, null);
      return;
    }

    var bookingData = activeBooking.data();
    var bookingDate = (bookingData?['date'] as Timestamp).toDate();

    var views = bookingData?['views'] as num?;
    var clicks = bookingData?['clicks'] as num?;
    var requests = bookingData?['requests'] as num?;

    views = views?.toInt();
    clicks = clicks?.toInt();
    requests = requests?.toInt();

    var timeSlotId = bookingData?['timeSlotId'];
    int numericSlotId = int.parse(timeSlotId);
    int addedHours = (numericSlotId - 1) * 3;

    var status = _determineBookingStatus(bookingDate.add(Duration(hours: addedHours)));

    // Fetch time slot details
    var timeSlot = await FirebaseFirestore.instance
        .collection('starbeesTimeOptions')
        .doc(timeSlotId)
        .get();
    var timeSlotData = timeSlot.data();
    String formattedStartTime = DateFormat('HH:mm').format(DateTime(2000, 1, 1, timeSlotData?['startHour']));
    String formattedEndTime = DateFormat('HH:mm').format(DateTime(2000, 1, 1, timeSlotData?['endHour']));
    var timeRange = '${formattedStartTime} - ${formattedEndTime}';

    _showBookingInfo(timeRange, bookingDate, status, timeSlotId, views, clicks, requests);
  }

  void _showBookingInfo(String? timeRange, DateTime? date, String? status, String? timeSlotId, num? views, num? clicks, num? requests) {

    showDialog(
      context: context,
      builder: (BuildContext context) {
        Color statusColor;
        switch (status) {
          case 'Queued':
            statusColor = Colors.orange;
            break;
          case 'Active':
            statusColor = Colors.green;
            break;
          case 'Done':
            statusColor = Colors.grey;
            break;
          default:
            statusColor = Colors.blue;
        }

        return AlertDialog(
          title: Text('My Latest Booking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('${date != null ? DateFormat('MMMM dd, yyyy').format(date) : 'N/A'}'),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('$timeRange'),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, color: statusColor),
                  SizedBox(width: 8),
                  Chip(
                    label: Text(status ?? 'N/A'),
                    backgroundColor: statusColor.withAlpha(50),
                  ),
                ],
              ),
              Divider(),
              SizedBox(height: 10,),
              Text('Insights', style: TextStyle(fontWeight: FontWeight.bold),),
              SizedBox(height: 10,),
              Row(
                children: [
                  Icon(Icons.visibility_rounded, color: Colors.black54),
                  SizedBox(width: 8),
                  Chip(
                    label: Text(views != null ? views.toString() : '-'),
                    backgroundColor: Colors.blue[50],
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.ads_click_rounded, color: Colors.black54),
                  SizedBox(width: 8),
                  Chip(
                    label: Text(clicks != null ? clicks.toString() : '-'),
                    backgroundColor: Colors.blue[50],
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.send_rounded, color: Colors.black54),
                  SizedBox(width: 8),
                  Chip(
                    label: Text(requests != null ? requests.toString() : '-'),
                    backgroundColor: Colors.blue[50],
                  ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.blue)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }


  String _determineBookingStatus(DateTime bookingDate) {
    DateTime now = DateTime.now();
    if (now.isBefore(bookingDate)) return 'Queued';
    if (now.isAfter(bookingDate.add(Duration(hours: 3)))) return 'Done';
    return 'Active';
  }

  Widget _buildDateSelection() {
    return Container(
      decoration: BoxDecoration(
        color: _isDateChosen ? Colors.green[50] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _isDateChosen ? Colors.green : Colors.grey),
      ),
      child: ListTile(
        leading: Icon(Icons.calendar_today, color: _isDateChosen ? Colors.green : Colors.grey),
        title: Text(_selectedDate == null ? 'Choose a Date' : '${DateFormat('MMMM dd, yyyy').format(_selectedDate!)}'),
        subtitle: _isDateChosen ? Text('Tap to change the date') : null,
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now().add(Duration(days: 1)),
            firstDate: DateTime.now(),
            lastDate: DateTime(2101),
          );
          if (picked != null && picked != _selectedDate) {
            setState(() {
              _selectedDate = picked;
              _selectedTimeSlot = null;
              _isTimeSlotChosen = false;
              _isDateChosen = true;
            });
          }
        },
      ),
    );
  }

  Widget _buildTimeSlotSelection() {
    if (!_isDateChosen) {
      return Text('Please select a date first.', style: TextStyle(color: Colors.white),);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('globalPlatformState').doc('activeStarbeeTimeSlot').get(),
      builder: (context, activeSlotSnapshot) {
        if (!activeSlotSnapshot.hasData) {
          return SpinKitWave(color: Colors.white60, size: 30.0);
        }

        String activeTimeSlotId = activeSlotSnapshot.data!.get('id');

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('starbeesTimeOptions').get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SpinKitWave(color: Colors.white60, size: 30.0);
            }

            if (snapshot.hasError) {
              return Text("Error loading time slots", style: TextStyle(color: Colors.white),);
            }

            if (!snapshot.hasData) {
              return Text("No time slots available", style: TextStyle(color: Colors.white),);
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                DocumentSnapshot document = snapshot.data!.docs[index];
                Map<String, dynamic> data = document.data() as Map<String, dynamic>;
                String formattedStartTime = DateFormat('HH:mm').format(DateTime(2000, 1, 1, data['startHour']));
                String formattedEndTime = DateFormat('HH:mm').format(DateTime(2000, 1, 1, data['endHour']));
                String timeRange = '$formattedStartTime - $formattedEndTime';

                return FutureBuilder<int>(
                  future: _checkTimeSlotAvailability(_selectedDate!, document.id),
                  builder: (context, availabilitySnapshot) {
                    bool isAvailable = availabilitySnapshot.data != 0;
                    int slotsLeft = availabilitySnapshot.data ?? 0;
                    bool isSelected = _selectedTimeSlot == document.id;

                    bool isDisabled = _shouldDisableSlot(_selectedDate!, document.id, activeTimeSlotId);

                    return Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Opacity(
                      opacity: isDisabled ? 0.5 : 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.green[50] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? Colors.green : Colors.grey),
                        ),
                        child: ListTile(
                          leading: Icon(isSelected ? Icons.check_circle : Icons.access_time, color: isSelected ? Colors.green : Colors.grey, size: 32,),
                          title: Text(timeRange),
                          subtitle: isAvailable && !isDisabled ? Text('$slotsLeft slots left') : Text('Fully booked or expired'),
                          trailing: isAvailable && !isDisabled ? Icon(Icons.event_available, color: Colors.lightGreen, size: 28,) : Icon(Icons.lock, color: Colors.red, size: 28,),
                          onTap: isAvailable && !isDisabled ? () {
                            setState(() {
                              _selectedTimeSlot = document.id;
                              _beetsCost = (data['beetsCost'] as num).toInt();
                              _isTimeSlotChosen = true;
                            });
                          } : null,
                        ),
                      ),
                    ));
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  bool _shouldDisableSlot(DateTime selectedDate, String timeSlotId, String activeTimeSlotId) {
    DateTime now = DateTime.now();
    if (selectedDate.day < now.day && selectedDate.month <= now.month && selectedDate.year <= now.year || (selectedDate.day == now.day && selectedDate.month == now.month && selectedDate.year == now.year && int.parse(timeSlotId) <= int.parse(activeTimeSlotId))) {
      return true;
    }
    return false;
  }


  Step _buildPromotionMessageStep() {
    return Step(
      title: Text('Write a Promotion Message', style: TextStyle(color: Colors.white),),
      content: Padding(
        padding: EdgeInsets.all(8.0),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return TextFormField(
              controller: _promotionMessageController,
              maxLength: 60,
              style: TextStyle(color: Colors.white), // Text color
              decoration: InputDecoration(
                labelText: 'Write something interesting..',
                labelStyle: TextStyle(color: Colors.white), // Label color
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white), // Border color
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white), // Enabled border color
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white), // Focused border color
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _promotionMessage = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a promotion message';
                }
                return null;
              },
            );
          },
        ),
      ),
      isActive: _currentStep >= 3,
      state: _promotionMessage.isNotEmpty ? StepState.complete : StepState.indexed,
    );
  }


  Step _buildRequestCostStep() {
    return Step(
      title: Text('Set Request Cost', style: TextStyle(color: Colors.white),),
      content: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.green,
                inactiveTrackColor: Colors.red,
                thumbColor: Colors.white,
                overlayColor: Colors.green.withAlpha(32),
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 15.0),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 28.0),
              ),
              child: Slider(
                label: '${_requestCost.toInt()} Beets',
                value: _requestCost,
                min: 1,
                max: 4,
                divisions: 3,
                onChanged: (value) {
                  setState(() {
                    _requestCost = value;
                  });
                },
              ),
            ),
            Text(
              'This will be how much Beets other users will have to pay in order to send you a request via Starbee. The lower you set this, the higher you must pay to accept their request.',
              style: TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        ),
      ),
      isActive: _currentStep >= 4,
      state: _requestCost > 0 ? StepState.complete : StepState.indexed,
    );
  }


  Widget _buildPurchaseConfirmation() {
    if (!_isTimeSlotChosen) {
      return Text('Please select a time slot first.', style: TextStyle(color: Colors.white),);
    }
    if (_requestCost < 1 || _requestCost > 4) {
      return Text('Please select the request cost first.', style: TextStyle(color: Colors.white),);
    }
    if (_promotionMessage.trim().isEmpty) {
      return Text('Please enter a promotion message first.', style: TextStyle(color: Colors.white),);
    }
    if (!_isDateChosen) {
      return Text('Please select a date first.', style: TextStyle(color: Colors.white),);
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Starbee Purchase Cost: ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              SvgPicture.asset('assets/beets_icon.svg', height: 20, colorFilter: ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
              SizedBox(width: 10),
              Text(
                '$_beetsCost',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            'By purchasing this, if there is any active or queued booking, it will be OVERRIDEN and will not be refunded.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.green[800],
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: SwipeButton.expand(
              thumb: Icon(Icons.payment_rounded, color: Colors.white),
              child: Text(
                "Swipe to pay",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              activeThumbColor: Colors.green,
              activeTrackColor: Colors.black54,
              onSwipe: () async {
                _handlePurchase();
              },
            ),
          ),
        ],
      ),
    );
  }



  Future<int> _checkTimeSlotAvailability(DateTime date, String timeSlotId) async {
    final MAX_ALLOWED_PROFILES = 3;

    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    Timestamp startTimestamp = Timestamp.fromDate(startOfDay);
    Timestamp endTimestamp = Timestamp.fromDate(endOfDay);

    var result = await FirebaseFirestore.instance
        .collection('starbeesPool')
        .where('date', isGreaterThanOrEqualTo: startTimestamp)
        .where('date', isLessThanOrEqualTo: endTimestamp)
        .where('timeSlotId', isEqualTo: timeSlotId)
        .get();

    return max(MAX_ALLOWED_PROFILES - result.docs.length, 0);
  }

  void _handlePurchase() async {
    _userBeets = currentUser.beets!;
    if (_userBeets < _beetsCost!) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Insufficient Beets'),
            content: Text('You do not have enough beets to complete the purchase.'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    FirebaseFirestore.instance.collection('users').doc(currentUser.id)
        .update({'beets': FieldValue.increment(-_beetsCost!)});

    FirebaseFirestore.instance.collection('starbeesPool').doc(currentUser.id).set({
      'timeSlotId': _selectedTimeSlot,
      'date': Timestamp.fromDate(_selectedDate!),
      'requestCost': _requestCost,
      'promotionMessage': _promotionMessage,
      'gender': currentUser.gender!.substring(0, 1).toUpperCase() + currentUser.gender!.substring(1),
      'major': currentUser.major,
      'fgy': 'B${currentUser.studentNumber!.substring(0, 2)}',
    }, SetOptions(merge: false));

    setState(() {
      _isPurchaseCompleted = true;
      _userBeets -= _beetsCost!;
      _currentStep = 0;
      _isDateChosen = false;
      _isTimeSlotChosen = false;
      _selectedDate = null;
      _selectedTimeSlot = null;
      _promotionMessage = '';
      _promotionMessageController.clear();
      _requestCost = 1;
      _beetsCost = 0;
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Purchase Successful'),
          content: Text('Your Starbee slot has been booked. Check "View My Active Booking" to verify.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _isPrefaceState = true); // Reset to initial state
              },
            ),
          ],
        );
      },
    );

    setState(() => _isPrefaceState = true);
  }
}
