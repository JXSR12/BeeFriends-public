import 'package:BeeFriends/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ConsentScreen extends StatefulWidget {
  @override
  _ConsentScreenState createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _consentGiven = false;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('Student Data Retrieval Consent'),
      ),
      body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In order to use and register for BeeFriends, we need to retrieve the following student data of yours:',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: Icon(Icons.perm_identity, color: Theme.of(context).cardColor),
                          title: Text('Student ID', style: TextStyle(fontSize: 16)),
                        ),
                        ListTile(
                          leading: Icon(Icons.person, color: Theme.of(context).cardColor),
                          title: Text('Full Name', style: TextStyle(fontSize: 16)),
                        ),
                        ListTile(
                          leading: Icon(Icons.email, color: Theme.of(context).cardColor),
                          title: Text('College Email', style: TextStyle(fontSize: 16)),
                        ),
                        ListTile(
                          leading: Icon(Icons.school, color: Theme.of(context).cardColor),
                          title: Text('Major', style: TextStyle(fontSize: 16)),
                        ),
                        ListTile(
                          leading: Icon(Icons.cake, color: Theme.of(context).cardColor),
                          title: Text('Birthdate', style: TextStyle(fontSize: 16)),
                        ),
                        ListTile(
                          leading: Icon(Icons.perm_contact_cal_rounded, color: Theme.of(context).cardColor),
                          title: Text('Student Picture', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    CheckboxListTile(
                      title: Text('I consent to the retrieval of my student data as listed above.'),
                      value: _consentGiven,
                      onChanged: (bool? value) {
                        setState(() {
                          _consentGiven = value!;
                        });
                      },
                      secondary: const Icon(Icons.privacy_tip),
                    ),
                  ],
              ),
              Spacer(),
              Align(
                alignment: Alignment.center,
                child: InkWell(
                  onTap: () async {
                    const String url = 'https://beefriendsapp.com/privacy-policy';
                    await launchUrl(Uri.parse(url));
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Read our privacy policy regarding your data',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      Icon(
                        Icons.open_in_new,
                        color: Colors.pink,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30,),
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _consentGiven
                      ? () {
                    Navigator.of(context).pop(true);
                  }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Text('Begin Registration', style: TextStyle(fontSize: 20)),
                  ),
                  style: ButtonStyle(
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );

  }
}
