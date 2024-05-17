import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class DisplayUtils {
  static const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  static List<Widget> displayInterests(DocumentSnapshot candidate) {
    // Ensure the interests field exists and is a string
    final interestsField = candidate.data() as Map<String, dynamic>?;

    if (interestsField == null || interestsField['interests'] == null || interestsField['interests'].isEmpty) {
      // If 'interests' is null or an empty string, return a text widget indicating no interests are set.
      return [Text("No interests set", style: TextStyle(fontSize: 18))];
    }

    String interests = interestsField['interests'];

    // Split the interests string by commas and remove empty entries
    List<String> interestsList = interests.split(',').where((interest) => interest.trim().isNotEmpty).toList();

    if (interestsList.isEmpty) {
      // If 'interests' is an empty list after removal of empty entries, return a text widget indicating no interests are set.
      return [Text("No interests set")];
    }

    // Create a Chip for each interest
    List<Widget> interestChips = interestsList
        .map((interest) => Chip(label: Text(interest.trim())))
        .toList();

    return interestChips;
  }

  static List<Widget> displayInterestsForMap(Map<String, dynamic> candidate) {
    // Ensure the interests field exists and is a string
    final interestsField = candidate;

    if (interestsField['interests'] == null || interestsField['interests'].isEmpty) {
      // If 'interests' is null or an empty string, return a text widget indicating no interests are set.
      return [Text("No interests set", style: TextStyle(fontSize: 18))];
    }

    String interests = interestsField['interests'];

    // Split the interests string by commas and remove empty entries
    List<String> interestsList = interests.split(',').where((interest) => interest.trim().isNotEmpty).toList();

    if (interestsList.isEmpty) {
      // If 'interests' is an empty list after removal of empty entries, return a text widget indicating no interests are set.
      return [Text("No interests set")];
    }

    // Create a Chip for each interest
    List<Widget> interestChips = interestsList
        .map((interest) => Chip(label: Text(interest.trim())))
        .toList();

    return interestChips;
  }

  static void openImageDialog(BuildContext context, List<String> images, int currentIndex) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(0), // Fullscreen dialog
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: <Widget>[
                ResponsiveSwiper(images: images, currentIndex: currentIndex),
                Positioned(
                  top: MediaQuery.of(context).padding.top, // For correct positioning under the status bar
                  right: 0,
                  child: Material(
                    type: MaterialType.transparency,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

class ResponsiveSwiper extends StatefulWidget {
  final List<String> images;
  final int currentIndex;

  ResponsiveSwiper({Key? key, required this.images, required this.currentIndex}) : super(key: key);

  @override
  _ResponsiveSwiperState createState() => _ResponsiveSwiperState();
}

class _ResponsiveSwiperState extends State<ResponsiveSwiper> {
  late PageController pageController;
  late int cIndex;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: widget.currentIndex);
    cIndex = widget.currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: PhotoViewGallery.builder(
        pageController: pageController,
        itemCount: widget.images.length,
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            maxScale: 1.0,
            imageProvider: NetworkImage(widget.images[index]),
            initialScale: PhotoViewComputedScale.contained * 1,
            heroAttributes: PhotoViewHeroAttributes(tag: widget.images[index]),
          );
        },
        scrollPhysics: const BouncingScrollPhysics(),
        backgroundDecoration: BoxDecoration(
          color: Colors.transparent,
        ),
        onPageChanged: (index) {
          setState(() {
            cIndex = index;
          });
        },
        loadingBuilder: (context, event) => Center(
          child: Container(
            width: 20.0,
            height: 20.0,
            child: CircularProgressIndicator(
              value: event == null ? 0 : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
            ),
          ),
        ),
      ),
    );
  }
}


class ScrollableText extends StatelessWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;

  const ScrollableText({
    Key? key,
    required this.text,
    this.maxLines = 20,
    this.style,
  }) : super(key: key);


  void _showFullScreenDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Rounded corners
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[800],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(padding: EdgeInsets.all(6), child: Text('Message Content', style: TextStyle(color: Colors.white),)),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],)
              ),
              Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Arial', // Custom font
                        color: Colors.black87,
                      ),
                    ),
                  ),
              ),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: maxLines,
          ellipsis: '...',
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        if (textPainter.didExceedMaxLines) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 200,
                child: Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.fade),
              ),
              InkWell(
                onTap: () => _showFullScreenDialog(context),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Read more', style: TextStyle(color: Colors.blue)),
                ),
              ),
            ],
          );
        } else {
          return Text(text, style: style);
        }
      },
    );
  }
}



