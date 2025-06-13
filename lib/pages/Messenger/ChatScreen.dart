import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:task_management/main.dart';
import 'package:task_management/pages/Messenger/imageViewer.dart';
import 'package:task_management/pages/Messenger/videoPlayer.dart';
import 'package:task_management/resources/localDBHelper.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:task_management/resources/model/chatListModal.dart';
import 'package:task_management/resources/model/chatMessageModal.dart';
import 'package:task_management/utils/MeasureSize.dart';
import 'package:task_management/utils/network_utils.dart';
import 'package:task_management/utils/permissionHandler.dart';
import 'package:task_management/utils/socket_service.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatScreen extends StatefulWidget {
  final String chatID;
  final String chatName;
  final String receiverUserID;
  final String chatType;

  const ChatScreen({
    super.key,
    required this.chatID,
    required this.chatName,
    required this.receiverUserID,
    required this.chatType,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
  // _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final client = http.Client();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SocketService socketService = SocketService();
  late AppLifecycleState _appState = AppLifecycleState.resumed;
  List<dynamic> users = [];
  TextEditingController _searchController = TextEditingController();
  String? selectedUserID;
  final ImagePicker _imagePicker = ImagePicker();
  Map<String, GlobalKey> _messageKeys = {};
  Map<String, int> messageIndexMap = {};
  List<Map<String, dynamic>> messages = [];
  String? _highlightedMessageID;
  int page = 1;
  bool isLoading = false;
  int pageCounter = 1; // Initial page
  bool hasMore = true; // Track if more messages are available
  bool isFirstLoaded = false; // Track if more messages are available
  String selectedChatType = 'private';
  String _replyingToText = "";
  String _replyingToID = "";
  String currentUserID = '';
  String accessToken = '';
  String baseURL = dotenv.get('HOST');
  Map<String, double> messageHeights = {};
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadUser();
    socketService.joinRooms(
      userID: currentUserID,
      chatIDs: [widget.chatID],
      isChat: true,
    );

    _scrollController.addListener(_scrollListener);
    socketService.onNewMessage((data) async {
      final newMsg = ChatMessage.fromMap(data);
      debugPrint('📥 New message from socket: $data');
      await ChatDatabase.instance.insertMessage(newMsg);
      final chatList = await ChatDatabase.instance.getChatListByChatID(
        newMsg.chatID,
      );

      await ChatDatabase.instance.updateChat(
        ChatList(
          chatName: chatList.chatName,
          chatType: chatList.chatType,
          receiverUserID: chatList.receiverUserID,
          chatID: chatList.chatID,
          recentMessage: newMsg.message,
          recentMessageTimestamp: newMsg.timestamp,
        ),
      );

      final isSameChat = data['chatID'] == widget.chatID;
      debugPrint("isAppInBackground $isAppInBackground");
      debugPrint("isSameChat $isSameChat");
      // 🎯 Show notification if app is in background or not the current chat
      if (isAppInBackground || !isSameChat) {
        showLocalNotification(newMsg); // You’ll define this method
        return;
      }

      // if (data['chatID'] != widget.chatID) return;
      debugPrint("👀Looking this msg: ${newMsg.message} ");
      if (!mounted) return;
      setState(() {
        messages.insert(0, data);
      });

      socketService.seenThisMessage(
        userID: currentUserID,
        chatID: widget.chatID,
        messageID: newMsg.messageID,
      );

      await ChatDatabase.instance.updateMessageReedAllPrevious(
        newMsg.messageID,
        widget.chatID,
      );
      if (!mounted) return;
      // Find message by messageID and mark as read
      try {
        setState(() {
          messages = messages.where((msg) => msg != null).toList();
          messages =
              messages.where((msg) => msg != null).map((msg) {
                if (msg['messageID'] == newMsg.messageID) {
                  msg['isRead'] = 1;
                }
                return msg;
              }).toList();
        });
      } catch (e) {
        debugPrint(e.toString());
      }

      // Scroll to bottom on new message
      Future.delayed(Duration(milliseconds: 200), () {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        }
      });
    });

    socketService.onMessageSeen((data) async {
      final messageID = data['messageID'];
      await ChatDatabase.instance.updateMessageSeenStatus(messageID);
      // update message seen status
      if (!mounted) return;
      setState(() {
        if (messages.isNotEmpty) {
          messages =
              messages.map((msg) {
                if (msg['messageID'] == messageID) {
                  if (msg != null && msg['messageID'] == messageID) {
                    msg['isRead'] = 1;
                  }
                }
                return msg;
              }).toList();
        }
      });
    });

    socketService.onMessageReadAll((data) async {
      debugPrint('🤖😍🤖😍 Message seen from socket2: $data');
      // messageID, chatID, userID

      await ChatDatabase.instance.updateMessageReedAllPrevious(
        data['messageID'],
        data['chatID'],
      );
      if (!mounted) return;
      setState(() {
        if (messages.isNotEmpty) {
          messages = messages.where((msg) => msg != null).toList();
          messages =
              messages.where((msg) => msg != null).map((msg) {
                if (msg['messageID'] == data['messageID']) {
                  msg['isRead'] = 1;
                }
                return msg;
              }).toList();
          // messages =
          // messages.map((msg) {
          //   if (msg != null) {
          //     msg['isRead'] = 1;
          //   }
          // }).toList();
        }
        ;
      });
    });
  }

  void openFile(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not open file $url';
    }
  }

  Future<void> saveFile(String url) async {
    try {
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) return;

      final saved = await SaverGallery.saveFile(
        filePath: url,
        skipIfExists: true,
        fileName: "task_chat_file_${DateTime.now().millisecondsSinceEpoch}",
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved.isSuccess ? "File saved" : "Failed to save file"),
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to save file")));
    }
  }

  void showLocalNotification(ChatMessage message) {
    flutterLocalNotificationsPlugin.show(
      message.timestamp.hashCode,
      "New MessageChat",
      message.message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_channel',
          'Chat Messages',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.toMap()),
    );
    // flutterLocalNotificationsPlugin.cancelAll();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appState = state;
    debugPrint(
      '🌀 App lifecycle changed: $_appState is Background $isAppInBackground',
    );
  }

  bool get isAppInBackground => _appState != AppLifecycleState.resumed;

  Future<void> loadUser() async {
    accessToken = await localStorage.getString('accessToken') ?? '';
    final Map<String, dynamic> userData = jsonDecode(
      jsonEncode(localStorage.getObject('userData') ?? {}),
    );
    currentUserID = userData['userID'];

    if (await NetworkUtils.hasInternetConnection()) {
      await loadFirst();
      await _loadLocalMessages();
    } else {
      debugPrint("currentUserID: $currentUserID");
      await _loadLocalMessages();
    }
    // await ChatDatabase.instance.deleteMessagesByChatID(widget.chatID);
    // fetchMessages();
  }

  Future<void> _loadLocalMessages() async {
    final localMsgs = await ChatDatabase.instance.getMessagesByChatID(
      widget.chatID,
    );

    debugPrint("ChatDatabase.instance: ${widget.chatID}");
    debugPrint("localMsgs $localMsgs");
    final localMaps =
        localMsgs.map((msg) => msg.toMap()).toList().reversed.toList();

    setState(() {
      messages = localMaps;
    });

    // const LatestMsgRecieved = //Filter By senderID if Its not currentUserID pick the latest message by its timestamp

    var latestMsgRecieved =
        localMsgs
            .where((msg) => msg.senderID != currentUserID)
            .toList()
            .lastOrNull;

    debugPrint("\n\nlocalMsgs\n\n");
    debugPrint(latestMsgRecieved?.message);
    debugPrint("\n\nlocalMsgs\n\n");

    // Send trigger to socket msg Readed
    if (latestMsgRecieved != null && latestMsgRecieved.isRead == 0) {
      socketService.readMessage(
        userID: currentUserID,
        chatID: widget.chatID,
        messageID: latestMsgRecieved.messageID,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
      }
    });
  }

  String _formatTime(String timeStr) {
    bool isSameDay(DateTime d1, DateTime d2) {
      return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
    }

    bool isYesterday(DateTime d1, DateTime now) {
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      return d1.year == yesterday.year &&
          d1.month == yesterday.month &&
          d1.day == yesterday.day;
    }

    bool isSameWeek(DateTime d1, DateTime d2) {
      final startOfWeek = d2.subtract(Duration(days: d2.weekday % 7));
      final endOfWeek = startOfWeek.add(Duration(days: 6));
      return d1.isAfter(startOfWeek) &&
          d1.isBefore(endOfWeek.add(Duration(days: 1)));
    }

    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inSeconds < 60) {
        return '${difference.inSeconds} sec ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (isSameDay(dt, now)) {
        return DateFormat('h:mma').format(dt).toLowerCase();
      } else if (isYesterday(dt, now)) {
        return 'Yesterday ${DateFormat('h:mma').format(dt).toLowerCase()}';
      } else if (isSameWeek(dt, now)) {
        return DateFormat('EEEE h:mma').format(dt).toLowerCase();
      } else {
        return DateFormat('d MMM y h:mma').format(dt).toLowerCase();
      }
    } catch (e) {
      return '';
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      // fetchMessages();
    }
  }

  Future<void> loadFirst() async {
    setState(() => isLoading = true);
    if (isFirstLoaded) return;
    final response = await client.get(
      Uri.https(baseURL, '/api/v1/chats/get-messages/${widget.chatID}', {
        'page': '1',
        'limit': '15',
        'order': 'DESC',
      }),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newMessages =
          (data['data'] as List)
              .map((e) => e as Map<String, dynamic>)
              .toList()
              .reversed
              .toList(); // Reverse to get oldest to newest

      if (newMessages.isNotEmpty) {
        for (var msg in newMessages) {
          final chatMessage = ChatMessage.fromMap(msg);
          await ChatDatabase.instance.insertMessage(chatMessage);
        }

        final messagesFromDb = await ChatDatabase.instance.getMessagesByChatID(
          widget.chatID,
        );

        final messageMaps =
            messagesFromDb.map((msg) => msg.toMap()).toList().reversed.toList();

        setState(() {
          messages.insertAll(0, messageMaps);
        });

        if (data['data'][data['data'].length - 1]['haveMore'] == true) {
          setState(() {
            hasMore = true;
          });
        }
      }
      //Filter By senderID if Its not currentUserID pick the latest message by its timestampFormSender THEN emmit Read all if its not readed
      var latestMessageFromSender =
          messages
              .where((msg) => msg['senderID'] == widget.receiverUserID)
              .toList();
      final latestMsgRecieved =
          latestMessageFromSender.isNotEmpty
              ? latestMessageFromSender.first
              : null;
      if (latestMsgRecieved != null && latestMsgRecieved['isRead'] == 0) {
        socketService.readMessage(
          userID: currentUserID,
          chatID: widget.chatID,
          messageID: latestMsgRecieved['messageID'],
        );
      }
      isFirstLoaded = true;
      setState(() => isLoading = false);
    }
  }

  Future<void> syncMessages() async {
    if (isLoading || !hasMore) return;

    setState(() {
      isLoading = true;
      messages = [];
    });

    final currentPage = pageCounter;

    final response = await client.get(
      Uri.https(baseURL, '/api/v1/chats/get-messages/${widget.chatID}', {
        'page': '$currentPage',
        'limit': '20',
      }),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newMessages =
          (data['data'] as List).map((e) => e as Map<String, dynamic>).toList();

      if (newMessages.isNotEmpty) {
        // Insert new messages into DB
        for (var msg in newMessages) {
          final chatMessage = ChatMessage.fromMap(msg);
          await ChatDatabase.instance.insertMessage(chatMessage);
        }

        debugPrint(
          "apiHasMore: ${data['data'][data['data'].length - 1]['haveMore']}",
        );
        final bool apiHasMore =
            data['data'][data['data'].length - 1]['haveMore'] ?? false;
        if (apiHasMore) {
          pageCounter++; // Only increment if more pages exist
          hasMore = true;
          isLoading = false;
          syncMessages();
          return;
        } else {
          hasMore = false;
        }
      } else {
        hasMore = false;
      }
    } else {
      debugPrint('Error fetching messages: ${response.body}');
    }
    final localMsgs = await ChatDatabase.instance.getMessagesByChatID(
      widget.chatID,
    );

    final localMaps =
        localMsgs.map((msg) => msg.toMap()).toList().reversed.toList();

    setState(() {
      messages = localMaps;
    });
    setState(() => isLoading = false);
  }

  Future<void> sendMessage({
    required String message_,
    required String type,
  }) async {
    final message =
        message_.trim().isNotEmpty
            ? message_.trim()
            : _messageController.text.trim();
    if (message.isEmpty) return;

    String cacheKey = "chat_${widget.chatID}";

    if (await NetworkUtils.hasInternetConnection()) {
      try {
        final response = await client.post(
          Uri.https(baseURL, '/api/v1/chats/send-message'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            'chatID': widget.chatID,
            'senderID': currentUserID,
            'receiverID': widget.receiverUserID,
            'message': message,
            'messageType': type.isEmpty ? 'text' : type,
          }),
        );

        if (response.statusCode == 200) {
          _messageController.clear();
          var newMsg = jsonDecode(response.body)['data'][0];
          final chatMessage = ChatMessage.fromMap(newMsg);
          await ChatDatabase.instance.insertMessage(chatMessage);

          setState(() {
            messages.insert(0, newMsg);
          });

          socketService.socket.emit('sendMessage', newMsg);

          // Scroll to bottom
          Future.delayed(Duration(milliseconds: 100), () {
            _scrollController.jumpTo(
              _scrollController.position.minScrollExtent,
            );
          });
        } else {
          debugPrint('Error sending message: ${response.body}');
        }
      } catch (e) {
        debugPrint('Error sending message: $e');
      }
    } else {
      // create Queued message and send when connected
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No internet connection')));
    }
  }

  Widget _buildImageBubble(String url) {
    return GestureDetector(
      onTap: () => openFullImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 200,
          fit: BoxFit.cover,
          placeholder:
              (context, url) => Container(
                width: 200,
                height: 120,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              ),
          errorWidget:
              (context, url, error) => Container(
                color: Colors.grey.shade300,
                width: 200,
                height: 120,
                child: const Center(child: Icon(Icons.broken_image)),
              ),
        ),
      ),
    );
  }

  Widget _buildVideoBubble(String videoUrl) {
    return GestureDetector(
      onTap:
          () => showGeneralDialog(
            context: context,
            barrierDismissible: true,
            barrierLabel: "Video",
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder:
                (ctx, anim1, anim2) =>
                    Center(child: VideoPlayerWidget(videoUrl: videoUrl)),
            transitionBuilder: (_, anim, __, child) {
              return FadeTransition(opacity: anim, child: child);
            },
          ),
      child: Container(
        width: 200,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.play_circle_fill, size: 50, color: Colors.blue),
        ),
      ),
    );
  }

  Widget _buildFileBubble(String fileUrl, String path, String fileType) {
    final fileName = path.split('/').last;

    return GestureDetector(
      onTap:
          () async => {
            await canLaunchUrl(Uri.parse(fileUrl))
                ? await launchUrl(Uri.parse(fileUrl))
                : Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 80, color: Colors.red),
                        const SizedBox(height: 20),
                        Text(
                          'File not found',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName.isNotEmpty ? fileName : "Fetching file...",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    fileType.isNotEmpty ? fileType : "unknown",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.download_rounded, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBubble(
    String text,
    bool isMe,
    String timeText,
    bool isSeen,
  ) {
    // Step 1: Extract reply text if present
    String replyTo = "";
    String? replyToMessageID;
    String mainText = text;

    // final replyRegex = RegExp(r'<reply>(.*?)<\/reply>', dotAll: true);
    final replyRegex = RegExp(
      r'<reply(?: messageID="(.*?)")?>(.*?)<\/reply>',
      dotAll: true,
    );
    final match = replyRegex.firstMatch(text);
    if (match != null) {
      replyToMessageID = match.group(1); // group(1) = messageID (optional)
      replyTo = match.group(2)!.trim(); // group(2) = actual reply text
      mainText = text.replaceFirst(replyRegex, '').trim();
    }

    // Step 2: Process links in main message
    final linkRegex = RegExp(r'((https?:\/\/|www\.)[^\s]+)');
    final spans = <TextSpan>[];

    mainText.splitMapJoin(
      linkRegex,
      onMatch: (match) {
        final url = match.group(0)!;
        spans.add(
          TextSpan(
            text: url,
            style: TextStyle(
              color: isMe ? Color.fromARGB(255, 198, 255, 200) : Colors.blue,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () async {
                    final uri = Uri.parse(
                      url.toLowerCase().startsWith('http')
                          ? url
                          : 'https://$url',
                    );
                    if (await canLaunchUrl(uri)) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Could not open link")),
                      );
                    }
                  },
          ),
        );
        return '';
      },
      onNonMatch: (str) {
        spans.add(TextSpan(text: str));
        return '';
      },
    );

    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (replyTo.isNotEmpty)
          GestureDetector(
            onTap: () {
              debugPrint(" replyToMessageID: $replyToMessageID");
              // debugPrint(messageKeys);
              if (replyToMessageID != null) {
                scrollToMessage(replyToMessageID);
              }
            },

            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              width:
                  replyTo.length < 40
                      ? MediaQuery.of(context).size.width * 0.2
                      : MediaQuery.of(context).size.width * 0.7,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isMe ? Colors.white12 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                replyTo.length > 50 ? replyTo.substring(0, 50) : replyTo,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: isMe ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ),
        RichText(
          text: TextSpan(
            children: spans,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeText,
              style: TextStyle(
                fontSize: 11,
                color: isMe ? Colors.white70 : Colors.grey,
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 5),
              Icon(
                isSeen ? Icons.done_all_rounded : Icons.done_rounded,
                size: 16,
                color: isSeen ? Colors.blue.shade900 : Colors.white70,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Map message, bool isMe, GlobalKey key) {
    final String messageText = message['message'] ?? '';
    final String timeText = _formatTime(message['timestamp']);
    final bool isSeen = message['isRead'] > 0;

    final String fullUrl =
        messageText.startsWith('http')
            ? messageText
            : 'https://$baseURL$messageText';

    final mimeType = lookupMimeType(messageText);

    final mimeMainType = mimeType?.split('/').first ?? '';
    final mimeSubType = mimeType?.split('/').last ?? '';

    String contentType;
    if (mimeMainType == 'image') {
      contentType = 'image';
    } else if (mimeMainType == 'video') {
      contentType = 'video';
    } else if (mimeType == 'text/csv' ||
        mimeMainType == 'application' ||
        mimeMainType == 'text') {
      contentType = 'file';
    } else {
      contentType = 'text';
    }
    // Check If have Extention .pdf,doc etc then its type of file;
    debugPrint("mimeType: ${mimeType?.split('/').first} messageText:");
    final type =
        mimeType?.split('/').first == null
            ? 'text'
            : mimeType?.split('/').first ?? 'text';

    String? replyTo;
    String actualMessage = messageText;
    final replyRegex = RegExp(
      r'<reply(?: messageID="(.*?)")?>(.*?)<\/reply>',
      dotAll: true,
    );
    final match = replyRegex.firstMatch(messageText);

    if (match != null) {
      replyTo = match.group(1)?.trim();
      actualMessage = messageText.replaceFirst(replyRegex, '').trim();
    }

    late final Widget content;

    switch (contentType) {
      case 'image':
        content = _buildImageBubble(fullUrl);
        break;
      case 'video':
        content = _buildVideoBubble(fullUrl);
        break;
      case 'file':
        content = _buildFileBubble(fullUrl, messageText, mimeType ?? 'unknown');
        break;
      default:
        content = _buildTextBubble(messageText, isMe, timeText, isSeen);
    }

    void showMessageOptions() {
      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        builder: (_) {
          return SafeArea(
            child: MeasureSize(
              onChange: (size) {
                debugPrint("size: $size");
                if (size != null) {
                  messageHeights['messageID'] = size.height;
                }
              },
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.copy),
                    title: const Text('Copy'),
                    onTap: () {
                      Navigator.pop(context);
                      if (replyTo != null) {
                        Clipboard.setData(ClipboardData(text: actualMessage));
                      } else {
                        Clipboard.setData(ClipboardData(text: messageText));
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Message copied")),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.reply),
                    title: const Text('Reply'),
                    onTap: () {
                      Navigator.pop(context);
                      // Call your reply function here
                      if (replyTo != null) {
                        _startReplyingToMessage(
                          actualMessage,
                          message['messageID'],
                        );
                      } else {
                        _startReplyingToMessage(
                          messageText,
                          message['messageID'],
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.cancel),
                    title: const Text('Cancel'),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final isHighlighted = message['messageID'] == _highlightedMessageID;

    return GestureDetector(
      onLongPress: showMessageOptions,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          padding:
              contentType == 'text'
                  ? EdgeInsets.symmetric(vertical: 12, horizontal: 16)
                  : EdgeInsets.all(0),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            gradient:
                isMe
                    ? LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    )
                    : LinearGradient(
                      colors: [Colors.grey.shade300, Colors.grey.shade100],
                    ),
            border:
                isHighlighted
                    ? Border.all(color: Colors.amberAccent, width: 2)
                    : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
            ),
          ),
          child: content,
        ),
      ),
    );
  }

  void scrollToMessage(String messageID) {
    double position = 0;

    debugPrint("messages HEIGHT: ${messageHeights['messageID']} ");
    for (final msg in messages) {
      final id = msg['messageID'];
      if (id == messageID) break;
      position += messageHeights[id] ?? 100.0; // fallback estimate
    }

    _scrollController.animateTo(
      position,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );

    setState(() => _highlightedMessageID = messageID);

    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _highlightedMessageID = null);
    });
  }

  void _startReplyingToMessage(String msg, String msgID) {
    setState(() {
      _replyingToText = msg;
      _replyingToID = msgID;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToText = "";
      _replyingToID = "";
    });
  }

  Future<void> _addMemberToGroup(String userID) async {
    final accessToken = await localStorage.getString('accessToken');
    final baseURL = dotenv.get('HOST');

    try {
      final response = await client.post(
        Uri.https(baseURL, '/api/v1/chats/add-to-group'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'chatID': widget.chatID, 'userID': userID}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User added to group')));
      } else {
        debugPrint('Add member failed: ${response.body}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: ${response.body}')));
      }
    } catch (e) {
      debugPrint('Add member error: $e');
    }
  }

  void _showAddMemberDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add member to group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  await searchUsers(textEditingValue.text);
                  return users.map((user) {
                    return '${user['userFirstName']} ${user['userSurname'] ?? ''} (${user['userAddressLine2'] ?? ''})';
                  }).toList();
                },
                onSelected: (String value) {
                  final selectedUser = users.firstWhere(
                    (u) =>
                        '${u['userFirstName']} ${u['userSurname'] ?? ''} (${u['userAddressLine2'] ?? ''})' ==
                        value,
                  );
                  selectedUserID = selectedUser['userID'];
                },
                fieldViewBuilder: (
                  context,
                  controller,
                  focusNode,
                  onFieldSubmitted,
                ) {
                  _searchController = controller;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Search user...',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedUserID != null) {
                  _addMemberToGroup(selectedUserID!);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> searchUsers(String search) async {
    final accessToken = await localStorage.getString('accessToken');
    final baseURL = dotenv.get('HOST');

    try {
      final response = await client.get(
        Uri.https(baseURL, '/api/v1/users/allUsers', {'search': search}),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          users = data['data']; // Ensure data is a list of user objects
        });
      } else {
        debugPrint('Failed to load users: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera),
                  title: const Text("Click Now"),
                  onTap: () {
                    Navigator.pop(context);
                    _showCameraOptions();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text("Select from Gallery"),
                  onTap: () {
                    Navigator.pop(context);
                    _showGalleryPicker();
                  },
                ),
                // File picker
                ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: const Text("Attach File"),
                  onTap: () {
                    Navigator.pop(context);
                    _showAllFilesPicker();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text("Cancel"),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showCameraOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text("Capture Photo"),
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await _imagePicker.pickImage(
                      source: ImageSource.camera,
                    );
                    if (pickedFile != null) {
                      await uploadFilesAndSendMessages([
                        File(pickedFile.path),
                      ], currentUserID);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.videocam),
                  title: const Text("Record Video"),
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await _imagePicker.pickVideo(
                      source: ImageSource.camera,
                    );
                    if (pickedFile != null) {
                      await uploadFilesAndSendMessages([
                        File(pickedFile.path),
                      ], currentUserID);
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showGalleryPicker() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );

    if (result != null && result.files.isNotEmpty) {
      final files = result.paths.map((path) => File(path!)).toList();
      await uploadFilesAndSendMessages(files, currentUserID);
    } else {
      debugPrint('No files selected.');
    }
  }

  void _showAllFilesPicker() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      final files = result.paths.map((path) => File(path!)).toList();
      await uploadFilesAndSendMessages(files, currentUserID);
    } else {
      debugPrint('No files selected.');
    }
  }

  Future<void> uploadFilesAndSendMessages(
    List<File> files,
    String userID,
  ) async {
    setState(() => isLoading = true);
    try {
      final uri = Uri.https(baseURL, '/api/v1/uploads/uploads');
      final request = http.MultipartRequest('POST', uri)
        ..fields['userID'] = userID;

      for (File file in files) {
        final mimeType =
            lookupMimeType(file.path) ?? 'application/octet-stream';
        final split = mimeType.split('/');
        final mediaType =
            (split.length == 2)
                ? MediaType(split[0], split[1])
                : MediaType('application', 'octet-stream');
        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            file.path,
            contentType: mediaType,
          ),
        );
      }

      request.headers['Authorization'] = 'Bearer $accessToken';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> filePaths = data['filePaths'];

        for (String filePath in filePaths) {
          final fileType = lookupMimeType(filePath)?.split('/')[0] ?? 'file';
          final messageType =
              (fileType == 'image')
                  ? 'image'
                  : (fileType == 'video')
                  ? 'video'
                  : 'file';

          await sendMessage(message_: filePath, type: messageType);
        }
      } else {
        debugPrint('File upload failed: ${response.body}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error uploading files: $e');
      return;
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    String? currentPath;
    navigatorKey.currentState?.popUntil((route) {
      currentPath = route.settings.name;
      return true;
    });
    String messageToSend = "";
    // debugPrint("👉👉👉 currentRoute: $currentPath");
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 5),
      curve: Curves.easeInOut,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child:
                    widget.chatType == "private"
                        ? CircleAvatar(
                          backgroundColor: Colors.black26,
                          radius: 22.0,
                          child: CircleAvatar(
                            backgroundColor: ThemeData().colorScheme.primary,
                            radius: 20.0,
                            child: Text(
                              // widget.chatName.substring(0, 1).toUpperCase(),
                              widget.chatName != null
                                  ? widget.chatName.split(' ').length > 1
                                      ? widget.chatName.split(' ')[0][0] +
                                          widget.chatName.split(' ')[1][0]
                                      : widget.chatName.split(' ')[0][0]
                                  : 'U',
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                                color: ThemeData().colorScheme.onSecondary,
                                shadows: [
                                  Shadow(
                                    color: ThemeData().colorScheme.onSurface,
                                    offset: Offset(0.5, 0.5),
                                    blurRadius: 10.0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        : CircleAvatar(
                          backgroundColor: Colors.black26,
                          radius: 23.0,
                          child: CircleAvatar(
                            backgroundColor:
                                Colors.blue, // You can customize the color~
                            child: Icon(
                              Icons.group_sharp, // Profile icon
                              color: Colors.white,
                            ),
                          ),
                        ),
              ),
              Text(
                widget.chatName.length > 16
                    ? "${widget.chatName.substring(0, 16)}..."
                    : widget.chatName,
              ),
            ],
          ),
          actions: <Widget>[
            PopupMenuButton<String>(
              onSelected: (String choice) {
                if (choice == 'Sync older Chats') {
                  // Handle logout action
                  syncMessages();
                } else if (choice == 'Settings') {
                  // Show snackbar not implimented
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings not implimented')),
                  );
                } else if (choice == 'clear all chats') {
                  ChatDatabase.instance.deleteAllMessagesByChatID(
                    widget.chatID,
                  );
                  setState(() {
                    messages = [];
                  });
                } else if (choice == 'Add member to group') {
                  _showAddMemberDialog(context);
                }
              },
              itemBuilder: (BuildContext context) {
                final items = <String>[
                  'Sync older Chats',
                  'Settings',
                  'clear all chats',
                ];

                if (widget.chatType == 'group') {
                  items.add('Add member to group');
                }

                return items.map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Flexible(
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];

                    if (message == null) return const SizedBox.shrink();
                    final isMe = message['senderID'] == currentUserID;
                    final key = GlobalKey();
                    _messageKeys[message["messageID"]!] = key;
                    return _buildMessageBubble(message, isMe, key);
                  },
                ),
              ),
              isLoading ? const LinearProgressIndicator() : const SizedBox(),
              if (_replyingToText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.reply, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Replying to : ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),

                      Expanded(
                        child: Text(
                          _replyingToText,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _cancelReply,
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Camera icon
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: IconButton(
                        icon: Icon(
                          Icons.camera_alt_outlined,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onPressed: () {
                          _showImageOptions();
                        },
                      ),
                    ),

                    // Text input
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color:
                              Theme.of(
                                context,
                              ).inputDecorationTheme.fillColor ??
                              Theme.of(context).cardColor.withOpacity(0.9),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.05),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: Theme.of(context).hintColor,
                            ),
                            border: InputBorder.none,
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                          minLines: 1,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Send button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.blue,
                        child: IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed:
                              () => {
                                if (_replyingToText.isNotEmpty)
                                  {
                                    messageToSend =
                                        "<reply messageID=\"$_replyingToID\">$_replyingToText</reply>${_messageController.text}",
                                    sendMessage(
                                      message_: messageToSend,
                                      type: 'text',
                                    ),
                                    _cancelReply(),
                                  }
                                else
                                  {
                                    sendMessage(
                                      message_: _messageController.text,
                                      type: 'text',
                                    ),
                                  },
                                // sendMessage(
                                //   message_: _messageController.text,
                                //   type: 'text',
                                // ),
                                // _cancelReply(),
                              },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    socketService.socket.off('newMessage');
    // socketService.dispose(currentUserID); // Dispose the socket connection
    super.dispose();
  }
}
