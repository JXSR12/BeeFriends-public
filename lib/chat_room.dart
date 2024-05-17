import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:BeeFriends/chats_page.dart';
import 'package:BeeFriends/matchmake_page.dart';
import 'package:BeeFriends/profile_page.dart';
import 'package:BeeFriends/utils/data_manager.dart';
import 'package:BeeFriends/utils/display_utils.dart';
import 'package:BeeFriends/utils/helper_classes.dart';
import 'package:BeeFriends/utils/nickname_manager.dart';
import 'package:BeeFriends/utils/notification_manager.dart';
import 'package:BeeFriends/utils/static_global_keys.dart';
import 'package:BeeFriends/utils/user_provider.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path/path.dart' as Path;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:BeeFriends/main.dart';
import 'package:flutter/services.dart';

class ThumbnailCacheManager {
  static final ThumbnailCacheManager _instance = ThumbnailCacheManager._internal();
  factory ThumbnailCacheManager() => _instance;
  ThumbnailCacheManager._internal();

  final Map<String, String> _cache = {};

  String? getThumbnail(String videoUrl) => _cache[videoUrl];

  void setThumbnail(String videoUrl, String thumbnailPath) {
    _cache[videoUrl] = thumbnailPath;
  }
}

class ChatRoom extends StatefulWidget {
  final String chatRoomId;
  final String recipientId;
  final String chatRoomType;

  ChatRoom({required this.chatRoomId, required this.recipientId, required this.chatRoomType, Key? key})
      : super(key: key ?? chatRoomKey);

  @override
  ChatRoomState createState() => ChatRoomState();
}

class VideoItem extends StatelessWidget {
  final String videoUrl;
  final int index;
  final DocumentSnapshot snapshot;

  VideoItem({
    Key? key,
    required this.videoUrl,
    required this.index,
    required this.snapshot,
  }) : super(key: key);

  final ThumbnailCacheManager _cacheManager = ThumbnailCacheManager();

  @override
  Widget build(BuildContext context) {
    String? cachedThumbnail = _cacheManager.getThumbnail(videoUrl);

    Widget imageWidget(String imagePath) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0), // Set the border radius here
        child: FadeInImage(
          placeholder: Image.memory(kTransparentImage).image,
          image: FileImage(File(imagePath)),
          fit: BoxFit.cover,
          height: 256,
          width: 256,
        ),
      );
    }

    if (cachedThumbnail != null) {
      return imageWidget(cachedThumbnail);
    } else {
      return FutureBuilder<String>(
        future: ChatRoomState.getVideoThumbnail(videoUrl),
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // if (snapshot.hasData) {
              _cacheManager.setThumbnail(videoUrl, snapshot.data!);
              return imageWidget(snapshot.data!);
            // } else if (snapshot.hasError) {
            //   return ClipRRect(
            //     borderRadius: BorderRadius.circular(8.0),
            //     child: Center(child: Text('Error loading thumbnail')),
            //   );
            // }
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                color: Colors.black26,
              ),
              child: Center(
                child: SizedBox(height: 30, child: SpinKitWave(color: Colors.white60, duration: Duration(milliseconds: 400),)),
              ),
            ),
          );
        },
      );
    }
  }
}

enum AudioMessageType { VOICE_NOTE, AUDIO }

class _AudioMessage extends StatefulWidget {
  final String messageId;
  final String audioUrl;
  final AudioMessageType type;

  _AudioMessage({Key? key, required this.messageId, required this.audioUrl, required this.type}) : super(key: key);

  @override
  __AudioMessageState createState() => __AudioMessageState();
}
class __AudioMessageState extends State<_AudioMessage> {
  late AudioPlayer _audioPlayer;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double? _fileSizeInMB;
  ValueNotifier<double?> _downloadProgress = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
    _checkIfFileExists();
  }

  Future<void> _checkIfFileExists() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/${widget.messageId}';
    final fileExists = await File(filePath).exists();
    setState(() {
      _isDownloaded = fileExists;
      if(!_isDownloaded){
        _fetchFileSize();
      }
    });
  }

  Future<void> _fetchFileSize() async {
    try {
      final response = await http.head(Uri.parse(widget.audioUrl));
      if (response.statusCode == 200) {
        final contentLength = response.headers['content-length'];
        if (contentLength != null) {
          final fileSizeInBytes = int.parse(contentLength);
          setState(() {
            _fileSizeInMB = fileSizeInBytes / (1024 * 1024);
          });
        }
      }
    } catch (e) {
      print('Error fetching file size: $e');
    }
  }

  Future<void> _downloadAndSaveFile() async {
    _downloadProgress.value = 0.0;
    setState(() {
      _isDownloading = true;
    });
    try {
      final request = await HttpClient().getUrl(Uri.parse(widget.audioUrl));
      final response = await request.close();
      final bytes = <int>[];
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${widget.messageId}';
      final file = File(filePath);

      await response.listen((newBytes) {
        bytes.addAll(newBytes);
        _downloadProgress.value = bytes.length / response.contentLength!;
      }).asFuture();

      await file.writeAsBytes(bytes);
      setState(() {
        _isDownloaded = true;
        _isDownloading = false;
      });
      _downloadProgress.value = null;
    } catch (e) {
      print('Error downloading file: $e');
      _downloadProgress.value = null;
    }
  }

  Future<void> _initAndPlayAudio() async {
    if (!_isInitialized) {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${widget.messageId}';
      final fileExists = await File(filePath).exists();

      if (fileExists) {
        await _audioPlayer.setFilePath(filePath);
      }
      _isInitialized = true;
    }
    await _audioPlayer.play();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(widget.type == AudioMessageType.VOICE_NOTE ? Icons.multitrack_audio_rounded : Icons.audiotrack, size: 30),
      title: StreamBuilder<Duration>(
        stream: _audioPlayer.positionStream,
        builder: (context, snapshot) {
          var position = snapshot.data ?? Duration.zero;
          return StreamBuilder<Duration?>(
            stream: _audioPlayer.durationStream,
            builder: (context, snapshot) {
              var duration = snapshot.data ?? Duration.zero;
              position = position > duration ? duration : position;

              if(Platform.isIOS && _isDownloaded) return SizedBox.shrink();

              return Slider(
                onChanged: (value) {
                  _audioPlayer.seek(Duration(milliseconds: value.round()));
                },
                value: position.inMilliseconds.toDouble(),
                min: 0.0,
                max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : position.inMilliseconds.toDouble(),
              );
            },
          );
        },
      ),
      subtitle: Platform.isIOS && _isDownloaded ? _buildIOSContent() : _buildDefaultContent(),
    );
  }

  Widget _buildIOSContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('In-app audio player is currently disabled on iOS.'),
        TextButton.icon(
          onPressed: _openFile,
          icon: Icon(Icons.folder_open),
          label: Text('Open audio file'),
        ),
      ],
    );
  }

  Widget _buildDefaultContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isDownloaded)
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              if (_isPlaying) {
                _audioPlayer.pause();
              } else {
                _initAndPlayAudio();
              }
            },
          )
        else
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _downloadAndSaveFile,
          ),
        if (!_isDownloaded && !_isDownloading)
          _fileSizeInMB != null
              ? Text('${_fileSizeInMB!.toStringAsFixed(1)} MB')
              : SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, size: 20, duration: Duration(milliseconds: 200),)),
        if (_isDownloaded)
          StreamBuilder<Duration?>(
            stream: _audioPlayer.durationStream,
            builder: (context, snapshot) {
              final duration = snapshot.data ?? Duration.zero;
              final durationText = "${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(duration.inSeconds.remainder(60).toString().padLeft(2, '0'))}";
              return Text(durationText);
            },
          )
        else if (_isDownloading)
          ValueListenableBuilder<double?>(
            valueListenable: _downloadProgress,
            builder: (context, progress, _) {
              if (progress != null) {
                return Expanded(
                  child: LinearProgressIndicator(value: progress),
                );
              }
              return SizedBox.shrink();
            },
          ),
      ],
    );
  }

  Future<void> _openFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/${widget.messageId}';
    OpenFile.open(filePath);
  }
}

