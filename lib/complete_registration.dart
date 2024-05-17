// complete_registration.dart
import 'package:BeeFriends/main_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompleteRegistration extends StatefulWidget {
  final String id;
  final String email;
  final String number;
  final String major;
  final String birthDate;
  final String name;
  final String defaultPicture;

  CompleteRegistration({
    required this.id,
    required this.email,
    required this.number,
    required this.major,
    required this.birthDate,
    required this.name,
    required this.defaultPicture,
  });

  @override
  _CompleteRegistrationState createState() => _CompleteRegistrationState();
}

class _CompleteRegistrationState extends State<CompleteRegistration> {
  int phase = 1;
  String? selectedGender;
  int? lookingFor;
  List<String> interests = [];
  TextEditingController descriptionController = TextEditingController();
  TextEditingController heightController = TextEditingController();
  int? selectedDay;
  int? selectedMonth;
  int? selectedYear;
  DateTime? selectedDate;
  bool isDescriptionFilled = false;
  final firestore = FirebaseFirestore.instance;
  List<String> allInterests = [];
  List<String> campuses = [];
  List<String> religions = [];
  String? selectedReligion;
  int? selectedHeight;
  bool isHeightProvided = true;
  String? selectedCampus;
  ScrollController _scrollController = ScrollController();
  bool _hasScrolled = false;

  late List<String> filteredInterests;

  TextEditingController searchTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    selectedDay = now.day;
    selectedMonth = now.month;
    selectedYear = now.year;

    _scrollController.addListener(_onScroll);

    descriptionController.addListener(() {
      setState(() {
        isDescriptionFilled = descriptionController.text.trim().isNotEmpty;
      });
    });

    heightController.addListener(() {
      setState(() {
        selectedHeight = int.tryParse(heightController.text);
      });
    });

