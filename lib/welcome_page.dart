import 'dart:typed_data';

import 'package:BeeFriends/login_page.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml2json/xml2json.dart';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';

import 'complete_registration.dart';
import 'package:BeeFriends/main.dart';

import 'consent_screen_page.dart';
import 'main_page.dart';


class WelcomePage extends StatelessWidget {
  final String displayName;
  final String number;
  final String birthDate;
  final String major;
  final String id;
  final String email;
  final String defaultPicture;

  WelcomePage({
    required this.displayName,
    required this.number,
    required this.birthDate,
    required this.major,
    required this.id,
    required this.email,
    required this.defaultPicture,
  });

  static final Config config = Config(
      tenant: 'common',
      clientId: 'b89cc19d-4587-4170-9b80-b39204b74380',
      scope: 'openid profile offline_access User.Read',
      redirectUri: 'https://beefriends-a1c17.firebaseapp.com/__/auth/handler',
      navigatorKey: navigatorKey,
      loader: SizedBox());
  final AadOAuth oauth = AadOAuth(config);

  @override
  Widget build(BuildContext context) {
    DateTime currentDate = DateTime.now();
    DateTime birthDateTime = DateTime.parse(birthDate);
    int age = currentDate.year - birthDateTime.year;

    if (birthDateTime.month > currentDate.month ||
        (birthDateTime.month == currentDate.month &&
            birthDateTime.day > currentDate.day)) {
      age--;
    }

    return Scaffold(
      appBar: AppBar(title: Text('Welcome to BeeFriends')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome, $displayName.",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Seems like you are new to BeeFriends.",
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "We have verified your identity as a student of the following institution:",
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    "BINUS University (Indonesia)",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    color: Theme.of(context).primaryColorDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "You are graduating in 20${number
                                .substring(0, 2)} with the major $major.",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "By continuing, you agree to our terms of service and will be registered for the following environment: ",
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    "BeeFriends for BINUS",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => CompleteRegistration(
                      id: id,
                      email: email,
                      number: number,
                      major: major,
                      birthDate: birthDate,
                      name: displayName,
                      defaultPicture: defaultPicture,
                    ),
                  ));
                },
                child: Text('Acknowledge & Continue', style: TextStyle(fontSize: 20)),
                style: ButtonStyle(
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.0),
            Container(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () async {
                  await oauth.logout();
                  Navigator.pop(context);
                },
                child: Text('Sign Out', style: TextStyle(fontSize: 20)),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Theme.of(context).primaryColorDark),
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


Future<Map<String, String>> fetchDetails(String domain) async {
  final xml2json = Xml2Json();

  final envelope1 = """
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:mes="Messier">
      <soapenv:Header/>
      <soapenv:Body>
         <mes:GetBinusianByEmail>
            <mes:emailWithoutDomain>$domain</mes:emailWithoutDomain>
         </mes:GetBinusianByEmail>
      </soapenv:Body>
    </soapenv:Envelope>
  """;

  final response1 = await http.post(
    Uri.parse("https://socs1.binus.ac.id/messier/GeneralApplication.svc"),
    headers: {
      "Content-Type": "text/xml; charset=utf-8",
      "SOAPAction": "Messier/IGeneralApplicationService/GetBinusianByEmail",
    },
    body: envelope1,
  );

  xml2json.parse(response1.body);
  var json1 = xml2json.toParker();
  var data1 = json.decode(json1);

  final String number = data1['s:Envelope']['s:Body']['GetBinusianByEmailResponse']['GetBinusianByEmailResult']['a:Number'];
  final String birthDate = data1['s:Envelope']['s:Body']['GetBinusianByEmailResponse']['GetBinusianByEmailResult']['a:BirthDate'];

  final envelope2 = """
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:mes="Messier" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays">
      <soapenv:Header/>
      <soapenv:Body>
         <mes:GetBinusianByNumberListWithProgramDescription>
            <mes:binusianNumberList>
               <arr:string>$number</arr:string>
            </mes:binusianNumberList>
         </mes:GetBinusianByNumberListWithProgramDescription>
      </soapenv:Body>
    </soapenv:Envelope>
  """;

  final response2 = await http.post(
    Uri.parse("https://socs1.binus.ac.id/messier/GeneralApplication.svc"),
    headers: {
      "Content-Type": "text/xml; charset=utf-8",
      "SOAPAction": "Messier/IGeneralApplicationService/GetBinusianByNumberListWithProgramDescription",
    },
    body: envelope2,
  );

  xml2json.parse(response2.body);
  var json2 = xml2json.toParker();
  var data2 = json.decode(json2);

  final String major = data2['s:Envelope']['s:Body']['GetBinusianByNumberListWithProgramDescriptionResponse']['GetBinusianByNumberListWithProgramDescriptionResult']['a:ClientBinusianWithProgramDescription']['a:ProgramDescription'];
  final String pictureId = data2['s:Envelope']['s:Body']['GetBinusianByNumberListWithProgramDescriptionResponse']['GetBinusianByNumberListWithProgramDescriptionResult']['a:ClientBinusianWithProgramDescription']['a:PictureId'];

  final envelope3 = """
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:mes="Messier">
     <soapenv:Header/>
     <soapenv:Body>
        <mes:GetThumbnail>
           <!--Optional:-->
           <mes:pictureId>$pictureId</mes:pictureId>
           <!--Optional:-->
           <mes:size>400</mes:size>
        </mes:GetThumbnail>
     </soapenv:Body>
  </soapenv:Envelope>
  """;

  final response3 = await http.post(
    Uri.parse("https://socs1.binus.ac.id/messier/GeneralApplication.svc"),
    headers: {
      "Content-Type": "text/xml; charset=utf-8",
      "SOAPAction": "Messier/IGeneralApplicationService/GetThumbnail",
    },
    body: envelope3,
  );

  xml2json.parse(response3.body);
  var json3 = xml2json.toParker();
  var data3 = json.decode(json3);

  String? defaultPictureUrl = "empty";
  final String defaultPicBase64 = data3['s:Envelope']['s:Body']['GetThumbnailResponse']['GetThumbnailResult'];
  defaultPictureUrl = await uploadBase64ImageToFirebase(defaultPicBase64, 'default_picture_$number');


  return {'number': number, 'birthDate': birthDate, 'major': major, 'defaultPicture': defaultPictureUrl ?? 'empty'};
}

Future<String?> uploadBase64ImageToFirebase(String base64String, String fileName) async {
  Uint8List uint8list = base64Decode(base64String);
  Reference storageRef = FirebaseStorage.instance.ref().child('user_pictures/$fileName.png');
  UploadTask uploadTask = storageRef.putData(uint8list, SettableMetadata(contentType: 'image/png'));

  TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
  String defaultPictureUrl = await snapshot.ref.getDownloadURL();

  return defaultPictureUrl;
}

Future<bool> afterLogin(BuildContext context, String id, String email, String displayName) async {
  if (email.endsWith("@binus.ac.id")) {
    final domain = email.split('@')[0];
    try {
      bool? consent = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConsentScreen(),
        ),
      );

      if (consent ?? false) {
        final details = await fetchDetails(domain);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WelcomePage(
              displayName: displayName,
              number: details['number']!,
              birthDate: details['birthDate']!,
              major: details['major']!,
              id: id,
              email: email,
              defaultPicture: details['defaultPicture']!,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginPage(onUserLoggedIn: () {
              navigatorKey.currentState?.pushReplacement(MaterialPageRoute(builder: (context) => MainPage()));
            }),
          ),
        );
      }
    }
    catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error fetching details: $e')));
    }
    return true;
  } else {

    return false;
  }

}