class MessageWidget extends StatefulWidget {
  final QueryDocumentSnapshot message;
  final AsyncSnapshot<QuerySnapshot<Object?>> snapshot;
  final int index;
  final CompleteUser? currentUser;
  final Function enterReplyMode;
  final Function unsendMessage;
  final Function buildMessageContent;
  final Function buildMessageStamp;

  const MessageWidget({
    Key? key,
    required this.currentUser,
    required this.message,
    required this.snapshot,
    required this.index,
    required this.enterReplyMode,
    required this.unsendMessage,
    required this.buildMessageContent,
    required this.buildMessageStamp,
  }) : super(key: key);

  @override
  _MessageWidgetState createState() => _MessageWidgetState();
}

class _MessageWidgetState extends State<MessageWidget> with AutomaticKeepAliveClientMixin{

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant MessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      // Update the state only if the message has changed
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    GlobalKey key = GlobalKey();
    bool isOutgoingMessage = widget.message['authorId'] == widget.currentUser?.id;

    Widget messageWidget = ListTile(
      contentPadding: EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 0),
      key: key,
      title: Align(
        alignment: isOutgoingMessage ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: isOutgoingMessage ? EdgeInsets.only(left: 40) : EdgeInsets.only(right: 40),
          padding: EdgeInsets.symmetric(horizontal: (widget.message['messageType'] == 'IMAGE' || widget.message['messageType'] == 'VIDEO') ? 6 : 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isOutgoingMessage ? Colors.lightBlue[100] : Colors.green[100],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                  child: widget.buildMessageContent(widget.message, widget.snapshot, widget.index)),
              SizedBox(width: 10),
              widget.buildMessageStamp(widget.message, isOutgoingMessage),
            ],
          ),
        ),
      ),
      onLongPress: () {
        if (isOutgoingMessage) {
          showModalBottomSheet(
            constraints: BoxConstraints.tight(Size.fromHeight(200)),
            context: context,
            builder: (context) => Column(
              children: [
                ListTile(
                  leading: Icon(Icons.reply_rounded),
                  title: Text("Reply"),
                  onTap: () {
                    widget.enterReplyMode(widget.message);
                    Navigator.of(context).pop();
                  },
                ),
                if(widget.message['messageType'] != 'DELETED')
                ListTile(
                  leading: Icon(Icons.highlight_remove_rounded),
                  title: Text("Unsend"),
                  onTap: () {
                    widget.unsendMessage(widget.message);
                  },
                ),
                if(widget.message['messageType'] == 'TEXT' || widget.message['messageType'] ==  'REPLY')
                  ListTile(
                    leading: Icon(Icons.copy_rounded),
                    title: Text("Copy Message"),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: widget.message['content'])).then((_) {
                        Fluttertoast.showToast(
                          msg: "Message content copied to clipboard",
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          timeInSecForIosWeb: 1,
                          backgroundColor: Colors.black54,
                          textColor: Colors.white,
                          fontSize: 16.0,
                        );
                        Navigator.of(context).pop();
                      }).catchError((error) {
                        // Handle error if any
                        print("Error copying to clipboard: $error");
                      });
                    },
                  ),
              ],
            )
          );
        } else {
          showModalBottomSheet(
              constraints: BoxConstraints.tight(Size.fromHeight(200)),
              context: context,
              builder: (context) => Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.reply_rounded),
                    title: Text("Reply"),
                    onTap: () {
                      widget.enterReplyMode(widget.message);
                      Navigator.of(context).pop();
                    },
                  ),
                  if(widget.message['messageType'] == 'TEXT' || widget.message['messageType'] ==  'REPLY')
                    ListTile(
                      leading: Icon(Icons.copy_rounded),
                      title: Text("Copy Message"),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.message['content'])).then((_) {
                          Fluttertoast.showToast(
                            msg: "Message content copied to clipboard",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            timeInSecForIosWeb: 1,
                            backgroundColor: Colors.black54,
                            textColor: Colors.white,
                            fontSize: 16.0,
                          );
                          Navigator.of(context).pop();
                        }).catchError((error) {
                          // Handle error if any
                          print("Error copying to clipboard: $error");
                        });
                      },
                    ),
                ],
              )
          );
        }
      },
    );

    if (widget.index == widget.snapshot.data!.docs.length - 1 || ChatRoomState.getDate(widget.snapshot.data!.docs[widget.index]['timestamp'] ?? Timestamp.now()) != ChatRoomState.getDate(widget.snapshot.data!.docs[widget.index + 1]['timestamp'])) {
      final timeString = ChatRoomState.getDateSeparatorText(widget.snapshot.data!.docs[widget.index]['timestamp'] ?? Timestamp.now());

      return Column(
        children: [
          Chip(label: Text(timeString)),
          messageWidget,
        ],
      );
    }


    return messageWidget;
  }
}


class ChatRoomState extends State<ChatRoom> with TickerProviderStateMixin, WidgetsBindingObserver{
  final _floatingChipKey = GlobalKey();
  late CompleteUser? currentUser = null;
  TextEditingController _messageController = TextEditingController();
  late DocumentSnapshot user;
  late bool friendRequestSent = false;
  late bool friendRequestReceived = false;
  ScrollController _scrollController = ScrollController();
  StreamSubscription? _chatSubscription;
  bool isTextFilled = false;
  String topMostMessageTime = "None";
  late bool _isUserScrolling = false;
  late bool _showChip = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  Timer? _hideTimer;
  double _downloadProgress = 0.0;
  final ThumbnailCacheManager _cacheManager = ThumbnailCacheManager();

  final Set<Timestamp> _visibleMessageTimestamps = {};

  final ImagePicker _imagePicker = ImagePicker();
  final ValueNotifier<bool> _isUploading = ValueNotifier<bool>(false);
  final ValueNotifier<double> _uploadProgress = ValueNotifier<double>(0.0);

  int _messageLimit = 20;
  int _messageLimitIncrement = 20;

  final Map<String, GlobalKey> _messageKeys = {};

  bool replyingMode = false;
  String repliedMessageId = '';
  String repliedMessageContent = '';

  late AppLifecycleState _lastLifecycleState;

  late QueryDocumentSnapshot<Object?> repliedMessage;

  bool lastMessageLimitUsed = false;

  int lastSnapshotLength = 0;

  ValueNotifier<bool> isTextFilledNotifier = ValueNotifier(false);

  ValueNotifier<bool> isReplyingModeNotifier = ValueNotifier(false);

