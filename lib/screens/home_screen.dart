import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../models/message.dart';
import '../providers/user_provider.dart';
import '../services/chat_service.dart';
import '../services/discovery_service.dart';
import '../services/database.dart';
import '../widgets/device_tile.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _discovery = DiscoveryService();
  late final ChatService _chat;
  List<DiscoveredDevice> _devices = [];
  Set<String> _onlineIps = {};
  bool _started = false;
  StreamSubscription? _msgSub;
  StreamSubscription? _fileSub;
  StreamSubscription? _onlineSub;
  StreamSubscription? _seenSub;

  final Map<String, int> _unread = {};
  final Map<String, String> _lastMessage = {};
  final Map<String, String> _lastMessageTime = {};
  final Map<String, String> _lastReadMessageId = {};
  OverlayEntry? _bannerEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final user = context.read<UserProvider>();
    _chat = ChatService();
    await _chat.startServer(user.name, user.localIp);
    await _discovery.start(user.name, user.avatar, user.localIp, _chat.db, user.deviceId);

    _discovery.devicesStream.listen((devices) {
      if (!mounted) return;
      setState(() => _devices = devices);
      for (final d in devices) {
        if (!_lastMessage.containsKey(d.ip)) {
          _loadLastMessage(d.ip);
        }
      }
    });

    _onlineSub = _discovery.onlineStream.listen((onlineIps) {
      if (mounted) setState(() => _onlineIps = onlineIps);
    });

    // load last messages for all known devices
    for (final device in _devices) {
      _loadLastMessage(device.ip);
    }

    _msgSub = _chat.messageStream.listen((msg) {
      if (!msg.isMe) {
        final isActiveChat = _chat.activeChatIp == msg.senderIp;
        setState(() {
          if (!isActiveChat) {
            _unread[msg.senderIp] = (_unread[msg.senderIp] ?? 0) + 1;
          }
          _updateLastMessage(msg.senderIp, msg);
        });
        if (!isActiveChat) {
          _showBanner(msg.senderName,
              msg.type == MessageType.code ? '📎 code snippet' : msg.content,
              msg.senderIp);
        }
      } else {
        setState(() => _updateLastMessage(msg.senderIp, msg));
      }
    });

    _fileSub = _chat.fileStream.listen((msg) {
      if (!msg.isMe) {
        final isActiveChat = _chat.activeChatIp == msg.senderIp;
        setState(() {
          if (!isActiveChat) {
            _unread[msg.senderIp] = (_unread[msg.senderIp] ?? 0) + 1;
          }
          _updateLastMessage(msg.senderIp, msg);
        });
        if (!isActiveChat) {
          _showBanner(msg.senderName, '📁 ${msg.content}', msg.senderIp);
        }
      } else {
        setState(() => _updateLastMessage(msg.isMe ? msg.senderIp : msg.senderIp, msg));
      }
    });

    _seenSub = _chat.seenStream.listen((peerIp) {
      if (!mounted) return;
      setState(() => _unread.remove(peerIp));
    });

    if (mounted) setState(() => _started = true);


  }

  Future<void> _loadLastMessage(String peerIp) async {
    final msg = await _chat.db.lastMessageForPeer(peerIp);
    if (msg != null && mounted) {
      setState(() {
        _updateLastMessageFromDb(peerIp, msg);
      });
    }
  }

  void _updateLastMessageFromDb(String peerIp, Message msg) {
    String preview;
    if (msg.type == 'file') {
      preview = '📁 ${msg.content}';
    } else if (msg.type == 'code') {
      preview = '📎 code snippet';
    } else {
      preview = msg.isMe ? 'you: ${msg.content}' : msg.content;
    }
    _lastMessage[peerIp] = preview;
    _lastMessageTime[peerIp] = _formatTime(DateTime.parse(msg.timestamp));
  }

  void _updateLastMessage(String peerIp, ChatMessage msg) {
    String preview;
    if (msg.type == MessageType.file) {
      preview = '📁 ${msg.content}';
    } else if (msg.type == MessageType.code) {
      preview = '📎 code snippet';
    } else {
      preview = msg.isMe ? 'you: ${msg.content}' : msg.content;
    }
    _lastMessage[peerIp] = preview;
    _lastMessageTime[peerIp] = _formatTime(msg.timestamp);
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    if (t.day == now.day) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.day}/${t.month}';
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
    _onlineSub?.cancel();
    _seenSub?.cancel();
    _discovery.dispose();
    _chat.dispose();
    super.dispose();
  }

  void _openChat(DiscoveredDevice device) {
    final unreadCount = _unread[device.ip] ?? 0;

    // snapshot last read position before opening
    final cached = _chat.getCachedMessages(device.ip);
    if (cached.isNotEmpty) {
      _lastReadMessageId[device.ip] = cached.last.id;
    }

    setState(() => _unread.remove(device.ip));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          device: device,
          chatService: _chat,
          initialUnreadCount: unreadCount,
          lastReadMessageId: _lastReadMessageId[device.ip],
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      setState(() => _unread.remove(device.ip));
      _loadLastMessage(device.ip);
    });
  }

  Future<void> _showManualConnectDialog() async {
    final ipController = TextEditingController();
    String? errorMsg;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('connect by IP',
              style: GoogleFonts.spaceGrotesk(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "enter the device's local IP address",
                style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ipController,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: GoogleFonts.spaceGrotesk(color: Colors.white),
                cursorColor: const Color(0xFFB8FF57),
                decoration: InputDecoration(
                  hintText: '192.168.x.x',
                  hintStyle: GoogleFonts.spaceGrotesk(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFB8FF57), width: 1),
                  ),
                  errorText: errorMsg,
                  errorStyle: GoogleFonts.spaceGrotesk(color: Colors.redAccent),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () async {
                final ip = ipController.text.trim();
                if (ip.isEmpty) {
                  setDialogState(() => errorMsg = 'enter an IP');
                  return;
                }
                final parts = ip.split('.');
                if (parts.length != 4 ||
                    parts.any((p) => int.tryParse(p) == null)) {
                  setDialogState(() => errorMsg = 'invalid IP format');
                  return;
                }
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('connecting to \$ip...',
                        style: GoogleFonts.spaceGrotesk()),
                    backgroundColor: const Color(0xFF1A1A1A),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                  ),
                );
                final result = await _discovery.manualConnect(ip);
                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                if (result != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('connected to \$result',
                          style: GoogleFonts.spaceGrotesk()),
                      backgroundColor: const Color(0xFF1A1A1A),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('could not reach \$ip — is the app open there?',
                          style: GoogleFonts.spaceGrotesk()),
                      backgroundColor: Colors.red.shade900,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text('connect',
                  style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFFB8FF57),
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    ipController.dispose();
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          onProfileChanged: () {
            final user = context.read<UserProvider>();
            _chat.updateName(user.name);
            _discovery.updateProfile(user.name, user.avatar);
          },
        ),
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  user.avatar.isNotEmpty
                      ? Text(user.avatar, style: const TextStyle(fontSize: 14))
                      : const Icon(Icons.person_rounded, size: 14, color: Colors.white54),
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
      floatingActionButton: _started
          ? FloatingActionButton(
              onPressed: _showManualConnectDialog,
              backgroundColor: const Color(0xFF1A1A1A),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: const Color(0xFFB8FF57).withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Color(0xFFB8FF57),
                size: 22,
              ),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalUnread > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                              strokeWidth: 2, color: Color(0xFFB8FF57)),
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
                          return Dismissible(
                            key: Key(device.ip),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B6B).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_sweep_rounded,
                                  color: Color(0xFFFF6B6B), size: 22),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: const Color(0xFF1A1A1A),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  title: Text('remove ${device.name}?',
                                      style: GoogleFonts.spaceGrotesk(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                  content: Text(
                                      'removes chat history and device from list.',
                                      style: GoogleFonts.spaceGrotesk(
                                          color: Colors.white54, fontSize: 13)),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text('cancel',
                                          style: GoogleFonts.spaceGrotesk(
                                              color: Colors.white38)),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text('remove',
                                          style: GoogleFonts.spaceGrotesk(
                                              color: const Color(0xFFFF6B6B),
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ) ?? false;
                            },
                            onDismissed: (_) async {
                              await _chat.db.deleteMessagesForPeer(device.ip);
                              await _chat.db.deleteKnownDevice(device.ip);
                              _chat.clearCache(device.ip);
                              _discovery.removeDevice(device.ip);
                              setState(() {
                                _devices.removeWhere((d) => d.ip == device.ip);
                                _unread.remove(device.ip);
                                _lastMessage.remove(device.ip);
                                _lastMessageTime.remove(device.ip);
                              });
                            },
                            child: DeviceTile(
                              device: device,
                              unreadCount: _unread[device.ip] ?? 0,
                              isOnline: _onlineIps.contains(device.ip),
                              lastMessage: _lastMessage[device.ip],
                              lastMessageTime: _lastMessageTime[device.ip],
                              onTap: () => _openChat(device),
                            ),
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
                    color: _started ? const Color(0xFFB8FF57) : Colors.white24,
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
              border: Border.all(
                  color: const Color(0xFFB8FF57).withOpacity(0.3)),
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
