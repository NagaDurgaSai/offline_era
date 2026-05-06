import 'dart:async';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../models/message.dart';
import '../providers/user_provider.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final DiscoveredDevice device;
  final ChatService chatService;

  const ChatScreen({
    super.key,
    required this.device,
    required this.chatService,
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

  @override
  void initState() {
    super.initState();
    widget.chatService.isInChat = true;
    _tabController = TabController(length: 2, vsync: this);
    _messages = [];
    widget.chatService.historyFor(widget.device.ip).then((msgs) {
      if (mounted) setState(() => _messages = List.from(msgs));
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
  }

  @override
  void dispose() {
    widget.chatService.isInChat = false;
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
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _pickerTile(
                  icon: Icons.text_fields_rounded,
                  label: 'plain text',
                  selected: _inputMode == MessageType.text,
                  onTap: () {
                    setState(() => _inputMode = MessageType.text);
                    Navigator.pop(context);
                  },
                )),
                const SizedBox(width: 12),
                Expanded(child: _pickerTile(
                  icon: Icons.code_rounded,
                  label: 'code',
                  selected: _inputMode == MessageType.code,
                  onTap: () {
                    setState(() => _inputMode = MessageType.code);
                    Navigator.pop(context);
                  },
                )),
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
            Icon(icon, size: 28,
                color: selected ? const Color(0xFFB8FF57) : Colors.white38),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? const Color(0xFFB8FF57)
                        : Colors.white38)),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await widget.chatService.sendTo(widget.device, text, _inputMode);
    _scrollToBottom();
  }

  Future<void> _pickAndSendFile() async {
    print("DEBUG: opening file picker");
    final result = await FilePicker.platform.pickFiles(withData: true);
    print("DEBUG: picker result = \${result?.files.length} files");
    if (result == null || result.files.isEmpty) return;
    final pf = result.files.first;
    print("DEBUG: file name=\${pf.name} path=\${pf.path} bytes=\${pf.bytes?.length}");
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
    await widget.chatService.sendFile(widget.device, pf.name, bytes);
    print("DEBUG: sendFile done");
  }

  Future<void> _sendFileFromPath(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final name = path.split(Platform.pathSeparator).last;
    await widget.chatService.sendFile(widget.device, name, bytes);
  }

  Future<void> _saveFile(ChatMessage msg) async {
    if (msg.fileBytes == null && msg.savedPath == null) return;
    final bytes = msg.fileBytes ?? await File(msg.savedPath!).readAsBytes();
    final name = msg.fileName ?? msg.content;
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'save file',
      fileName: name,
      bytes: bytes,
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('saved to \$result',
              style: GoogleFonts.spaceGrotesk(fontSize: 12)),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
        ),
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
          content: Text('no app found to open this file',
              style: GoogleFonts.spaceGrotesk()),
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

  bool _isPdf(String name) =>
      name.split('.').last.toLowerCase() == 'pdf';

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
    final size = msg.fileBytes != null ? _formatSize(msg.fileBytes!.length) : '';
    final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

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
            if (isPdf)
              GestureDetector(
                onTap: () => _openFile(msg),
                child: Container(
                  width: 200,
                  height: 200,
                  color: const Color(0xFFFF6B6B).withOpacity(0.07),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded,
                          color: Color(0xFFFF6B6B), size: 48),
                      const SizedBox(height: 8),
                      Text('PDF',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              color: const Color(0xFFFF6B6B).withOpacity(0.7),
                              fontWeight: FontWeight.w600)),
                    ],
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
                          Text(size,
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10, color: Colors.white38)),
                      ],
                    ),
                  ),
                  if (msg.isMe)
                    const Icon(Icons.check_rounded,
                        size: 12, color: Colors.white24),
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
                              'save',
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
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.white.withOpacity(0.04),
              child: Row(
                children: [
                  const Icon(Icons.code_rounded,
                      size: 12, color: Color(0xFFB8FF57)),
                  const SizedBox(width: 6),
                  Text('code',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: const Color(0xFFB8FF57),
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () =>
                        Clipboard.setData(ClipboardData(text: msg.content)),
                    child: const Icon(Icons.copy_rounded,
                        size: 14, color: Colors.white38),
                  ),
                ],
              ),
            ),
            HighlightView(
              msg.content,
              language: 'dart',
              theme: atomOneDarkTheme,
              padding: const EdgeInsets.all(12),
              textStyle: GoogleFonts.jetBrainsMono(fontSize: 12),
            ),
          ],
        ),
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
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(
          crossAxisAlignment: msg.isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  Text(msg.content,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          color:
                              msg.isMe ? Colors.black : Colors.white)),
                  if (isLong) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => Clipboard.setData(
                          ClipboardData(text: msg.content)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded,
                              size: 12,
                              color: msg.isMe
                                  ? Colors.black54
                                  : Colors.white38),
                          const SizedBox(width: 4),
                          Text('copy',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  color: msg.isMe
                                      ? Colors.black54
                                      : Colors.white38)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(_formatTime(msg.timestamp),
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 10, color: Colors.white24)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    final chatMsgs = _messages
        .where((m) =>
            m.type == MessageType.text || m.type == MessageType.code)
        .toList();
    return Column(
      children: [
        Expanded(
          child: chatMsgs.isEmpty
              ? Center(
                  child: Text('say something.',
                      style: GoogleFonts.spaceGrotesk(
                          color: Colors.white24, fontSize: 14)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: chatMsgs.length,
                  itemBuilder: (_, i) => _buildMessage(chatMsgs[i]),
                ),
        ),
        _buildInput(),
      ],
    );
  }

  Widget _buildFilesTab() {
    final fileMsgs =
        _messages.where((m) => m.type == MessageType.file).toList();
    return Column(
      children: [
        Expanded(
          child: fileMsgs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_open_rounded,
                          color: Colors.white12, size: 48),
                      const SizedBox(height: 12),
                      Text('no files yet.',
                          style: GoogleFonts.spaceGrotesk(
                              color: Colors.white24, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('tap send or drag a file.',
                          style: GoogleFonts.spaceGrotesk(
                              color: Colors.white.withOpacity(0.08),
                              fontSize: 12)),
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
                  Icon(Icons.file_upload_outlined,
                      size: 16,
                      color: _dragOver
                          ? const Color(0xFFB8FF57)
                          : Colors.white24),
                  const SizedBox(width: 8),
                  Text(
                    _dragOver ? 'drop to send' : 'drag file here',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: _dragOver
                            ? const Color(0xFFB8FF57)
                            : Colors.white24),
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
                  const Icon(Icons.add_rounded,
                      color: Colors.black, size: 20),
                  const SizedBox(width: 8),
                  Text('send a file',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black)),
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
                  fontSize: 15, color: Colors.white),
              cursorColor: const Color(0xFFB8FF57),
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: _inputMode == MessageType.code
                    ? 'paste code...'
                    : 'say something...',
                hintStyle: GoogleFonts.spaceGrotesk(
                    color: Colors.white24, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
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
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.black, size: 20),
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
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFB8FF57).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.device.name[0].toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB8FF57)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.device.name,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFB8FF57),
          indicatorWeight: 2,
          labelColor: const Color(0xFFB8FF57),
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.spaceGrotesk(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'chat'), Tab(text: 'files')],
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
