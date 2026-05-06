import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _messages = List.from(widget.chatService.historyFor(widget.device.ip));

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
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
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
            Icon(icon,
                size: 28,
                color: selected ? const Color(0xFFB8FF57) : Colors.white38),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? const Color(0xFFB8FF57) : Colors.white38)),
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
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    await widget.chatService.sendFile(
      widget.device,
      file.name,
      file.bytes!,
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Widget _buildMessage(ChatMessage msg) {
    if (msg.type == MessageType.file) {
      final size = msg.fileBytes != null
          ? _formatSize(msg.fileBytes!.length)
          : '';
      return Align(
        alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFB8FF57).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insert_drive_file_rounded,
                    color: Color(0xFFB8FF57), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.content,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  if (size.isNotEmpty)
                    Text(size,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 11, color: Colors.white38)),
                ],
              ),
              if (!msg.isMe && msg.fileBytes != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.download_done_rounded,
                    color: Color(0xFFB8FF57), size: 16),
              ],
            ],
          ),
        ),
      );
    }

    if (msg.type == MessageType.code) {
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(
          crossAxisAlignment:
              msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
              child: Text(msg.content,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      color: msg.isMe ? Colors.black : Colors.white)),
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
        .where(
            (m) => m.type == MessageType.text || m.type == MessageType.code)
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
                      Text('tap send to share any file.',
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
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F0F),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
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
              style:
                  GoogleFonts.spaceGrotesk(fontSize: 15, color: Colors.white),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
  void dispose() {
    _msgSub?.cancel();
    _fileSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
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
      body: TabBarView(
        controller: _tabController,
        children: [_buildChatTab(), _buildFilesTab()],
      ),
    );
  }
}