  bool showRecipientReads = true;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(vsync: this, duration: Duration(milliseconds: 150));
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0), end: Offset(0, -1)).animate(_slideController);

    _messageController.addListener(() {
      isTextFilledNotifier.value = _messageController.text.trim().isNotEmpty;
    });

    _scrollController.addListener(_scrollListener);

    _chatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          if (_lastLifecycleState == AppLifecycleState.resumed) {
            _markMessagesAsRead();
          }
        });

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lastLifecycleState = AppLifecycleState.resumed;
      _markMessagesAsRead();
    });
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
        if(lastMessageLimitUsed){
          setState(() {
            _messageLimit += _messageLimitIncrement;
            _messageLimitIncrement += _messageLimitIncrement;
            lastMessageLimitUsed = false;
          });
        }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    if(state == AppLifecycleState.resumed){
      _markMessagesAsRead();
    }
  }

  void _markMessagesAsRead() async {
    String currentUserId = currentUser?.id ?? '';
    String recipientId = widget.recipientId;

    QuerySnapshot messagesReadByOnlyOne = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatRoomId)
        .collection('messages')
        .where('reads', whereNotIn: [[currentUserId, recipientId], [recipientId, currentUserId]])
        .get();

    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (QueryDocumentSnapshot message in messagesReadByOnlyOne.docs) {
      batch.update(message.reference, {
        'reads': FieldValue.arrayUnion([currentUserId])
      });
    }

    _resetUnreadCount();

    await batch.commit();
  }



  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatSubscription?.cancel();
    _slideController.dispose();
    _scrollController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newUser = UserProviderState.userOf(context);
    if (newUser != currentUser) {
      if (newUser != currentUser) {
        setState(() {
          currentUser = newUser;
          validateShowReads();
        });
      }
    }
  }

  void validateShowReads() async {
    var userSettingsDoc = await FirebaseFirestore.instance
        .collection('userSettings')
        .doc(widget.recipientId)
        .get();

    if (userSettingsDoc.exists) {
      var data = userSettingsDoc.data();
      bool showReadReceipts = data?['show_read_receipts'];
      setState(() {
        showRecipientReads = showReadReceipts ?? true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(widget.recipientId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return SizedBox(height: 30, child: SpinKitWave(color: Colors.white70, duration: Duration(milliseconds: 200),));
            user = snapshot.data!;

            if (widget.chatRoomType == 'match') {
              var gender = user['gender'].toString().capitalizeFirst;
              return GestureDetector(
                onTap: () => _showRequestDetails(snapshot.data!), // Show request details on title tap
                child: Text(
                  NicknameManager.getNickname(widget.recipientId, "$gender, B${user['studentNumber'].substring(0, 2)}\n${user['major']}"),
                  style: TextStyle(fontSize: 14),
                ),
              );
            } else {
              return GestureDetector(
                onTap: () => _showRequestDetails(snapshot.data!), // Show request details on title tap
                child: Text(formatName(user['name'])),
              );
            }
          },
        ),
        actions: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection(widget.chatRoomType == 'match' ? 'matches' : 'friends').doc(widget.recipientId).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Container();

              if (snapshot.hasError || !snapshot.data!.exists) {
                return _handleInvalidRelationship();
              }
              if (widget.chatRoomType == 'match') {
                return Row(children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection('matches').doc(widget.recipientId).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return Container();

                    if (snapshot.hasError || !snapshot.data!.exists) {
                      return _handleInvalidRelationship();
                    }

                    final data = snapshot.data!.data() as Map;
                    if (data.containsKey('friendRequest') && data['friendRequest'] == true) {
                      friendRequestSent = true;
                    }

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection('matches').doc(widget.recipientId).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return Container();

                        if (snapshot.hasError || !snapshot.data!.exists) {
                          return _handleInvalidRelationship();
                        }

                        final data = snapshot.data!.data() as Map;
                        friendRequestSent = data.containsKey('friendRequest') && data['friendRequest'] == true;

                        return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection('users').doc(widget.recipientId).collection('matches').doc(currentUser?.id).snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return Container();

                              if (snapshot.hasError || !snapshot.data!.exists) {
                                return _handleInvalidRelationship();
                              }

                              final data = snapshot.data!.data() as Map;
                              friendRequestReceived = data.containsKey('friendRequest') && data['friendRequest'] == true;

                              return _buildFriendButton();
                            });
                      },
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.block_rounded, color: Colors.redAccent),
                  onPressed: snapshot.hasError || !snapshot.data!.exists ? null : _confirmRemoveMatch,
                )
                ]);
              } else {
                return _buildButton(
                  pressFunction: _friendInfo,
                  icon: Icons.person_4_rounded,
                  label: "Friend",
                  backgroundColor: Colors.lightGreen,
                );
              }
            },
          ),
        ],

      ),
      body:
      Stack(
        children: [
          Column(
            children: <Widget>[
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatRoomId).collection('messages').orderBy('timestamp', descending: true).limit(_messageLimit).snapshots(),
                builder: (context, snapshot) {
                  if((snapshot.data?.docs.length ?? 0) != lastSnapshotLength){
                    lastMessageLimitUsed = true;
                    lastSnapshotLength = snapshot.data!.docs.length;
                  }

                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return ListView.builder(
                    reverse: true,
                    itemCount: snapshot.data!.docs.length,
                    controller: _scrollController,
                    itemBuilder: (context, index) {
                      var message = snapshot.data!.docs[index];

                      var key = GlobalKey();
                      _messageKeys[message.id] = key;

                      return VisibilityDetector(
                        key: ValueKey(message.id),
                        onVisibilityChanged: (visibilityInfo) {
                          var visiblePercentage = visibilityInfo.visibleFraction * 100;
                          if (visiblePercentage > 0) {
                            _visibleMessageTimestamps.add(message['timestamp']);
                          } else {
                            _visibleMessageTimestamps.remove(message['timestamp']);
                          }
                          _updateOldestVisibleMessage();
                        },
                        child: SwipeTo(
                          child: MessageWidget(
                            key: key,
                            message: message,
                            snapshot: snapshot,
                            index: index,
                            buildMessageContent: _buildMessageContent,
                            buildMessageStamp: _buildMessageStamp,
                            currentUser: currentUser,
                            enterReplyMode: enterReplyMode,
                            unsendMessage: unsendMessage,
                          ),
                          onRightSwipe: (details) {
                            enterReplyMode(message);
                          },
                          animationDuration: Duration(milliseconds: 120),
                          iconColor: Colors.black54,
                          iconSize: 40,
                          iconOnRightSwipe: Icons.reply_rounded,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
              _buildMessageBar()
          ],
        ),
          if (_showChip || _slideController.status != AnimationStatus.dismissed)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: Chip(
                    key: _floatingChipKey,
                    label: Text(topMostMessageTime),
                  ),
                ),
              ),
            ),
          ValueListenableBuilder<bool>(
            valueListenable: _isUploading,
            builder: (context, isUploading, child) {
              if (!isUploading) return SizedBox.shrink(); // If not uploading, don't show anything

              return Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 30, child: SpinKitWave(color: Colors.white60, duration: Duration(milliseconds: 600),)),
                        SizedBox(height: 20),
                        Text('Uploading attachment..', style: TextStyle(color: Colors.white),)
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ]),
    );
  }

  Widget _handleInvalidRelationship() {
    return InkWell(
      onTap: () async {
        bool isFriend = await DataManager.isFriend(currentUser?.id, widget.recipientId);
        if (isFriend) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatRoom(
                chatRoomId: widget.chatRoomId,
                recipientId: widget.recipientId,
                chatRoomType: 'friend',
              ),
            ),
          );
          return;
        }

        bool isMatch = await DataManager.isMatch(currentUser?.id, widget.recipientId);
        if (isMatch) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatRoom(
                chatRoomId: widget.chatRoomId,
                recipientId: widget.recipientId,
                chatRoomType: 'match',
              ),
            ),
          );
          return;
        }

        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("You have been removed"),
              content: Text(
                  "We are sorry to inform you, but the user in the other end has decided to end communications with you and remove you from their contacts. Therefore, you can no longer contact them or view their profile."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Dismiss"),
                ),
              ],
            );
          },
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 8),
          Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Relationship changed",
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
              Text(
                "Tap to refresh",
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ],),
          SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildFriendButton() {
    if (friendRequestSent) {
      return _buildButton(
          pressFunction: _pendingFriendRequest,
          icon: Icons.access_time,
          label: "Pending",
          backgroundColor: Colors.grey
      );
    } else if (friendRequestReceived) {
      return _buildButton(
          pressFunction: _acceptFriendRequest,
          icon: Icons.check,
          label: "Accept Friend",
          backgroundColor: Colors.green
      );
    } else {
      return _buildButton(
          pressFunction: _sendFriendRequest,
          icon: Icons.person_add,
          label: "Add Friend",
          backgroundColor: Colors.blue
      );
    }
  }

  Widget _buildButton({required Function pressFunction, required IconData icon, required String label, required Color backgroundColor}) {
    return Padding(
        padding: EdgeInsets.all(10),
        child: ElevatedButton.icon(
          onPressed: () {
            pressFunction();
          },
          icon: Icon(icon),
          label: label.isNotEmpty ? Text(label) : SizedBox.shrink(),
          style: ElevatedButton.styleFrom(backgroundColor: backgroundColor),
        )
    );
  }

  String _getResizedImageUrl(String originalUrl) {

    return originalUrl;
  }

  void enterReplyMode(QueryDocumentSnapshot message) {
     isReplyingModeNotifier.value = false;
      repliedMessage = message;
      repliedMessageId = message.id;
      repliedMessageContent = _getPreviewContent(message);
      isReplyingModeNotifier.value = true;
      replyingMode = true;
  }

  Widget _buildMessageContent(QueryDocumentSnapshot message, AsyncSnapshot<QuerySnapshot<Object?>> snapshot, int index){

    switch(message['messageType']){
      case 'DELETED':
        return Text('This message has been deleted', style: TextStyle(fontStyle: FontStyle.italic));
      case 'TEXT':
        return ScrollableText(
          text: message['content'],
          maxLines: 20
        );
      case 'REPLY':
        var replyingToMessageId = message['replyingTo'];

        var repliedMessage = null;
        try{
          repliedMessage = snapshot.data!.docs.firstWhere((doc) => doc.id == replyingToMessageId);
        }catch(e){
          repliedMessage = null;
        }

        bool useCached = repliedMessage != null;
        print('Use Cached: $useCached');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _scrollToMessage(snapshot, replyingToMessageId),
              child: _buildRepliedMessage(useCached, repliedMessage, replyingToMessageId),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: ScrollableText(
                  text: message['content'],
                  maxLines: 20
              ),
            ),
          ],
        );
      case 'IMAGE':
        return GestureDetector(
          onTap: () {
            _openImageDialog(context, snapshot.data!.docs, index);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0), // Set the border radius here
            child: FadeInImage.memoryNetwork(
              placeholder: kTransparentImage,
              image: _getResizedImageUrl(message['content']),
              height: 250,
              width: 250,
              fit: BoxFit.cover,
              // Handle image loading error
              imageErrorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                return Container(
                  height: 250,
                  width: 250,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8), // Apply the same border radius for consistency
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    color: Colors.white,
                    size: 50,
                  ),
                  alignment: Alignment.center,
                );
              },
            ),
          ),
        );

      case 'VIDEO':
        return GestureDetector(
          onTap: () {
            _openImageDialog(context, snapshot.data!.docs, index);
          },
          child: VideoItem(videoUrl: message['content'], index: index, snapshot: snapshot.data!.docs[index])
        );
      case 'AUDIO':
        return _AudioMessage(
          messageId: message.id,
          audioUrl: message['content'],
          type: AudioMessageType.AUDIO
        );
      case 'VOICE_NOTE':
        return _AudioMessage(
            messageId: message.id,
            audioUrl: message['content'],
            type: AudioMessageType.VOICE_NOTE
        );
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildRepliedMessage(bool useCached, QueryDocumentSnapshot? repliedMessage, String replyingToMessageId) {
    return FutureBuilder<QueryDocumentSnapshot?>(
      future: useCached ? Future.value(repliedMessage) : fetchRepliedMessage(replyingToMessageId),
      builder: (context, snapshot) {
        // if (snapshot.connectionState == ConnectionState.waiting) {
        //   print('>BRP> BUILDING LOADING MESSAGE $replyingToMessageId');
        //   return _buildLoadingMessage();
        // }

        //CHECKING CONNECTION STATE IS DISABLED DUE TO STUCK IN THERE SOMETIMES

        QueryDocumentSnapshot? snapshotData = snapshot.data;
        if (snapshotData == null) {
          return _buildErrorMessage();
        }

        String senderName = _getRepliedSenderName(snapshotData);
        Color senderColor = _getSenderColor(snapshotData);

        return Container(
          padding: EdgeInsets.all(0),
          margin: EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(3)),
            color: Color.fromARGB(15, 0, 0, 0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 36,
                child:
                Container(
                  width: 5,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: senderColor,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(3), bottomLeft: Radius.circular(3)),
                  ),
                ),
              ),
              SizedBox(width: 8), // Spacing between color bar and text
              // Message content
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName,
                      style: TextStyle(fontWeight: FontWeight.bold, color: senderColor, fontSize: 14),
                    ),
                    Text(
                      _getPreviewContent(snapshotData),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: Color.fromARGB(100, 0, 0, 0)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingMessage() {
    print('Building Loading Message!!!');
    return Container(
      padding: EdgeInsets.all(0),
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(3)),
        color: Color.fromARGB(75, 255, 255, 255),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 8),
          Text('Please wait', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: EdgeInsets.all(0),
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(3)),
        color: Color.fromARGB(75, 255, 255, 255),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: Container(
              width: 5,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(3), bottomLeft: Radius.circular(3)),
              ),
            ),
          ),
          SizedBox(width: 8), // Spacing between color bar and text
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, size: 20, duration: Duration(milliseconds: 200))),
                Text(
                  'Trying to get original message',
                  style: TextStyle(fontSize: 16, color: Color.fromARGB(100, 0, 0, 0)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Future<QueryDocumentSnapshot?> fetchRepliedMessage(String messageId) async {
    print('Fetching replied message $messageId');
    try {
      QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatRoomId)
          .collection('messages')
          .where(FieldPath.documentId, isEqualTo: messageId)
          .limit(1)
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        print('Fetching: is not empty');
        return messagesSnapshot.docs.first;
      }

      print('Error fetching message1');
      return null;
    } catch (e) {
      print('Error fetching message2 : $e');
      return null;
    }
  }


  String _getPreviewContent(QueryDocumentSnapshot message) {
    switch(message['messageType']) {
      case 'TEXT' || 'REPLY':
        return message['content'];
      case 'IMAGE':
        return 'An image attachment';
      case 'VIDEO':
        return 'A video attachment';
      case 'AUDIO':
        return 'An audio attachment';
      case 'VOICE_NOTE':
        return 'A voice note';
      case 'DELETED':
        return 'Deleted message';
      default:
        return '[Message]';
    }
  }

  String _getPreviewContentByTypeAndString(String type, String message) {
    switch(type) {
      case 'TEXT' || 'REPLY':
        return message;
      case 'IMAGE':
        return 'An image attachment';
      case 'VIDEO':
        return 'A video attachment';
      case 'AUDIO':
        return 'An audio attachment';
      case 'VOICE_NOTE':
        return 'A voice note';
      case 'DELETED':
        return 'Deleted message';
      default:
        return '[Message]';
    }
  }

  void _scrollToMessage(AsyncSnapshot<QuerySnapshot<Object?>> snapshot, String messageId) {
    // print('Scrolling to replied');
    int messageIndex = snapshot.data!.docs.indexWhere((doc) => doc.id == messageId);
    if (messageIndex != -1) {
      GlobalKey<State<StatefulWidget>>? key = _messageKeys[messageId];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(key.currentContext!,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    }
  }

  void _openImageDialog(BuildContext context, List<QueryDocumentSnapshot> messages, int currentIndex) {
    List<QueryDocumentSnapshot> mediaMessages = messages
        .where((msg) => msg['messageType'] == 'IMAGE' || msg['messageType'] == 'VIDEO')
        .toList();

    int convertedIndex = mediaMessages.indexOf(mediaMessages.where((msg) => msg['content'] == messages[currentIndex]['content']).first);

    mediaMessages = mediaMessages.reversed.toList();
    int mediaIndex = mediaMessages.length - 1 - convertedIndex;

    print(mediaIndex);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => Container(
            height: MediaQuery.of(context).size.height * 0.9,
            child: Stack(
              children: <Widget>[
                Swiper(
                  itemCount: mediaMessages.length,
                  index: mediaIndex,
                  loop: false,
                  itemBuilder: (context, index) {
                    QueryDocumentSnapshot mediaMessage = mediaMessages[index];
                    if (mediaMessage['messageType'] == 'IMAGE') {
                      return PhotoView(
                        imageProvider: NetworkImage(_getResizedImageUrl(mediaMessage['content'])),
                      );
                    } else if (mediaMessage['messageType'] == 'VIDEO') {
                      String videoUrl = mediaMessage['content'];

                      final videoRef = FirebaseStorage.instance.refFromURL(videoUrl);

                      String messageId = mediaMessage.id;
                      String fileExtension = Path.extension(videoRef.name);

                      return Material(child:
                      FutureBuilder<String>(
                        future: (() async {
                          // Get the thumbnail URL
                          String? cachedThumbnail = _cacheManager.getThumbnail(videoUrl);
                          if (cachedThumbnail != null) {
                            return cachedThumbnail;
                          } else {
                            String thumbnail = await getVideoThumbnail(videoUrl);
                            _cacheManager.setThumbnail(videoUrl, thumbnail);
                            return thumbnail;
                          }
                        })(),
                        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Error loading video'));
                          } else if (!snapshot.hasData) {
                            return Center(child: SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 200),)));
                          } else {
                            return FutureBuilder<Directory>(
                              future: getApplicationDocumentsDirectory(),
                              builder: (context, directorySnapshot) {
                                if (directorySnapshot.connectionState == ConnectionState.done && directorySnapshot.data != null) {
                                  String thumbnailUrl = snapshot.data!;
                                  String appDocPath = directorySnapshot.data!.path;
                                  File localFile = File('$appDocPath/$messageId$fileExtension');
                                  bool isLocalFile = localFile.existsSync();

                                  return Stack(
                                    alignment: Alignment.center,
                                    children: <Widget>[
                                      Positioned.fill(
                                        child: Container(
                                          color: Colors.black,
                                        ),
                                      ),
                                      FadeInImage(
                                        placeholder: Image.memory(kTransparentImage).image,
                                        image: FileImage(File(thumbnailUrl)),
                                        fit: BoxFit.cover,
                                        height: 256,
                                      ),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(30.0),
                                        onTap: () async {
                                          if (isLocalFile) {
                                            OpenFile.open(localFile.path); // Open local file
                                          } else {
                                            // Download logic
                                            var result = await requestProperPermission();
                                            if (result) {
                                              Dio dio = Dio();
                                              Directory appDocDir = await getApplicationDocumentsDirectory();
                                              String appDocPath = appDocDir.path;
                                              try {
                                                await dio.download(
                                                  videoUrl,
                                                  '$appDocPath/$messageId$fileExtension',
                                                  onReceiveProgress: (received, total) {
                                                    if (total != -1) {
                                                      setState(() {
                                                        _downloadProgress = received / total;
                                                      });
                                                    }
                                                  },
                                                );
                                                setState(() {
                                                  _downloadProgress = 0.0;
                                                });
                                                OpenFile.open('$appDocPath/$messageId$fileExtension');
                                              } catch (e) {
                                                setState(() {
                                                  _downloadProgress = 0.0;
                                                });
                                                print(e);
                                              }
                                            } else {
                                              // Permission denied logic
                                            }
                                          }
                                        },
                                        child: isLocalFile ? playOverlay() : downloadOverlay(),
                                      ),
                                    ],
                                  );
                                }
                                else {
                                  return Center(
                                    child: Container(
                                      color: Colors.black,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Text(
                                            'Loading video',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          SizedBox(height: 10),
                                          SizedBox(
                                            height: 30,
                                            child: SpinKitWave(
                                              color: Colors.black54,
                                              duration: Duration(milliseconds: 200),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          }
                        },
                      )
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  },
                ),
                Positioned(
                  top: 0,
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

  Widget downloadOverlay() {
    return Container(
      padding: EdgeInsets.all(12.0), // Adjust the padding as needed
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Wrap(
        // Wrap is used to keep the icon and text together
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8.0, // Space between the icon and text
        children: <Widget>[
          Icon(Icons.download_rounded, size: 50, color: Colors.white),
          Text(
            'Download this video to view',
            style: TextStyle(color: Colors.white),
          ),
          _downloadProgress > 0.0
              ? Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          )
              : SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget playOverlay() {
    return Container(
      padding: EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Icon(
        Icons.play_circle_outline,
        size: 50,
        color: Colors.white,
      ),
    );
  }

  Future<bool> requestProperPermission() async {
    PermissionStatus status = PermissionStatus.granted;

    if (Platform.isAndroid) {
      // Android 13+ corresponds to API level 33
      if (Platform.isAndroid && await Permission.videos.status.isDenied) {
        // On Android 13+ (API level 33) or higher, request videos permission
        if (await Permission.videos.request().isGranted) {
          // Granted
          return true;
        }
      } else {
        // On Android 12 (API level 32) or lower, request storage permission
        if (await Permission.storage.request().isGranted) {
          // Granted
          return true;
        }
      }
    } else if (Platform.isIOS) {
      status = await Permission.storage.request();
    }

    return status.isGranted;
  }

  static Future<String> getVideoThumbnail(String videoUrl) async {
    String? path = await VideoThumbnail.thumbnailFile(
      video: videoUrl,
      imageFormat: ImageFormat.PNG,
      maxWidth: 512,
      quality: 18,
    );

    return path ?? '.png';
  }

  Widget _buildMessageStamp(QueryDocumentSnapshot<Object?> messageSnapshot, bool isOutgoingMessage) {
    Map<String, dynamic> message = messageSnapshot.data() as Map<String, dynamic>;

    if (!isOutgoingMessage) {
      return Row(
        children: [Text(
          getTimeString(message['timestamp'] ?? Timestamp.now()),
          style: TextStyle(color: Colors.black.withAlpha(120), fontSize: 12),
        ),]
      );
    }

    List<String>? reads = List<String>.from(message['reads'] ?? []);
    bool isRead = reads != null && reads.contains(widget.recipientId);

    Icon statusIcon;
    if (isRead && showRecipientReads) {
      statusIcon = Icon(Icons.done_all, color: Colors.blue, size: 16,);
    } else if (!isRead || !showRecipientReads) {
      statusIcon = Icon(Icons.done_all, color: Colors.grey, size: 16,);
    } else {
      statusIcon = Icon(Icons.done, color: Colors.grey, size: 16,);
    }

    return Row(
          mainAxisAlignment: MainAxisAlignment.end,  // Align content to the end
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,  // Align to bottom
          children: [
            Text(
              getTimeString(message['timestamp'] ?? Timestamp.now()),
              style: TextStyle(color: Colors.black.withAlpha(120), fontSize: 12),
            ),
            SizedBox(width: 5),
            statusIcon,
          ],
        );
  }

  Widget _buildMessageBar() {
    return Container(
      color: Theme.of(context).primaryColorLight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<bool>(
                  valueListenable: isReplyingModeNotifier,
                  builder: (context, isReplyingMode, child) {
                    if (isReplyingMode) {
                      return _buildReplyingSection();
                    }else {
                      return const SizedBox.shrink();
                    }
                  }
              ),
              Container(
                color: Colors.black.withOpacity(0.2),
                padding: EdgeInsets.only(left: 8.0, right: 8.0, top: 4.0, bottom: (Platform.isIOS ? 24.0 : 4.0)),
                child: ValueListenableBuilder<bool>(
                  valueListenable: isTextFilledNotifier,
                  builder: (context, isTextFilled, child) {
                    return Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.black54,  // or any color you prefer
                          child: IconButton(
                            icon: Icon(Icons.add, color: Colors.white),  // Adjust icon color
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (BuildContext context) {
                                  return SafeArea(
                                    child: Wrap(
                                      children: <Widget>[
                                        ListTile(
                                          leading: Icon(Icons.image),
                                          title: Text("Send a Picture"),
                                          onTap: () {
                                            Navigator.of(context).pop();
                                            _sendImageMessage();
                                          },
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.audiotrack),
                                          title: Text("Send an Audio"),
                                          onTap: () {
                                            Navigator.of(context).pop();
                                            _sendAudioMessage();
                                          },
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.videocam),
                                          title: Text("Send a Video"),
                                          onTap: () {
                                            Navigator.of(context).pop();
                                            _sendVideoMessage();
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            maxLines: 6,
                            minLines: 1,
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              fillColor: Colors.white,
                              filled: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        if (isTextFilled)
                          IconButton(
                            icon: Icon(Icons.send, color: Colors.white, size: 30,),
                            onPressed: replyingMode ? _sendReplyMessage : _sendTextMessage,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildReplyingSection() {
    String senderName = _getRepliedSenderName(repliedMessage);
    Color senderColor = _getSenderColor(repliedMessage);

    return Container(
      color: Colors.white.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Replying to', style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 12)),
                Container(
                  padding: EdgeInsets.all(0),
                  margin: EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                    color: Color.fromARGB(75, 255, 255, 255),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 36,
                        child:
                        Container(
                          width: 5,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: senderColor,
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(3), bottomLeft: Radius.circular(3)),
                          ),
                        ),
                      ),
                      SizedBox(width: 8), // Spacing between color bar and text
                      // Message content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              senderName,
                              style: TextStyle(fontWeight: FontWeight.bold, color: senderColor, fontSize: 14),
                            ),
                            Text(
                              repliedMessageContent,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, color: Color.fromARGB(200, 160, 120, 0)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.black.withOpacity(0.6)),
            onPressed: () {
              isReplyingModeNotifier.value = false;
              replyingMode = false;
              repliedMessageId = '';
              repliedMessageContent = '';
            },
          ),
        ],
      ),
    );
  }


  void _updateOldestVisibleMessage() {
    if (_visibleMessageTimestamps.isNotEmpty) {
      topMostMessageTime = ChatRoomState.getDateSeparatorText(_visibleMessageTimestamps.reduce((a, b) => a.toDate().isBefore(b.toDate()) ? a : b));
    } else {
      topMostMessageTime = "";
    }
  }

  void _sendFriendRequest() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add match as a friend"),
        content: Text("You can add this match as a friend by sending a friend request to them. This will let them know that you want to befriend them. It's important to know that your full identity and theirs will be revealed to each other after they accept your friend request.\n\nProceed to send friend request?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection('matches').doc(widget.recipientId).set({
                'friendRequest': true,
              }, SetOptions(merge: true));
              await NotificationManager.addFriendRequestNotification(currentUser?.id ?? 'UNKNOWN', widget.recipientId, widget.chatRoomId);
              Navigator.pop(context);
              setState(() {
                friendRequestSent = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Friend request sent")));
            },
            child: Text("Send"),
          ),
        ],
      ),
    );
  }

  void _friendInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("This person is your friend"),
        content: Text("Both of you will be able to see each other's full identity. You have previously matched with this person and both yourself and this person have agreed to become friend and reveal your identities.\n\nIf by any chance you want to remove this person as your friend, you can do so by pressing on the 'Remove Friend' option below.",),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmRemoveFriend();
            },
            child: Text("Remove Friend", style: TextStyle(color: Colors.red),),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
            },
            child: Text("Dismiss")
          ),
        ],
      ),
    );
  }

  void _confirmRemoveFriend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Remove friend"),
        content: Text("Are you sure you want to remove this person as a friend? This action is irreversible, and you would have to get matched with them again if you changed your mind.",),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Cancel"),
          ),
          ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                Navigator.pop(context);
                await DataManager.removeFriend(widget.recipientId, currentUser?.id);
                await NotificationManager.addRelationshipChangeNotification(currentUser?.id ?? 'UNKNOWN', widget.recipientId, 'friend', 'none', widget.chatRoomId, currentUser?.displayName ?? 'UNKNOWN NAME');
                await DataManager.removeChat(widget.chatRoomId);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Removed from friend list")));
              },
              child: Text("Confirm Removal"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveMatch() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Remove match"),
        content: Text("Are you sure you want to remove this person from your matches? This action is irreversible, and you would have to get matched with them again if you changed your mind.",),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context);
              await DataManager.removeMatch(widget.recipientId, currentUser?.id);
              await NotificationManager.addRelationshipChangeNotification(currentUser?.id ?? 'UNKNOWN', widget.recipientId, 'match', 'none', widget.chatRoomId, currentUser?.displayName ?? 'UNKNOWN NAME');
              await DataManager.removeChat(widget.chatRoomId);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Removed from match list")));
            },
            child: Text("Confirm Removal"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  void _acceptFriendRequest() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Accept friend request"),
        content: Text("If you choose to accept this friend request, this person will be added to your friend list, and both of your identity and theirs will be revealed to each other. \n\nProceed to accept request?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await DataManager.changeMatchToFriend(widget.chatRoomId, currentUser?.id, widget.recipientId);
              await NotificationManager.addRelationshipChangeNotification(currentUser?.id ?? 'UNKNOWN', widget.recipientId, 'match', 'friend', widget.chatRoomId, currentUser?.displayName ?? 'UNKNOWN NAME');
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatRoom(
                    chatRoomId: widget.chatRoomId,
                    recipientId: widget.recipientId,
                    chatRoomType: 'friend',
                  ),
                ),
              );
            },
            child: Text("Accept"),
          ),
        ],
      ),
    );
  }


  void _pendingFriendRequest() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Friend request pending"),
        content: Text("You have already sent a friend request to this match. Please kindly wait for them to accept in order to be friends and view their identity."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Dismiss"),
          ),
          ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser?.id)
                    .collection('matches')
                    .doc(widget.recipientId)
                    .update({
                  'friendRequest': FieldValue.delete(),
                });
                setState(() {
                  friendRequestSent = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Friend request has been withdrawn")));
              },
              child: Text("Withdraw Request")),
        ],
      ),
    );
  }


  void _sendTextMessage(){
    if(_messageController.text.trim().isNotEmpty){
      String content = _messageController.text.trim();
      _messageController.clear();
      _sendMessage('TEXT', content);
    }
  }

  void _sendReplyMessage(){
    if(_messageController.text.trim().isNotEmpty){
      String content = _messageController.text.trim();
      _messageController.clear();
      _sendMessage('REPLY', content);
    }

    isReplyingModeNotifier.value = false;
    repliedMessageId = '';
    repliedMessageContent = '';
    replyingMode = false;
  }

  Future<void> _sendImageMessage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    _isUploading.value = true;
    if (pickedFile != null) {
      XFile? xfile = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path,
        '${Path.dirname(pickedFile.path)}/${Path.basenameWithoutExtension(pickedFile.path)}_compressed.jpg',
        quality: 17,
      );

      File file = File(xfile!.path);

      Reference storageRef = FirebaseStorage.instance.ref().child('chat_attachments/images/${widget.chatRoomId}/${Path.basename(file.path)}');
      UploadTask uploadTask = storageRef.putFile(file);

      uploadTask.snapshotEvents.listen((snapshot) {
        _uploadProgress.value = snapshot.bytesTransferred.toDouble() / snapshot.totalBytes.toDouble();
      });

      TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
      String downloadURL = await snapshot.ref.getDownloadURL();

      _sendMessage('IMAGE', downloadURL);
    }
    _isUploading.value = false;
  }


  Future<void> _sendAudioMessage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    _isUploading.value = true;

    if (result != null) {
      File file = File(result.files.single.path!);

      double fileMbSize = file.lengthSync() / (1024 * 1024);
      String fileSizeInMB = '${fileMbSize.toStringAsFixed(1)} MB';

      if (file.lengthSync() > 4 * 1024 * 1024) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("File too large"),
              content: Text("The selected audio file (${fileSizeInMB}) exceeds the maximum allowed file size for audio (4 MB)."),
              actions: <Widget>[
                ElevatedButton(
                  child: Text("OK"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
        _isUploading.value = false;
        return;
      }

      Reference storageRef = FirebaseStorage.instance.ref().child('chat_attachments/audios/${widget.chatRoomId}/${Path.basename(file.path)}');
      UploadTask uploadTask = storageRef.putFile(file);

      uploadTask.snapshotEvents.listen((snapshot) {
        _uploadProgress.value = snapshot.bytesTransferred.toDouble() / snapshot.totalBytes.toDouble();
      });

      TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
      String downloadURL = await snapshot.ref.getDownloadURL();

      _sendMessage('AUDIO', downloadURL);
    }
    _isUploading.value = false;
  }


  Future<void> _sendVideoMessage() async {
    final pickedFile = await ImagePicker().pickVideo(source: ImageSource.gallery);
    _isUploading.value = true;
    if (pickedFile != null) {
      File file = File(pickedFile.path);
      File? compressedFile = await compressVideo(file);

      if (compressedFile == null) {
        _isUploading.value = false;
        return;
      }

      double fileMbSize = compressedFile.lengthSync() / (1024 * 1024);
      String fileSizeInMB = '${fileMbSize.toStringAsFixed(1)} MB';

      if (compressedFile.lengthSync() > 5.5 * 1024 * 1024) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("File too large"),
              content: Text("The compressed video file (${fileSizeInMB}) exceeds the maximum allowed file size (5.5 MB)."),
              actions: <Widget>[
                ElevatedButton(
                  child: Text("OK"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
        _isUploading.value = false;
        return;
      }

      Reference storageRef = FirebaseStorage.instance.ref().child('chat_attachments/videos/${widget.chatRoomId}/${Path.basename(compressedFile.path)}');
      UploadTask uploadTask = storageRef.putFile(compressedFile);

      uploadTask.snapshotEvents.listen((snapshot) {
        _uploadProgress.value = snapshot.bytesTransferred.toDouble() / snapshot.totalBytes.toDouble();
      });

      TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
      String downloadURL = await snapshot.ref.getDownloadURL();

      _sendMessage('VIDEO', downloadURL);
    }
    _isUploading.value = false;
  }


  Future<void> _sendVoiceNoteMessage() async {
    //TODO: Change this from FilePicker to display an overlay with a big button to start / stop recording voice note, uploads the audio and send the VOICE_NOTE message
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    _isUploading.value = true;

    if (result != null) {
      File file = File(result.files.single.path!);
      Reference storageRef = FirebaseStorage.instance.ref().child('chat_attachments/audios/${widget.chatRoomId}/${Path.basename(file.path)}');
      UploadTask uploadTask = storageRef.putFile(file);

      uploadTask.snapshotEvents.listen((snapshot) {
        _uploadProgress.value = snapshot.bytesTransferred.toDouble() / snapshot.totalBytes.toDouble();
      });

      TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
      String downloadURL = await snapshot.ref.getDownloadURL();

      _sendMessage('VOICE_NOTE', downloadURL);
    }
    _isUploading.value = false;
  }


  Future<File?> compressVideo(File videoFile) async {
    final MediaInfo? info = await VideoCompress.compressVideo(
      videoFile.path,
      quality: VideoQuality.LowQuality,
      deleteOrigin: false,
    );

    return info?.file;
  }

  void _sendMessage(String type, String content) {
    setState(() {
      _messageLimit += _messageLimitIncrement;
    });

    FirebaseFirestore.instance.collection('chats').doc(widget.chatRoomId).collection('messages').add({
      'content': content,
      'authorId': currentUser?.id,
      'timestamp': FieldValue.serverTimestamp(),
      'reads': [currentUser?.id],
      'messageType': type,
      'replyingTo': type == 'REPLY' ? repliedMessageId : null,
    }).then((DocumentReference messageRef) {
      _incrementUnreadCount();
      String gender = currentUser?.gender == 'male' ? 'Male' : 'Female';
      String? displayName = widget.chatRoomType == 'friend' ? currentUser?.displayName : '$gender, B${currentUser?.studentNumber?.substring(0, 2)}, ${currentUser?.major}';

      NotificationManager.addMessageNotification(messageRef.id, displayName ?? 'UNKNOWN', widget.recipientId, widget.chatRoomType, type == 'TEXT' || type == 'REPLY' ? content : '$displayName sent ${_getPreviewContentByTypeAndString(type, content)}', widget.chatRoomId, currentUser?.id ?? 'null');

      if (_scrollController.offset >= _scrollController.position.maxScrollExtent &&
          !_scrollController.position.outOfRange) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    if(widget.chatRoomType == 'match'){
      CollectionReference matches = FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection('matches');
      DocumentReference thisMatchDoc = matches.doc(widget.recipientId);
      thisMatchDoc.update({
        'lastMessageTimestamp': FieldValue.serverTimestamp()
      });

      CollectionReference rMatches = FirebaseFirestore.instance.collection('users').doc(widget.recipientId).collection('matches');
      DocumentReference rMatchDoc = rMatches.doc(currentUser?.id);
      rMatchDoc.update({
        'lastMessageTimestamp': FieldValue.serverTimestamp()
      });
    }else{
      CollectionReference friends = FirebaseFirestore.instance.collection('users').doc(currentUser?.id).collection('friends');
      DocumentReference thisFriendDoc = friends.doc(widget.recipientId);
      thisFriendDoc.update({
        'lastMessageTimestamp': FieldValue.serverTimestamp()
      });
      CollectionReference rFriends = FirebaseFirestore.instance.collection('users').doc(widget.recipientId).collection('friends');
      DocumentReference rFriendDoc = rFriends.doc(currentUser?.id);
      rFriendDoc.update({
        'lastMessageTimestamp': FieldValue.serverTimestamp()
      });
    }

  }

  Future<void> unsendMessage(QueryDocumentSnapshot message) async {
    DocumentReference messageRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatRoomId)
        .collection('messages')
        .doc(message.id);

    messageRef.update({'messageType': 'DELETED'}).then((_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Message unsent.")));
    }).catchError((error) {
      print("Failed to unsend message: $error");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to unsend message.")));
    });

    NotificationManager.unsendMessageNotification(currentUser?.id ?? 'Unknown', message.id);

    Navigator.pop(context);
  }

  void _incrementUnreadCount() async {
    var documentRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatRoomId).collection('unreadCounts').doc(widget.recipientId);
    await documentRef.set({
      'count': FieldValue.increment(1)
    }, SetOptions(merge: true));
  }

  void _resetUnreadCount() {
    FirebaseFirestore.instance.collection('chats').doc(widget.chatRoomId).collection('unreadCounts').doc(currentUser?.id).set({
      'count': 0
    });
  }

  static String getTimeString(Timestamp timestamp) {
    final requestTime = timestamp.toDate();
    return "${requestTime.hour.toString().padLeft(2, '0')}:${requestTime.minute.toString().padLeft(2, '0')}";
  }

  static String getDate(Timestamp timestamp) {
    final requestTime = timestamp.toDate();
    return "${requestTime.year}-${requestTime.month}-${requestTime.day}";
  }

  static String getDateSeparatorText(Timestamp timestamp) {
    final requestTime = timestamp.toDate();
    final currentTime = DateTime.now();
    final yesterday = currentTime.subtract(Duration(days: 1));

    if (currentTime.day == requestTime.day && currentTime.month == requestTime.month && currentTime.year == requestTime.year) {
      return 'Today';
    } else if (yesterday.day == requestTime.day && yesterday.month == requestTime.month && yesterday.year == requestTime.year) {
      return 'Yesterday';
    } else {
      return "${requestTime.day} ${DateFormat('MMMM').format(requestTime)} ${requestTime.year}";
    }
  }


  void _showRequestDetails(DocumentSnapshot recipient) {
    DocumentSnapshot candidate = recipient;

    bool isFriend = widget.chatRoomType == 'friend';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
            title: Card(
              color: Colors.black54,
              elevation: 2.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.0),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Text(
                  'Person Information',
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
                SizedBox(height: 5),
                if(!isFriend)
                  Image.asset('assets/unknown_avatar.png', width: 60, height: 60)
                else Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0),
                      image: DecorationImage(
                        image: NetworkImage(candidate['pictures']['default']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        candidate['gender'] == 'male' ? Icons.male : Icons.female,
                        color: candidate['gender'] == 'male' ? Colors.blue : Colors.pink,
                      ),
                      SizedBox(width: 5),
                      Text(candidate['gender'] == 'male' ? 'Male' : 'Female'),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                if(isFriend)
                  _buildOtherPicturesSubtitle(candidate),
                if(isFriend)
                  SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: Icon(Icons.help_outline),
                  label: Text('Relative Age Information'),
                  onPressed: () {
                    if (currentUser?.birthDate != null && candidate?['birthDate'] != null) {
                      DateTime currentUserBirthDate = DateTime.parse(currentUser?.birthDate ?? '1990-01-01T00:00:00');
                      DateTime candidateBirthDate = DateTime.parse(candidate?['birthDate'] ?? '1990-01-01T00:00:00');

                      int ageDifference = MatchmakePageState.calculateAgeDifference(currentUserBirthDate, candidateBirthDate);
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
                Text(!isFriend ? 'B${candidate['studentNumber'].substring(0, 2)}, ${candidate['major']} (${NicknameManager.getNickname(candidate.id, '-')}) ': '${candidate['name']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                if(isFriend)
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.black, fontFamily: GoogleFonts.quicksand().fontFamily),
                      children: [
                        TextSpan(text: 'BINUSIAN 20${candidate['studentNumber'].substring(0, 2)}, ' , style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '${candidate['major']}', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black, fontFamily: GoogleFonts.quicksand().fontFamily),
                    children: [
                      TextSpan(text: 'Campus location: '),
                      TextSpan(text: '${candidate['campus']}', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black, fontFamily: GoogleFonts.quicksand().fontFamily),
                    children: [
                      TextSpan(text: 'Religion: '),
                      TextSpan(text: '${candidate['religion']}', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          text: candidate['height'] == 'empty' ? 'Prefer not to say' : '${candidate['height']} cm',
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
                    child: SingleChildScrollView(child: Text('${candidate['description']}')),
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
                    children: DisplayUtils.displayInterests(candidate),
                  ),
                  ),
                ),
                SizedBox(height: 10),
                if(isFriend)
                  Text('Social Accounts'),
                if(isFriend)
                  FutureBuilder<List<SocialAccount>>(
                    future: DataManager.getSocialAccounts(candidate.id),
                    builder: (BuildContext context, AsyncSnapshot<List<SocialAccount>> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: SizedBox(height: 30, child: SpinKitWave(color: Colors.black54, duration: Duration(milliseconds: 200),)));
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (snapshot.hasData) {
                        return _buildSocialAccountsSection(snapshot.data!);
                      } else {
                        return Container();
                      }
                    },
                  )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSocialAccountsSection(List<SocialAccount> accounts) {
    if(accounts.isEmpty){
      return Container(
        height: 40,
        child: Center(child: Text('This person has not added any social accounts', style: TextStyle(fontSize: 11))),
      );
    }
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child:
        Wrap(
          spacing: 10.0,
          runSpacing: 10.0,
          children: accounts.map((account) => ProfileState.buildSocialAccountCard(context, account)).toList(),
        ),
    );
  }

  Widget _buildOtherPicturesSubtitle(DocumentSnapshot candidate) {
    List<String>? otherPictures = (candidate['pictures']['others'] as List?)?.cast<String>();

    if (otherPictures == null || otherPictures.isEmpty) {
      return Container(
        height: 80,
        child: Center(child: Text('This person has not added any other pictures', style: TextStyle(fontSize: 11))),
      );
    }

    return SizedBox(
      height: 150,
      width: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: otherPictures.length,
        itemBuilder: (BuildContext context, int index) {
          final imageUrl = otherPictures[index];
          if (imageUrl == null) return SizedBox.shrink();

          return GestureDetector(
            onTap: () => DisplayUtils.openImageDialog(context, otherPictures, index),
            child: Padding(
              padding: EdgeInsets.only(right: 12.0),
              child: FadeInImage.memoryNetwork(
                placeholder: kTransparentImage,
                image: imageUrl,
                height: 100,
                width: 100,
                fit: BoxFit.cover,
                imageErrorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                  return Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.white,
                      size: 50,
                    ),
                    alignment: Alignment.center,
                  );
                },
              ),
            ),
          );
        },
      ),
    );



    // return Row(
    //       children: ['https://picsum.photos/200/300', 'https://picsum.photos/400/300', 'https://picsum.photos/700/500', 'https://picsum.photos/400/900'].map((imageUrl) {
    //         if (imageUrl == null) return SizedBox.shrink();
    //
    //         return GestureDetector(
    //           onTap: () => DisplayUtils.openImageDialog(context, otherPictures, otherPictures.indexOf(imageUrl)),
    //           child: Padding(
    //             padding: EdgeInsets.only(right: 12.0),
    //             child: FadeInImage.memoryNetwork(
    //               placeholder: kTransparentImage,
    //               image: imageUrl,
    //               height: 100,
    //               width: 100,
    //               fit: BoxFit.cover,
    //               imageErrorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
    //                 return Container(
    //                   height: 100,
    //                   width: 100,
    //                   decoration: BoxDecoration(
    //                     color: Colors.black.withOpacity(0.5),
    //                     borderRadius: BorderRadius.circular(8),
    //                   ),
    //                   child: Icon(
    //                     Icons.image_outlined,
    //                     color: Colors.white,
    //                     size: 50,
    //                   ),
    //                   alignment: Alignment.center,
    //                 );
    //               },
    //             ),
    //           ),
    //         );
    //       }).toList(),
    //     );

  }

  Color _getSenderColor(QueryDocumentSnapshot message) {
    int hash = message['authorId'].hashCode;
    int r = (hash & 0xFF0000) >> 16;
    int g = (hash & 0x00FF00) >> 8;
    int b = (hash & 0x0000FF);
    return Color.fromARGB(255, r, g, b);
  }

  String _getRepliedSenderName(QueryDocumentSnapshot repliedMessage) {
    if (currentUser?.id == repliedMessage['authorId']) {
      return 'You';
    } else if (widget.chatRoomType == 'match') {
      return 'Your match';
    } else {
      return formatName(user['name']);
    }
  }

  static String formatName(String name) {
    List<String> parts = name.split(' ');
    if (parts.length == 1) {
      return parts[0].capitalizeFirstLowerElse;
    }

    String formattedName = parts[0].capitalizeFirstLowerElse;

    for (int i = 1; i < parts.length; i++) {
      formattedName += ' ' + parts[i][0].toUpperCase() + '.';
    }

    return formattedName;
  }
}