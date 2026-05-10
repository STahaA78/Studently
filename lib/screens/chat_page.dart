import 'package:studently/app_style.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:studently/models/chat.dart';
import 'package:studently/providers/chat_provider.dart';
import 'package:studently/services/chat_presence.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/logger.dart';

class ChatPage extends ConsumerStatefulWidget {
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
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color blue = AppStyle.primaryBlue;

  bool _isUploading = false;
  bool _isInitialLoad = true; // true until first scroll-to-bottom completes

  final Set<String> _downloadingUrls = {};

  @override
  void initState() {
    super.initState();

    // Scroll-to-bottom whenever the list grows taller (e.g. an image finishes
    // loading and expands the content), but only during the initial load phase.
    _scrollController.addListener(() {
      if (_isInitialLoad &&
          _scrollController.hasClients &&
          _scrollController.position.extentAfter == 0) {
        // Already at the bottom — initial load is done.
        _isInitialLoad = false;
      }
    });

    // Tell provider to load messages for THIS chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatProvider.notifier)
          .loadMessagesForChat(widget.conversationId);
      Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
    });

    // We removed the setState here to prevent rebuilding the whole list on every keystroke!
    // The send button now uses ValueListenableBuilder to update itself.
  }

  @override
  void dispose() {
    ChatPresence.setActiveConversation(null);

    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0, // With reverse: true, bottom is 0.0
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    // Give images up to 3 seconds to load and expand the list, re-snapping to
    // bottom each time. After that we stop so normal scrolling isn't disturbed.
    for (final ms in [600, 1000, 1500, 2500, 3000]) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (!mounted || !_isInitialLoad) return;
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0, // With reverse: true, bottom is 0.0
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
        if (ms == 3000) _isInitialLoad = false;
      });
    }
  }

  // --- Interaction Logic ---

  Future<void> _pickAndUploadFile() async {
    logger.i('ChatPage: User tapped attachment icon');
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      withData: true,
    );

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
        // Delegated to Provider
        String? url = await ref
            .read(chatProvider.notifier)
            .uploadAttachment(fileBytes, platformFile.name);

        if (url != null) {
          // Send via Provider!
          await ref
              .read(chatProvider.notifier)
              .sendMessage("", attachments: [url]);
          _scrollToBottom();
        }
      }
      setState(() => _isUploading = false);
    }
  }



  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    try {
      // Send via Provider!
      await ref.read(chatProvider.notifier).sendMessage(text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to send: $e")));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to download file.")),
        );
      }
    } finally {
      setState(() => _downloadingUrls.remove(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Listen to the chat state
    final chatState = ref.watch(chatProvider);
    final messages = chatState.activeMessages;
    final isLoading = chatState.isLoading;

    // 2. Automatically scroll down when a new message arrives over WebSocket
    ref.listen<ChatState>(chatProvider, (previous, next) {
      if (previous != null &&
          previous.activeMessages.length < next.activeMessages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.otherUserName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppStyle.primaryBlue,
                    ),
                  )
                : messages.isEmpty
                ? const Center(child: Text("No messages yet. Say Hi!"))
                : (() {
                      final reversedMessages = messages.reversed.toList();
                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true, // Anchors the list to the bottom
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        itemCount: reversedMessages.length,
                        itemBuilder: (context, index) {
                          final msg = reversedMessages[index];
                          final bool isMe =
                              msg.senderId == authService.value.currentUser?.uid;
                          return _buildMessageBubble(msg, isMe);
                        },
                      );
                  })(),
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
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
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (isGroupChat && !isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.senderName,
                  style: TextStyle(
                    color: blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

            if (msg.attachments.isNotEmpty)
              ...msg.attachments.map((url) => _buildAttachmentUI(url, isMe)),

            if (msg.text.isNotEmpty && msg.text != "🎤 Voice Message")
              Text(
                msg.text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),

            const SizedBox(height: 4),
            Text(
              _formatTime(msg.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey.shade600,
                fontSize: 10,
              ),
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
    if (cleanPath.endsWith('.jpg') ||
        cleanPath.endsWith('.png') ||
        cleanPath.endsWith('.jpeg') ||
        cleanPath.endsWith('.gif') ||
        cleanPath.endsWith('.webp')) {
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
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.grey.shade300,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          height: 100,
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
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
            border: Border.all(
              color: isMe ? Colors.transparent : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isDownloading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isMe ? Colors.white : blue,
                      ),
                    )
                  : Icon(
                      Icons.insert_drive_file,
                      color: isMe ? Colors.white : blue,
                      size: 28,
                    ),
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
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: Colors.grey),
              onPressed: _isUploading ? null : _pickAndUploadFile,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
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
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (context, value, child) {
                      final isTyping = value.text.trim().isNotEmpty;
                      return IconButton(
                        icon: const Icon(Icons.send_rounded),
                        color: isTyping ? blue : Colors.grey,
                        onPressed: isTyping ? _sendMessage : null,
                      );
                    },
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

  const InteractiveAudioBubble({
    super.key,
    required this.url,
    required this.isMe,
  });

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
    final Color iconColor = widget.isMe ? Colors.white : AppStyle.primaryBlue;
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
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6.0,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 14.0,
                ),
                activeTrackColor: iconColor,
                inactiveTrackColor: iconColor.withValues(alpha: 0.3),
                thumbColor: iconColor,
              ),
              child: Slider(
                min: 0,
                max: _duration.inSeconds.toDouble() > 0
                    ? _duration.inSeconds.toDouble()
                    : 1.0,
                value: _position.inSeconds.toDouble().clamp(
                  0.0,
                  _duration.inSeconds.toDouble() > 0
                      ? _duration.inSeconds.toDouble()
                      : 1.0,
                ),
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