    _fetchOptions();
  }

  void _onScroll() {
    if (_scrollController.offset > 0 && !_hasScrolled) {
      setState(() {
        _hasScrolled = true;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case 1:
        return _buildPhase1();
      case 2:
        return _buildPhase2();
      case 3:
        return _buildPhaseReligion();
      case 4:
        return _buildPhaseHeight();
      case 5:
        return _buildPhase3();
      case 6:
        return _buildPhase4();
      case 7:
        return _buildPhase5();
      case 8:
        return _buildPhaseCampus();
      case 9:
        return _buildPhase6();

      default:
        return SizedBox.shrink();
    }
  }

  Future<void> _fetchOptions() async {
    try {
      final querySnapshot = await firestore.collection('interestOptions').get();
      final fetchedInterests = querySnapshot.docs.map((doc) => doc.id).toList();
      final querySnapshot2 = await firestore.collection('campusOptions').get();
      final fetchedCampuses = querySnapshot2.docs.map((doc) => doc.id).toList();
      final querySnapshot3 = await firestore.collection('religionOptions').get();
      final fetchedReligions = querySnapshot3.docs.map((doc) => doc.id).toList();
      setState(() {
        allInterests = fetchedInterests;
        filteredInterests = allInterests;
        religions = fetchedReligions;
        campuses = fetchedCampuses;
      });
    } catch (e) {
      // Handle the error accordingly, maybe show a snackbar
      print("Error fetching interests: $e");
    }
  }


  int _calculateAge(DateTime birthDate) {
    DateTime currentDate = DateTime.now();
    int age = currentDate.year - birthDate.year;
    int month1 = currentDate.month;
    int month2 = birthDate.month;

    if (month2 > month1) {
      age--;
    } else if (month1 == month2) {
      int day1 = currentDate.day;
      int day2 = birthDate.day;
      if (day2 > day1) {
        age--;
      }
    }
    return age;
  }

  Widget _buildPhase1() {
    return Scaffold(
      appBar: AppBar(title: Text('Complete your profile')),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Verify your birthdate', textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  SizedBox(height: 20.0),
                  SizedBox(
                    height: 150.0,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: selectedDate ?? DateTime.now(),
                      onDateTimeChanged: (DateTime newDate) {
                        setState(() {
                          selectedDate = newDate;
                          selectedDay = newDate.day;
                          selectedMonth = newDate.month;
                          selectedYear = newDate.year;
                        });
                      },
                      maximumYear: DateTime.now().year,
                      minimumYear: 1900,
                    ),
                  ),
                  SizedBox(height: 20.0),
                  Text(
                    selectedDate == null
                        ? "Select a date"
                        : "${_calculateAge(selectedDate!)} year(s) old",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  )
                ],
              ),
            ),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: selectedDate != null
                    ? () {
                  String formattedSelectedDate =
                      "${selectedYear!}-${selectedMonth!.toString().padLeft(2, '0')}-${selectedDay!.toString().padLeft(2, '0')}";
                  if (formattedSelectedDate ==
                      widget.birthDate.split("T")[0]) {
                    setState(() {
                      phase = 2;
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sorry, but we are unable to verify your birthdate.')));
                  }
                }
                    : null,
                child: Text('Continue'),
              ),
            ),
            SizedBox(height: 10.0),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColorDark,
                ),
                onPressed: null,
                child: Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }



  // Phase 2: Gender Selection
  Widget _buildPhase2() {
    return Scaffold(
      appBar: AppBar(title: Text('Complete your profile')),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('Please select your gender', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          style: selectedGender == 'male'
                              ? ElevatedButton.styleFrom(backgroundColor: Colors.orange)
                              : null,
                          onPressed: () {
                            setState(() {
                              selectedGender = 'male';
                            });
                          },
                          child: Text('Male', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                      SizedBox(width: 20.0),
                      Expanded(
                        child: ElevatedButton(
                          style: selectedGender == 'female'
                              ? ElevatedButton.styleFrom(backgroundColor: Colors.orange)
                              : null,
                          onPressed: () {
                            setState(() {
                              selectedGender = 'female';
                            });
                          },
                          child: Text('Female', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: selectedGender != null
                    ? () {
                  setState(() {
                    phase = 3;
                  });
                }
                    : null,
                child: Text('Continue'),
              ),
            ),
            SizedBox(height: 10.0),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColorDark,
                ),
                onPressed: () {
                  setState(() {
                    phase = 1;
                  });
                },
                child: Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Phase 3: Looking For Selection
  Widget _buildPhase3() {
    return Scaffold(
      appBar: AppBar(title: Text('Complete your profile')),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('What are you mainly looking for?', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10.0),
                  Wrap(
                    runSpacing: 16.0,
                    spacing: 16.0,
                    children: <Widget>[
                      ElevatedButton(
                          style: lookingFor == 0
                              ? ElevatedButton.styleFrom(backgroundColor: Colors.orange)
                              : null,
                          onPressed: () {
                            setState(() {
                              lookingFor = 0;
                            });
                          },
                          child: Text('Friends', style: TextStyle(fontSize: 20)),
                        ),
                      ElevatedButton(
                          style: lookingFor == 1
                              ? ElevatedButton.styleFrom(backgroundColor: Colors.orange)
                              : null,
                          onPressed: () {
                            setState(() {
                              lookingFor = 1;
                            });
                          },
                          child: Text('A partner', style: TextStyle(fontSize: 20)),
                      ),
                      ElevatedButton(
                          style: lookingFor == 2
                              ? ElevatedButton.styleFrom(backgroundColor: Colors.orange)
                              : null,
                          onPressed: () {
                            setState(() {
                              lookingFor = 2;
                            });
                          },
                          child: Text('Both', style: TextStyle(fontSize: 20)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: lookingFor != null
                    ? () {
                  setState(() {
                    filteredInterests = allInterests
                        .where((interest) =>
                        interest.toLowerCase().contains(searchTextController.text.trim().toLowerCase()))
                        .toList();
                    phase = 6;
                  });
                }
                    : null,
                child: Text('Continue'),
              ),
            ),
            SizedBox(height: 10.0),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColorDark,
                ),
                onPressed: () {
                  setState(() {
                    phase = 4;
                  });
                },
                child: Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhase4() {
    return Scaffold(
      appBar: AppBar(title: Text('Complete your profile')),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('What are your interests?', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10.0),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Search an interest...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    controller: searchTextController,
                    onChanged: (searchText) {
                      setState(() {
                        // Filter the allInterests list based on the search text
                        filteredInterests = allInterests
                            .where((interest) =>
                            interest.toLowerCase().contains(searchText.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                  SizedBox(height: 10.0),
                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          controller: _scrollController,
                          child: Wrap(
                            spacing: 10.0,
                            runSpacing: 10.0,
                            children: filteredInterests.map((interest) {
                              bool isSelected = interests.contains(interest);
                              bool isDisabled = !isSelected && interests.length >= 9;

                              return FilterChip(
                                label: Text(
                                  interest,
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.quicksand().fontFamily,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDisabled ? Colors.grey : Colors.white,
                                  ),
                                ),
                                selected: isSelected,
                                backgroundColor: isDisabled ? Colors.grey[400] : Theme.of(context).cardColor,
                                selectedColor: Colors.orange,
                                checkmarkColor: Colors.white,
                                onSelected: (selected) {
                                  if (!isDisabled) {
                                    setState(() {
                                      if (selected) {
                                        interests.add(interest);
                                      } else {
                                        interests.remove(interest);
                                      }
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          bottom: _hasScrolled ? -50 : 0,
                          left: 0,
                          right: 0,
                          child: Chip(label: Text('Scroll down for more options', style: TextStyle(fontWeight: FontWeight.bold),)),
                        ),
                      ],
                    )
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: interests.isNotEmpty
                    ? () {
                  setState(() {
                    phase = 7;
                  });
                }
                    : null,
                child: Text('Continue'),
              ),
            ),
            SizedBox(height: 10.0),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColorDark,
                ),
                onPressed: () {
                  setState(() {
                    phase = 5;
                  });
                },
                child: Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Phase 6: Firebase Firestore Registration
  Widget _buildPhase6() {
    _registerUser();  // This initiates the Firebase Firestore registration

    return Scaffold(
      appBar: AppBar(title: Text('Complete your profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(height: 100, child: SpinKitWave(color: Colors.blue, duration: Duration(milliseconds: 400))),
            SizedBox(height: 20.0),
            Text('Registering your data to the system..'),
          ],
        ),
      ),
    );
  }

  Widget _buildPhase5() {
    return Scaffold(
      appBar: AppBar(title: Text('Complete your profile')),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('Tell us about yourself', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10.0),
                  TextField(
                    controller: descriptionController,
                    maxLines: 8,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: 'Specify a short but concise details about yourself that you would like people to know',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isDescriptionFilled
                    ? () {
                  setState(() {
                    phase = 8;
                  });
                }
                    : null,
                child: Text('Continue'),
              ),
            ),
            SizedBox(height: 10.0),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColorDark,
                ),
                onPressed: () {
                  setState(() {
                    filteredInterests = allInterests
                        .where((interest) =>
                        interest.toLowerCase().contains(searchTextController.text.trim().toLowerCase()))
                        .toList();
                    phase = 6;
                  });
                },
                child: Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseReligion() {
    return Scaffold(
      appBar: AppBar(title: Text('Complete your profile')),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('Please select your religion', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10.0),
                  Wrap(
                    alignment: WrapAlignment.spaceAround,
                    spacing: 10,
                    children: religions.map((religion) => ElevatedButton(
                      style: selectedReligion == religion
                          ? ElevatedButton.styleFrom(backgroundColor: Colors.orange)
                          : null,
                      onPressed: () {
                        print('Rel: $religion');
                        setState(() {
                          selectedReligion = religion;
                        });
                      },
                      child: Text(religion, style: TextStyle(fontSize: 20)),
                    )).toList(),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: selectedReligion != null
                    ? () {
                  setState(() {
                    filteredInterests = allInterests
                        .where((interest) =>
                        interest.toLowerCase().contains(searchTextController.text.trim().toLowerCase()))
                        .toList();
                    phase = 4;
                  });
                }
                    : null,
                child: Text('Continue'),
              ),
            ),
            SizedBox(height: 10.0),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColorDark,
                ),
                onPressed: () {
                  setState(() {
                    phase = 2;
                  });
                },
                child: Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseCampus() {
    return Scaffold(
      appBar: AppBar(title: Text('Complete your profile')),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('Please select your campus area', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10.0),
                  Wrap(
                    alignment: WrapAlignment.spaceAround,
                    spacing: 10,
                    children: campuses.map((campus) => ElevatedButton(
                      style: selectedCampus == campus
                          ? ElevatedButton.styleFrom(backgroundColor: Colors.orange)
                          : null,
                      onPressed: () {
                        setState(() {
                          selectedCampus = campus;
                        });
                      },
                      child: Text(campus, style: TextStyle(fontSize: 20)),
                    )).toList(),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: selectedCampus != null
                    ? () {
                  setState(() {
                    phase = 9;
                  });
                }
                    : null,
                child: Text('Complete my profile'),
              ),
            ),
            SizedBox(height: 10.0),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColorDark,
                ),
                onPressed: () {
                  setState(() {
                    phase = 7;
                  });
                },
                child: Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPhaseHeight() {
    return Scaffold(
      appBar: AppBar(title: Text('Complete your profile')),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('Input your height in cm', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10.0),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: heightController,
                          enabled: isHeightProvided,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Height in cm',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Switch(
                        value: !isHeightProvided,
                        onChanged: (bool value) {
                          setState(() {
                            selectedHeight = int.tryParse(heightController.text);
                            isHeightProvided = !value;
                            if (value) {
                              selectedHeight = null; // Clear height value if user prefers not to provide it
                            }
                          });
                        },
                      ),
                      Text('Prefer not to say')
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (isHeightProvided && (selectedHeight != null && selectedHeight! >= 60 && selectedHeight! <= 300)) || !isHeightProvided
                    ? () {
                  setState(() {
                    phase = 5;
                  });
                }
                    : null,
                child: Text('Continue'),
              ),
            ),
            SizedBox(height: 10.0),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColorDark,
                ),
                onPressed: () {
                  setState(() {
                    phase = 2;
                  });
                },
                child: Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerUser() async {
    final firestore = FirebaseFirestore.instance;
    try {
      await firestore.collection('users').doc(widget.id).set({
        'id': widget.id,
        'name': widget.name,
        'email': widget.email,
        'studentNumber': widget.number,
        'major': widget.major,
        'birthDate': widget.birthDate,
        'gender': selectedGender,
        'lookingFor': lookingFor,
        'interests': interests.join(','),
        'description': descriptionController.text,
        'religion': selectedReligion,
        'height': isHeightProvided ? selectedHeight?.toString() ?? 'empty' : 'empty',
        'campus': selectedCampus,
        'pictures': {
          'default': widget.defaultPicture,
          'others': []
        },
        'beets': (20).toInt(),
        'accountType': 'REGULAR'
      });

      await firestore.collection('userMatchingSettings').doc(widget.id).set({
        'religionPreference': selectedReligion,
        'campusPreference': selectedCampus,
        'genderRestriction': 'Any gender',
        'heightPreference': 'any'
      });

      await _showSuccessDialog();
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => MainPage()), (Route<dynamic> route) => false);
    } catch (e) {
      _showErrorDialog();
    }
  }


  Future<void> _showSuccessDialog() async {
    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Welcome Aboard!'),
          content: Text(
              'You have been registered successfully! \n\nPress the button below to begin your journey in BeeFriends.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => MainPage()), (Route<dynamic> route) => false);
              },
              child: Text('Proceed'),
            )
          ],
        );
      },
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(
              'Sorry, but we have trouble registering your data. Press the button below to retry your registration.'),
          actions: [
            TextButton(
              onPressed: _registerUser,  // This is a recursive call.
              child: Text('Retry'),
            )
          ],
        );
      },
    );
  }
}


