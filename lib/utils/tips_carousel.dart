import 'package:flutter/material.dart';
import 'package:page_indicator/page_indicator.dart';
import 'dart:async';

class TipsCarousel extends StatefulWidget {
  @override
  _TipsCarouselState createState() => _TipsCarouselState();
}

class _TipsCarouselState extends State<TipsCarousel> {
  final _pageController = PageController();
  Timer? _timer;

  final Map<String, Color?> _categoryColorMap = {
    'Profile Tip' : Colors.deepPurple[800],
    'Matching Tip' : Colors.pink[900],
    'Settings Tip' : Colors.green[900],
    'OpenMessage Tip' : Colors.orange[900],
  };

  final List<String> _categories = [
    'Profile Tip',
    'Matching Tip',
    'Profile Tip',
    'Settings Tip',
    'Profile Tip',
    'OpenMessage Tip',
    'Profile Tip',
    'OpenMessage Tip',
    'Profile Tip',
    'Matching Tip',
    'Profile Tip',
  ];

  final List<String> _tips = [
    'You can add more pictures other than your default photo.',
    'Want to stand out? Add a special message when sending a match request for an additional cost.',
    'You are allowed to upload up to 6 other pictures by default, and feel free to buy extra slots if you need more.',
    'You have complete control of what type of notifications are shown and whether you want to see in-app or push notifications.',
    'Make sure to set your personal description nicely, it is often the most frequently viewed part of your profile.',
    'Posting OpenMessages too frequently will result in a potentially very high posting cost.',
    'Always fill in correct information of yourself, or you can get reported for misrepresentation by others.',
    'You can report OpenMessages that you deem offensive or you suspect has violated our terms of service by clicking on the report button in the details.',
    'You can have up to 9 interests selected on your profile at a time.',
    'Setting too many matching criteria on will lead to a higher cost when sending a match request.',
    'Social accounts on profiles are set manually by the owners, beware getting misled by it.',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 5), (Timer timer) {
      if (_pageController.hasClients && mounted) {
        int nextPage = _pageController.page!.round() + 1;
        if (nextPage == _tips.length) {
          nextPage = 0; // Go back to first tip if we've reached the end
        }
        _pageController.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130, // Adjusted height
      child: PageIndicatorContainer(
        align: IndicatorAlign.bottom,
        length: _tips.length,
        indicatorSpace: 8.0,
        padding: EdgeInsets.all(10),
        indicatorColor: Colors.grey,
        indicatorSelectorColor: Colors.white,
        shape: IndicatorShape.roundRectangleShape(size: const Size(10, 3)),
        child: PageView.builder(
          controller: _pageController,
          itemCount: _tips.length,
          itemBuilder: (context, index) {
            return Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _categoryColorMap[_categories[index]],
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade900.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined, color: Colors.yellow, size: 18),
                      SizedBox(width: 8),
                      Text(
                        _categories[index],
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    _tips[index],
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
