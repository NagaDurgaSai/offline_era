import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../models/message.dart';
import '../providers/user_provider.dart';
import '../services/chat_service.dart';
import '../services/discovery_service.dart';
import '../widgets/device_tile.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _discovery = DiscoveryService();
  final _chat = ChatService();
  List<DiscoveredDevice> _devices = [];
  bool _started = false;
  StreamSubscription? _msgSub;
  StreamSubscription? _fileSub;

  // unread counts per device ip
  final Map<String, int> _unread = {};
  OverlayEntry? _bannerEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final user = context.read<UserProvider>();
    await _chat.startServer(user.name, user.localIp);
    await _discovery.start(user.name, user.localIp);
    _discovery.devicesStream.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });

    _msgSub = _chat.messageStream.listen((msg) {
      if (!msg.isMe) {
        setState(() => _unread[msg.senderIp] = (_unread[msg.senderIp] ?? 0) + 1);
        _showBanner(msg.senderName, msg.type == MessageType.code ? '📎 code snippet' : msg.content, msg.senderIp);
      }
    });

    _fileSub = _chat.fileStream.listen((msg) {
      if (!msg.isMe) {
        setState(() => _unread[msg.senderIp] = (_unread[msg.senderIp] ?? 0) + 1);
        _showBanner(msg.senderName, 'sent a file: ${msg.content}', msg.senderIp);
      }
    });

    if (mounted) setState(() => _started = true);
  }

  void _showBanner(String sender, String preview, String senderIp) {
    _bannerEntry?.remove();
    _bannerEntry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: _NotificationBanner(
          sender: sender,
          preview: preview,
          onTap: () {
            _bannerEntry?.remove();
            _bannerEntry = null;
            final device = _devices.firstWhere(
              (d) => d.ip == senderIp,
              orElse: () => _devices.first,
            );
            _openChat(device);
          },
          onDismiss: () {
            _bannerEntry?.remove();
            _bannerEntry = null;
          },
        ),
      ),
    );
    Overlay.of(context).insert(_bannerEntry!);
    Future.delayed(const Duration(seconds: 4), () {
      _bannerEntry?.remove();
      _bannerEntry = null;
    });
  }

  @override
  void dispose() {
    _bannerEntry?.remove();
    _msgSub?.cancel();
    _fileSub?.cancel();
    _discovery.dispose();
    _chat.dispose();
    super.dispose();
  }

  void _openChat(DiscoveredDevice device) {
    setState(() => _unread.remove(device.ip));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(device: device, chatService: _chat),
      ),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(onNameChanged: (name) { _chat.updateName(name); _discovery.updateName(name); })),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final totalUnread = _unread.values.fold(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        titleSpacing: 24,
        title: Text('offline era.',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFB8FF57))),
        actions: [
          GestureDetector(
            onTap: _openProfile,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded,
                      size: 14, color: Colors.white54),
                  const SizedBox(width: 6),
                  Text(user.name,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          color: Colors.white54,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalUnread > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFB8FF57).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFB8FF57).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_chat_unread_rounded,
                      color: Color(0xFFB8FF57), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '$totalUnread new ${totalUnread == 1 ? 'message' : 'messages'}',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: const Color(0xFFB8FF57),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Text("who's around",
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: Colors.white38,
                        letterSpacing: 0.5)),
                const SizedBox(width: 8),
                if (_started)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Color(0xFFB8FF57), shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
          Expanded(
            child: !_started
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFB8FF57)),
                        ),
                        const SizedBox(height: 12),
                        Text('scanning network...',
                            style: GoogleFonts.spaceGrotesk(
                                color: Colors.white24, fontSize: 13)),
                      ],
                    ),
                  )
                : _devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('( ´_ゝ`)',
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 32, color: Colors.white24)),
                            const SizedBox(height: 12),
                            Text('no one else is here yet.',
                                style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white24, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('open the app on another device.',
                                style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white.withOpacity(0.08),
                                    fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: _devices.length,
                        itemBuilder: (_, i) {
                          final device = _devices[i];
                          final unread = _unread[device.ip] ?? 0;
                          return DeviceTile(
                            device: device,
                            unreadCount: unread,
                            onTap: () => _openChat(device),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _started
                        ? const Color(0xFFB8FF57)
                        : Colors.white24,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _started
                      ? 'broadcasting on ${user.localIp}'
                      : 'connecting...',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, color: Colors.white24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBanner extends StatefulWidget {
  final String sender;
  final String preview;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.sender,
    required this.preview,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFB8FF57).withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
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
                      widget.sender[0].toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB8FF57)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.sender,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      Text(widget.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 12, color: Colors.white54)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white24, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
