import 'dart:async';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import '../models/device.dart';
import '../models/message.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final DiscoveredDevice device;
  final ChatService chatService;
  final int initialUnreadCount;
  final String? lastReadMessageId;

  const ChatScreen({
    super.key,
    required this.device,
    required this.chatService,
    this.initialUnreadCount = 0,
    this.lastReadMessageId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  StreamSubscription? _msgSub;
  StreamSubscription? _fileSub;
  MessageType _inputMode = MessageType.text;
  late TabController _tabController;
  bool _dragOver = false;
  bool _seenByPeer = false;
  int? _firstNewChatIndex;
  final Map<int, GlobalKey> _chatItemKeys = {};
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    widget.chatService.isInChat = true;
    _scrollController.addListener(_onScrollChanged);
    _tabController = TabController(length: 2, vsync: this);
    _messages = [];
    widget.chatService.activeChatIp = widget.device.ip;
    widget.chatService.clearNotificationsFor(widget.device.ip);
    widget.chatService.historyFor(widget.device.ip).then((msgs) {
      if (mounted) {
        setState(() {
          _messages = List.from(msgs);
          final chatMsgs = _messages
              .where(
                (m) => m.type == MessageType.text || m.type == MessageType.code,
              )
              .toList();
          final chatCount = chatMsgs.length;
          if (widget.initialUnreadCount > 0 && chatCount > 0) {
            // fresh unreads — jump to first unread
            _firstNewChatIndex = (chatCount - widget.initialUnreadCount).clamp(
              0,
              chatCount - 1,
            );
          } else if (widget.lastReadMessageId != null && chatCount > 0) {
            // returning after reading — jump just past last read message
            final idx = chatMsgs.indexWhere(
              (m) => m.id == widget.lastReadMessageId,
            );
            if (idx != -1 && idx < chatCount - 1) {
              _firstNewChatIndex = idx + 1;
            } else {
              _firstNewChatIndex = null;
            }
          } else {
            _firstNewChatIndex = null;
          }
        });
        _scrollToUnreadBoundaryIfNeeded();
        // send seen signal
        widget.chatService.sendSeen(widget.device);
      }
    });

    _msgSub = widget.chatService.messageStream.listen((msg) {
      if (msg.senderIp == widget.device.ip || msg.isMe) {
        if (!_messages.any((m) => m.id == msg.id)) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      }
    });

    _fileSub = widget.chatService.fileStream.listen((msg) {
      if (msg.senderIp == widget.device.ip || msg.isMe) {
        if (!_messages.any((m) => m.id == msg.id)) {
          setState(() => _messages.add(msg));
        }
      }
    });

    widget.chatService.seenStream.listen((peerIp) {
      if (peerIp == widget.device.ip && mounted) {
        setState(() => _seenByPeer = true);
      }
    });
  }

  @override
  void dispose() {
    widget.chatService.isInChat = false;
    widget.chatService.activeChatIp = null;
    _scrollController.removeListener(_onScrollChanged);
    _msgSub?.cancel();
    _fileSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    if (_firstNewChatIndex != null) {
      final markerContext = _chatItemKeys[_firstNewChatIndex!]?.currentContext;
      if (markerContext != null) {
        final box = markerContext.findRenderObject() as RenderBox;
        final viewport = RenderAbstractViewport.of(box);
        final reveal = viewport.getOffsetToReveal(box, 0).offset;
        if (_scrollController.offset >= reveal - 8) {
          setState(() => _firstNewChatIndex = null);
        }
      }
    }
    final distanceFromBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    final shouldShow = distanceFromBottom > 220;
    if (shouldShow != _showScrollToBottom && mounted) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _scrollToUnreadBoundaryIfNeeded() {
    final index = _firstNewChatIndex;
    if (index == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;

      final chatCount = _messages
          .where(
            (m) => m.type == MessageType.text || m.type == MessageType.code,
          )
          .length;
      if (chatCount <= 1) return;

      final ratio = index / (chatCount - 1);
      final estimatedOffset =
          _scrollController.position.maxScrollExtent * ratio;
      _scrollController.jumpTo(
        estimatedOffset.clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        ),
      );

      for (int attempt = 0; attempt < 4; attempt++) {
        await Future.delayed(const Duration(milliseconds: 16));
        if (!mounted) return;
        final ctx = _chatItemKeys[index]?.currentContext;
        if (ctx != null) {
          await Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 260),
            alignment: 0.08,
            curve: Curves.easeOut,
          );
          return;
        }
      }
    });
  }

  void _showInputPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _pickerTile(
                    icon: Icons.text_fields_rounded,
                    label: 'plain text',
                    selected: _inputMode == MessageType.text,
                    onTap: () {
                      setState(() => _inputMode = MessageType.text);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _pickerTile(
                    icon: Icons.code_rounded,
                    label: 'code',
                    selected: _inputMode == MessageType.code,
                    onTap: () {
                      setState(() => _inputMode = MessageType.code);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFB8FF57).withOpacity(0.12)
              : const Color(0xFF252525),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFB8FF57) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: selected ? const Color(0xFFB8FF57) : Colors.white38,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFFB8FF57) : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    if (_seenByPeer) {
      setState(() => _seenByPeer = false);
    }
    await widget.chatService.sendTo(widget.device, text, _inputMode);
    _scrollToBottom();
  }

  Future<void> _pickAndSendFile() async {
    print("DEBUG: opening file picker");
    final result = await FilePicker.platform.pickFiles(withData: true);
    print("DEBUG: picker result = \${result?.files.length} files");
    if (result == null || result.files.isEmpty) return;
    final pf = result.files.first;
    print(
      "DEBUG: file name=\${pf.name} path=\${pf.path} bytes=\${pf.bytes?.length}",
    );
    Uint8List? bytes;
    if (pf.bytes != null) {
      bytes = pf.bytes!;
      print("DEBUG: got bytes from picker directly: \${bytes.length}");
    } else if (pf.path != null) {
      print("DEBUG: reading from path \${pf.path}");
      try {
        bytes = await File(pf.path!).readAsBytes();
        print("DEBUG: read \${bytes.length} bytes from path");
      } catch (e) {
        print("DEBUG: error reading file: \$e");
      }
    }
    if (bytes == null) {
      print("DEBUG: bytes is null, aborting");
      return;
    }
    print("DEBUG: sending file \${pf.name} \${bytes.length} bytes");
    if (_seenByPeer) {
      setState(() => _seenByPeer = false);
    }
    await widget.chatService.sendFile(widget.device, pf.name, bytes);
    print("DEBUG: sendFile done");
  }

  Future<void> _sendFileFromPath(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final name = path.split(Platform.pathSeparator).last;
    if (_seenByPeer) {
      setState(() => _seenByPeer = false);
    }
    await widget.chatService.sendFile(widget.device, name, bytes);
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'clear chat?',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'removes all messages and files. cannot be undone.',
          style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'cancel',
              style: GoogleFonts.spaceGrotesk(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'clear',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFFFF6B6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    for (final msg in _messages) {
      if (msg.savedPath != null) {
        try {
          final f = File(msg.savedPath!);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
    await widget.chatService.db.deleteMessagesForPeer(widget.device.ip);
    widget.chatService.clearCache(widget.device.ip);
    if (mounted) setState(() => _messages.clear());
  }

  Future<void> _saveFile(ChatMessage msg) async {
    if (msg.savedPath == null) return;
    if (Platform.isMacOS) {
      // show in Finder
      final dir = msg.savedPath!.substring(
        0,
        msg.savedPath!.lastIndexOf(Platform.pathSeparator),
      );
      await Process.run('open', [dir]);
    } else if (Platform.isWindows) {
      // save to Downloads on Windows — file already there, open folder
      final dir = msg.savedPath!.substring(
        0,
        msg.savedPath!.lastIndexOf(Platform.pathSeparator),
      );
      await Process.run('explorer', [dir]);
    } else {
      // Android — save as dialog
      if (msg.fileBytes == null && msg.savedPath == null) return;
      final bytes = msg.fileBytes ?? await File(msg.savedPath!).readAsBytes();
      final name = msg.fileName ?? msg.content;
      await FilePicker.platform.saveFile(
        dialogTitle: 'save file',
        fileName: name,
        bytes: bytes,
      );
    }
  }

  Future<void> _shareFile(ChatMessage msg) async {
    if (msg.savedPath == null) return;
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      await OpenFilex.open(msg.savedPath!);
    } else {
      await Share.shareXFiles([XFile(msg.savedPath!)]);
    }
  }

  Future<void> _openFile(ChatMessage msg) async {
    if (msg.savedPath == null) return;
    final result = await OpenFilex.open(msg.savedPath!);
    if (result.type == ResultType.noAppToOpen && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'no app found to open this file',
            style: GoogleFonts.spaceGrotesk(),
          ),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _isImage(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  bool _isPdf(String name) => name.split('.').last.toLowerCase() == 'pdf';

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Widget _buildMessage(ChatMessage msg) {
    if (msg.type == MessageType.file) {
      return _buildFileMessage(msg);
    }
    if (msg.type == MessageType.code) {
      return _buildCodeMessage(msg);
    }
    return _buildTextMessage(msg);
  }

  Widget _buildFileMessage(ChatMessage msg) {
    final name = msg.fileName ?? msg.content;
    final isImg = _isImage(name);
    final isPdf = _isPdf(name);
    final size = msg.fileBytes != null
        ? _formatSize(msg.fileBytes!.length)
        : '';
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        width: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // square preview for images
            if (isImg && msg.fileBytes != null)
              GestureDetector(
                onTap: () => _openFile(msg),
                child: Image.memory(
                  msg.fileBytes!,
                  fit: BoxFit.cover,
                  width: 200,
                  height: 200,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            // square preview for pdf
            if (isPdf && msg.fileBytes != null)
              GestureDetector(
                onTap: () => _openFile(msg),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                  child: _PdfPreview(bytes: msg.fileBytes!),
                ),
              ),
            if (isPdf && msg.fileBytes == null)
              GestureDetector(
                onTap: () => _openFile(msg),
                child: Container(
                  width: 200,
                  height: 200,
                  color: const Color(0xFFFF6B6B).withOpacity(0.07),
                  child: const Center(
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFFF6B6B),
                      size: 48,
                    ),
                  ),
                ),
              ),
            // info row
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isImg
                          ? const Color(0xFFB8FF57).withOpacity(0.1)
                          : isPdf
                          ? const Color(0xFFFF6B6B).withOpacity(0.1)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isImg
                          ? Icons.image_rounded
                          : isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.insert_drive_file_rounded,
                      size: 14,
                      color: isImg
                          ? const Color(0xFFB8FF57)
                          : isPdf
                          ? const Color(0xFFFF6B6B)
                          : Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (size.isNotEmpty)
                          Text(
                            size,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              color: Colors.white38,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (msg.isMe)
                    const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Colors.white24,
                    ),
                ],
              ),
            ),
            // action row — shown for received files on all platforms
            if (!msg.isMe && msg.savedPath != null)
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _saveFile(msg),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Text(
                              isDesktop ? 'show in folder' : 'save',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB8FF57),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 30, color: Colors.white10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _shareFile(msg),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Text(
                              isDesktop ? 'open' : 'share',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB8FF57),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeMessage(ChatMessage msg) {
    final rawLines = msg.content.split('\n');
    final lines = rawLines.length == 1 ? msg.content.split(r'\n') : rawLines;
    final preview = lines.take(5).join('\n');
    final isLongCode = lines.length > 5;

    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: StatefulBuilder(
        builder: (context, setLocal) {
          bool expanded = false;
          return StatefulBuilder(
            builder: (context, setLocal2) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    color: Colors.white.withOpacity(0.04),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.code_rounded,
                          size: 12,
                          color: Color(0xFFB8FF57),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'code · ${lines.length} lines',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: const Color(0xFFB8FF57),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Clipboard.setData(
                            ClipboardData(text: msg.content),
                          ),
                          child: const Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: HighlightView(
                      expanded ? msg.content : preview,
                      language: 'dart',
                      theme: atomOneDarkTheme,
                      padding: const EdgeInsets.all(12),
                      textStyle: GoogleFonts.jetBrainsMono(fontSize: 12),
                    ),
                  ),
                  if (isLongCode)
                    GestureDetector(
                      onTap: () => setLocal2(() => expanded = !expanded),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        color: Colors.white.withOpacity(0.03),
                        child: Center(
                          child: Text(
                            expanded
                                ? 'show less ↑'
                                : 'show ${lines.length - 5} more lines ↓',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              color: const Color(0xFFB8FF57),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextMessage(ChatMessage msg) {
    final isLong = msg.content.length > 200;
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment: msg.isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isMe
                    ? const Color(0xFFB8FF57)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.isMe ? 16 : 4),
                  bottomRight: Radius.circular(msg.isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    msg.content,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      color: msg.isMe ? Colors.black : Colors.white,
                    ),
                  ),
                  if (isLong) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () =>
                          Clipboard.setData(ClipboardData(text: msg.content)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: msg.isMe ? Colors.black54 : Colors.white38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'copy',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              color: msg.isMe ? Colors.black54 : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.timestamp),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    color: Colors.white24,
                  ),
                ),
                if (msg.isMe && _seenByPeer && _isLastSentMessage(msg)) ...[
                  const SizedBox(width: 4),
                  Text(
                    'seen',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      color: const Color(0xFFB8FF57).withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isLastSentMessage(ChatMessage msg) {
    final sentMsgs = _messages
        .where(
          (m) =>
              m.isMe &&
              (m.type == MessageType.text || m.type == MessageType.code),
        )
        .toList();
    return sentMsgs.isNotEmpty && sentMsgs.last.id == msg.id;
  }

  Widget _buildChatTab() {
    final chatMsgs = _messages
        .where((m) => m.type == MessageType.text || m.type == MessageType.code)
        .toList();
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: chatMsgs.isEmpty
                    ? Center(
                        child: Text(
                          'say something.',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white24,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemCount: chatMsgs.length,
                        itemBuilder: (_, i) {
                          final key = _chatItemKeys.putIfAbsent(
                            i,
                            () => GlobalKey(),
                          );
                          return KeyedSubtree(
                            key: key,
                            child: Column(
                              children: [
                                if (_firstNewChatIndex == i)
                                  _buildUnreadBoundaryMarker(),
                                _buildMessage(chatMsgs[i]),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Positioned(
                right: 18,
                bottom: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _showScrollToBottom ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_showScrollToBottom,
                    child: GestureDetector(
                      onTap: _scrollToBottom,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB8FF57),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB8FF57).withOpacity(0.35),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildInput(),
      ],
    );
  }

  Widget _buildUnreadBoundaryMarker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFFB8FF57).withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFB8FF57),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB8FF57).withOpacity(0.45),
                  blurRadius: 8,
                  spreadRadius: 1.5,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFB8FF57).withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    final fileMsgs = _messages
        .where((m) => m.type == MessageType.file)
        .toList();
    return Column(
      children: [
        Expanded(
          child: fileMsgs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.folder_open_rounded,
                        color: Colors.white12,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'no files yet.',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white24,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'tap send or drag a file.',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white.withOpacity(0.08),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: fileMsgs.length,
                  itemBuilder: (_, i) => _buildMessage(fileMsgs[i]),
                ),
        ),
        DropTarget(
          onDragDone: (details) async {
            for (final file in details.files) {
              await _sendFileFromPath(file.path);
            }
            setState(() => _dragOver = false);
          },
          onDragEntered: (_) => setState(() => _dragOver = true),
          onDragExited: (_) => setState(() => _dragOver = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            height: 112,
            decoration: BoxDecoration(
              color: _dragOver
                  ? const Color(0xFFB8FF57).withOpacity(0.12)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _dragOver ? const Color(0xFFB8FF57) : Colors.white12,
                width: _dragOver ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.file_upload_outlined,
                    size: 16,
                    color: _dragOver ? const Color(0xFFB8FF57) : Colors.white24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _dragOver ? 'drop to send' : 'drag file here',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: _dragOver
                          ? const Color(0xFFB8FF57)
                          : Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          color: const Color(0xFF0F0F0F),
          child: GestureDetector(
            onTap: _pickAndSendFile,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFB8FF57),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.black, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'send a file',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showInputPicker,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _inputMode == MessageType.code
                    ? const Color(0xFFB8FF57).withOpacity(0.15)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _inputMode == MessageType.code
                    ? Icons.code_rounded
                    : Icons.attach_file_rounded,
                size: 18,
                color: _inputMode == MessageType.code
                    ? const Color(0xFFB8FF57)
                    : Colors.white38,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _textController,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                color: Colors.white,
              ),
              cursorColor: const Color(0xFFB8FF57),
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: _inputMode == MessageType.code
                    ? 'paste code...'
                    : 'say something...',
                hintStyle: GoogleFonts.spaceGrotesk(
                  color: Colors.white24,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFB8FF57),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFB8FF57).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: widget.device.avatar.isNotEmpty
                    ? Text(
                        widget.device.avatar,
                        style: const TextStyle(fontSize: 16),
                      )
                    : Text(
                        widget.device.name[0].toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB8FF57),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.device.name,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
            color: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: _clearChat,
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_sweep_rounded,
                      color: Color(0xFFFF6B6B),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'clear chat',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFFFF6B6B),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFB8FF57),
          indicatorWeight: 2,
          labelColor: const Color(0xFFB8FF57),
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'chat'),
            Tab(text: 'files'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [_buildChatTab(), _buildFilesTab()],
        ),
      ),
    );
  }
}

class _PdfPreview extends StatefulWidget {
  final Uint8List bytes;
  const _PdfPreview({required this.bytes});

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  PdfController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfController(document: PdfDocument.openData(widget.bytes));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: PdfView(
        controller: _controller!,
        scrollDirection: Axis.horizontal,
        builders: PdfViewBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFB8FF57),
              strokeWidth: 2,
            ),
          ),
          pageLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFB8FF57),
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }
}
