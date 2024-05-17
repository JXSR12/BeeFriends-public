import 'package:BeeFriends/main_page.dart';
import 'package:BeeFriends/profile_page.dart';
import 'package:BeeFriends/utils/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:BeeFriends/main.dart';

class MatchmakingSettingsPage extends StatefulWidget {
  @override
  _MatchmakingSettingsPageState createState() => _MatchmakingSettingsPageState();
}

class _MatchmakingSettingsPageState extends State<MatchmakingSettingsPage> {
  late CompleteUser? currentUser = null;

  bool noHeightPreference = false;

  String? genderRestriction;
  String? religionPreference;
  String? campusPreference;
  String? heightPreference;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newUser = UserProviderState.userOf(context);
    if (newUser != currentUser) {
      setState(() {
        currentUser = newUser;
        _fetchPreferences();
      });
    }
  }

  _fetchPreferences() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('userMatchingSettings')
        .doc(currentUser?.id)
        .get();
    Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

    setState(() {
      genderRestriction = data?.containsKey('genderRestriction') == true ? data!['genderRestriction'] : null;
      religionPreference = data?.containsKey('religionPreference') == true ? data!['religionPreference'] : null;
      campusPreference = data?.containsKey('campusPreference') == true ? data!['campusPreference'] : null;
      heightPreference = data?.containsKey('heightPreference') == true ? data!['heightPreference'] : null;
      noHeightPreference = (heightPreference == 'any' || heightPreference == null);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Matching Preferences')),
      body: ListView(
        children: [
          ListTile(
            leading: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.people_alt_outlined),),
            title: Text(
                "You are currently looking for ${_getLookingForText(currentUser?.lookingFor)}"),
            subtitle: Text("You can change it in your profile here"),
            trailing: Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfilePage(),
                ),
              );
            },
          ),
          ListTile(
            leading: Padding(padding: EdgeInsets.all(10), child: Icon((genderRestriction == 'Male only') ? Icons.male_outlined : (genderRestriction == 'Female only') ? Icons.female_outlined : Icons.question_mark),),
            title: Text("Gender Restriction"),
            subtitle: Text(genderRestriction ?? "No preference set"),
            onTap: _chooseGenderRestriction,
          ),
          ListTile(
            leading: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.balance_outlined),),
            title: Text("Religion Preference"),
            subtitle: Text(religionPreference ?? "No preference set"),
            onTap: _chooseReligionPreference,
          ),
          ListTile(
            leading: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.location_city_outlined),),
            title: Text("Campus Preference"),
            subtitle: Text(campusPreference ?? "No preference set"),
            onTap: _chooseCampusPreference,
          ),
          ListTile(
            leading: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.height_outlined),),
            title: Text("Height Preference"),
            subtitle: Text(heightPreference ?? "No preference set"),
            onTap: _chooseHeightPreference,
          ),
        ],
      ),
    );
  }

  String _getLookingForText(int? value) {
    switch (value) {
      case 0:
        return "friends";
      case 1:
        return "a partner";
      case 2:
        return "both friends and partner";
      default:
        return "";
    }
  }

  void _chooseGenderRestriction() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter dialogSetState) {
            return AlertDialog(
              title: Text("Gender Restriction"),
              content: DropdownButton<String>(
                value: genderRestriction,
                items: ["Male only", "Female only", "Any gender"].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    dialogSetState(() {  // StatefulBuilder's setState is used here
                      genderRestriction = newValue;
                    });
                    _savePreference("genderRestriction", newValue);
                    setState(() {});
                  }
                },
              ),
            );
          },
        );
      },
    );
  }


  void _chooseReligionPreference() async {
    var religions = (await FirebaseFirestore.instance.collection('religionOptions').get()).docs.map((e) => e.id).toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter dialogSetState) {
            return AlertDialog(
              title: Text("Religion Preference"),
              content: DropdownButton<String>(
                value: religionPreference,
                items: ["any", ...religions].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    dialogSetState(() {
                      religionPreference = newValue;
                    });
                    _savePreference("religionPreference", newValue);
                    setState(() {});
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  void _chooseCampusPreference() async {
    var campuses = (await FirebaseFirestore.instance.collection('campusOptions').get()).docs.map((e) => e.id).toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter dialogSetState) {
            return AlertDialog(
              title: Text("Campus Preference"),
              content: DropdownButton<String>(
                value: campusPreference,
                items: ["any", ...campuses].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    dialogSetState(() {
                      campusPreference = newValue;
                    });
                    _savePreference("campusPreference", newValue);
                    setState(() {});
                  }
                },
              ),
            );
          },
        );
      },
    );
  }


  void _chooseHeightPreference() {
    final lowerController = TextEditingController();
    final upperController = TextEditingController();

    // Split the current heightPreference into lower and upper values
    List<String>? currentBounds = heightPreference?.split('-');
    if (currentBounds != null && currentBounds.length == 2) {
      lowerController.text = currentBounds[0];
      upperController.text = currentBounds[1];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter dialogSetState) {
            return AlertDialog(
              title: Text("Height Preference (in cm)"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text("No height preference"),
                    value: noHeightPreference,
                    onChanged: (bool value) {
                      dialogSetState(() {
                        noHeightPreference = value;
                      });
                    },
                  ),
                  TextField(
                    controller: lowerController,
                    decoration: InputDecoration(labelText: 'Lower Bound'),
                    keyboardType: TextInputType.number,
                    enabled: !noHeightPreference,
                  ),
                  TextField(
                    controller: upperController,
                    decoration: InputDecoration(labelText: 'Upper Bound'),
                    keyboardType: TextInputType.number,
                    enabled: !noHeightPreference,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (noHeightPreference) {
                      _savePreference("heightPreference", "any");
                      setState(() {
                        heightPreference = "any";
                      });
                      Navigator.pop(context);
                      return;
                    }

                    int? lower = int.tryParse(lowerController.text.trim());
                    int? upper = int.tryParse(upperController.text.trim());

                    if (lower != null && upper != null &&
                        lower >= 60 && lower <= 300 &&
                        upper >= 60 && upper <= 300 &&
                        lower <= upper) {
                      String newValue = "$lower-$upper";
                      setState(() {
                        heightPreference = newValue;
                      });
                      _savePreference("heightPreference", newValue);
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Please input valid height bounds."))
                      );
                    }
                  },
                  child: Text('Confirm'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }



  void _savePreference(String field, String value) {
    if (currentUser?.id == null) {
      print("Error: Current user is null.");
      return;
    }

    FirebaseFirestore.instance
        .collection('userMatchingSettings')
        .doc(currentUser!.id)
        .set({field: value}, SetOptions(merge: true));
  }

}
