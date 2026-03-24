import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:http/http.dart' as http; 
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:open_filex/open_filex.dart'; 

import 'package:studently/models/chat.dart';
import 'package:studently/repositories/chat.dart';
import 'package:studently/services/socket.dart'; 
import 'package:studently/services/firebase_auth.dart'; 
import 'package:studently/logger.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserId; 
  final String otherUserName; 

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    this.otherUserName = "Chat",
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color blue = const Color(0xFF1976D2);

  List<ChatMessage> _messages = [];
  StreamSubscription? _socketSubscription; 
  bool _isLoading = true;

  bool _isTyping = false;
  bool _isRecording = false;
  bool _isUploading = false;
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  Timer? _recordTimer;
  int _recordDuration = 0;

  final Set<String> _downloadingUrls = {}; 

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    
    ChatRepository().markChatAsRead(widget.conversationId);

    _messageController.addListener(() {
      setState(() {
        _isTyping = _messageController.text.trim().isNotEmpty;
      });
    });

    _socketSubscription = socketService.stream?.listen((event) {
      final payload = jsonDecode(event);
      if (payload['type'] == 'NEW_MESSAGE' && 
          payload['data']['conversation_id'] == widget.conversationId) {
        _fetchMessages(isBackgroundRefresh: true);
        ChatRepository().markChatAsRead(widget.conversationId);
      }
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel(); 
    _messageController.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool isBackgroundRefresh = false}) async {
    try {
      final messages = await ChatRepository().getMessages(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages = messages;
          if (!isBackgroundRefresh) _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Error loading messages: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- Interaction Logic ---

  Future<void> _pickAndUploadFile() async {
    logger.i('ChatPage: User tapped attachment icon'); 
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.media, withData: true);
    
    if (result != null) {
      setState(() => _isUploading = true);
      
      final platformFile = result.files.single;
      List<int>? fileBytes;
      
      if (kIsWeb) {
        fileBytes = platformFile.bytes;
      } else {
        fileBytes = await File(platformFile.path!).readAsBytes();
      }
      
      if (fileBytes != null) {
        String? url = await ChatRepository().uploadAttachment(fileBytes, platformFile.name);
        
        if (url != null) {
          await ChatRepository().sendMessage(
            conversationId: widget.conversationId,
            text: "", 
            attachments: [url],
          );
          _fetchMessages(isBackgroundRefresh: true);
          _scrollToBottom();
        }
      }
      setState(() => _isUploading = false);
    }
  }

  String _formatRecordDuration() {
    final minutes = (_recordDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordDuration % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final Directory tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      logger.i('ChatPage: Started recording to $path');
      await _audioRecorder.start(const RecordConfig(), path: path);
      
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordDuration++);
      });

    } else {
      logger.e('ChatPage: Mic permission denied.');
    }
  }

  Future<void> _stopAndUploadRecording() async {
    logger.i('ChatPage: Stopped recording.');
    _recordTimer?.cancel();
    final String? path = await _audioRecorder.stop();
    
    setState(() {
      _isRecording = false;
      _recordDuration = 0;
    });
    
    if (path != null) {
      setState(() => _isUploading = true);
      
      List<int> audioBytes;
      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        audioBytes = response.bodyBytes;
      } else {
        audioBytes = await File(path).readAsBytes();
      }

      String? url = await ChatRepository().uploadAttachment(audioBytes, 'voice_message.m4a');
      
      if (url != null) {
        await ChatRepository().sendMessage(
          conversationId: widget.conversationId,
          text: "🎤 Voice Message",
          attachments: [url],
        );
        _fetchMessages(isBackgroundRefresh: true);
        _scrollToBottom();
      }
      setState(() => _isUploading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    try {
      await ChatRepository().sendMessage(
        conversationId: widget.conversationId,
        text: text,
      );
      _fetchMessages(isBackgroundRefresh: true);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send: $e")));
      }
    }
  }

  String _formatTime(String timestamp) {
    try {
       final DateTime dt = DateTime.parse(timestamp).toLocal(); 
       final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
       final period = dt.hour >= 12 ? "PM" : "AM";
       final minute = dt.minute.toString().padLeft(2, '0');
       return "$hour:$minute $period";
    } catch (e) {
       return "";
    }
  }

  // --- Helper: Strip out the backend ID to get the original filename ---
  String _getDisplayFilename(String url) {
    final decodedUrl = Uri.decodeFull(url);
    final fullName = decodedUrl.split('/').last; 
    
    final lastDotIndex = fullName.lastIndexOf('.');
    if (lastDotIndex == -1) return fullName; 

    final namePart = fullName.substring(0, lastDotIndex); 
    final extPart = fullName.substring(lastDotIndex); 

    if (namePart.length > 9 && namePart[namePart.length - 9] == '-') {
      final originalName = namePart.substring(0, namePart.length - 9);
      return originalName + extPart;
    }
    
    return fullName;
  }

  // --- Helper: Smart Cache, Download, and Open ---
  Future<void> _downloadAndOpenFile(String url) async {
    if (kIsWeb) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      return;
    }

    final cleanName = _getDisplayFilename(url);
    final dir = await getApplicationDocumentsDirectory();
    final localFile = File('${dir.path}/$cleanName'); 

    if (await localFile.exists()) {
      logger.i("Opening cached file: ${localFile.path}");
      await OpenFilex.open(localFile.path);
      return;
    }

    setState(() => _downloadingUrls.add(url)); 
    
    try {
      logger.i("Downloading file from: $url");
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        await OpenFilex.open(localFile.path);
      } else {
        throw Exception("Server returned ${response.statusCode}");
      }
    } catch (e) {
      logger.e("Failed to download file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to download file.")));
      }
    } finally {
      setState(() => _downloadingUrls.remove(url)); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.otherUserName, 
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18)
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : _messages.isEmpty 
                  ? const Center(child: Text("No messages yet. Say Hi!"))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final bool isMe = msg.senderId == authService.value.currentUser?.uid;
                        return _buildMessageBubble(msg, isMe);
                      },
                    ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    final bool isGroupChat = widget.otherUserId == "GROUP";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? blue : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isGroupChat && !isMe) 
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.senderName, 
                  style: TextStyle(color: blue, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            
            if (msg.attachments.isNotEmpty)
              ...msg.attachments.map((url) => _buildAttachmentUI(url, isMe)),

            if (msg.text.isNotEmpty && msg.text != "🎤 Voice Message")
              Text(
                msg.text, 
                style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)
              ),
            
            const SizedBox(height: 4),
            Text(
              _formatTime(msg.timestamp),
              style: TextStyle(color: isMe ? Colors.white70 : Colors.grey.shade600, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentUI(String url, bool isMe) {
    final cleanPath = Uri.parse(url).path.toLowerCase();
    final isDownloading = _downloadingUrls.contains(url);
    
    // --- WhatsApp-Style Image Preview ---
    if (cleanPath.endsWith('.jpg') || cleanPath.endsWith('.png') || 
        cleanPath.endsWith('.jpeg') || cleanPath.endsWith('.gif') || cleanPath.endsWith('.webp')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: GestureDetector(
          onTap: () => _downloadAndOpenFile(url), 
          child: Stack(
            alignment: Alignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 350,
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url, 
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        width: MediaQuery.of(context).size.width * 0.6,
                        color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade300,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const SizedBox(
                      height: 100, 
                      child: Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40))
                    ),
                  ),
                ),
              ),
              if (isDownloading)
                const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      );
    } 
    // --- Audio Player ---
    else if (cleanPath.endsWith('.m4a') || cleanPath.endsWith('.mp3')) {
      return InteractiveAudioBubble(url: url, isMe: isMe);
    }
    
    // --- Clickable Document Box ---
    final displayFilename = _getDisplayFilename(url);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: isDownloading ? null : () => _downloadAndOpenFile(url), 
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isMe ? Colors.transparent : Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isDownloading 
                ? SizedBox(
                    width: 24, height: 24, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: isMe ? Colors.white : blue)
                  )
                : Icon(Icons.insert_drive_file, color: isMe ? Colors.white : blue, size: 28),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  displayFilename, 
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (!_isRecording)
              IconButton(
                icon: const Icon(Icons.attach_file, color: Colors.grey),
                onPressed: _isUploading ? null : _pickAndUploadFile,
              ),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _isRecording ? Colors.red.shade200 : Colors.grey.shade300),
                ),
                child: _isRecording
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.mic, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Recording... ${_formatRecordDuration()}",
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Type a message...",
                        ),
                        enabled: !_isUploading,
                        onSubmitted: (_) => _sendMessage(),
                      ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            _isUploading 
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : GestureDetector(
                  onLongPressStart: (_) => _isTyping ? null : _startRecording(),
                  onLongPressEnd: (_) => _isTyping ? null : _stopAndUploadRecording(),
                  child: IconButton(
                    icon: Icon(
                      _isTyping ? Icons.send_rounded : Icons.mic,
                      color: _isRecording ? Colors.red : blue,
                    ),
                    onPressed: _isTyping ? _sendMessage : null, 
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// --- Interactive Audio Player Bubble Widget ---
class InteractiveAudioBubble extends StatefulWidget {
  final String url;
  final bool isMe;

  const InteractiveAudioBubble({super.key, required this.url, required this.isMe});

  @override
  State<InteractiveAudioBubble> createState() => _InteractiveAudioBubbleState();
}

class _InteractiveAudioBubbleState extends State<InteractiveAudioBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() => _duration = newDuration);
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() => _position = newPosition);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor = widget.isMe ? Colors.white : const Color(0xFF1976D2);
    final Color textColor = widget.isMe ? Colors.white : Colors.black87;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: iconColor,
              size: 36,
            ),
            onPressed: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                await _audioPlayer.play(UrlSource(widget.url));
              }
            },
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                activeTrackColor: iconColor,
                inactiveTrackColor: iconColor.withValues(alpha: 0.3),
                thumbColor: iconColor,
              ),
              child: Slider(
                min: 0,
                max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
                onChanged: (value) async {
                  final position = Duration(seconds: value.toInt());
                  await _audioPlayer.seek(position);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              _formatDuration(_position.inSeconds > 0 ? _position : _duration),
              style: TextStyle(color: textColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}