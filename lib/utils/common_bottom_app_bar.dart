import 'package:BeeFriends/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

class CommonBottomAppBar extends StatefulWidget {
  final int initialIndex;
  final Function(int) onTap;

  CommonBottomAppBar({Key? key, required this.onTap, this.initialIndex = 0}) : super(key: key);

  @override
  _CommonBottomAppBarState createState() => _CommonBottomAppBarState();
}

class _CommonBottomAppBarState extends State<CommonBottomAppBar> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    // BottomAppBar(
    //   height: 65,
    //   color: Theme.of(context).primaryColorLight,
    //   child: Row(
    //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    //     children: <Widget>[
    //       _buildIconButton(
    //         index: 0,
    //         iconData: Icons.home_rounded,
    //         iconSize: 30,
    //       ),
    //       _buildIconButton(
    //         index: 1,
    //         iconData: Icons.heart_broken_rounded,
    //         iconSize: 45,
    //       ),
    //       _buildIconButton(
    //         index: 2,
    //         iconData: Icons.chat_rounded,
    //         iconSize: 25,
    //       ),
    //     ],
    //   ),
    // );

    return SalomonBottomBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
        widget.onTap(index);
      },
      backgroundColor: Color(0xff262626),
      items: [
        /// Home
        SalomonBottomBarItem(
          icon: Icon(Icons.home_filled, size: 30, color: _selectedIndex == 0 ? Colors.green : Colors.white),
          title: Text("Home", style: TextStyle(fontFamily: GoogleFonts.quicksand(fontWeight: FontWeight.bold).fontFamily),),
          selectedColor: Colors.green.shade200,
        ),

        /// OpenMessage
        SalomonBottomBarItem(
          icon: Icon(Icons.featured_play_list_rounded, size: 30, color: _selectedIndex == 1 ? Colors.blue : Colors.white),
          title: Text("OpenMessage", style: TextStyle(fontFamily: GoogleFonts.quicksand(fontWeight: FontWeight.bold).fontFamily),),
          selectedColor: Colors.blue.shade200,
        ),

        /// Matchmake
        SalomonBottomBarItem(
          icon: _selectedIndex == 2 ? SvgPicture.asset('assets/match_icon.svg', height: 35, colorFilter: ColorFilter.mode(Colors.pinkAccent, BlendMode.srcIn)) : SvgPicture.asset('assets/match_icon.svg', height: 36, colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          title: Text("Matchmake", style: TextStyle(fontFamily: GoogleFonts.quicksand(fontWeight: FontWeight.bold).fontFamily),),
          selectedColor: Colors.pink.shade200,
        ),

        /// Chats
        SalomonBottomBarItem(
          icon: Icon(Icons.chat_rounded, size: 30, color: _selectedIndex == 3 ? Colors.orange : Colors.white),
          title: Text("Chats", style: TextStyle(fontFamily: GoogleFonts.quicksand(fontWeight: FontWeight.bold).fontFamily),),
          selectedColor: Colors.orange.shade200,
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required int index,
    required IconData iconData,
    double iconSize = 24.0,
  }) {
    Color iconColor = _selectedIndex == index
        ? Theme.of(context).cardColor
        : Theme.of(context).primaryColorDark;

    return Padding(
      padding: EdgeInsets.all((iconSize - 24) / 2),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          widget.onTap(index);
        },
        borderRadius: BorderRadius.circular(48),
        child: Center(
          child: index == 1 ? SvgPicture.asset('assets/match_icon.svg', height: iconSize * 1.2, colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn)) : Icon(iconData, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}
