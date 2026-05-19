import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/storage_service.dart';

const List<String> kAvatarEmojis = [
  '👾','🔥','💀','⚡','🎯','🌊','🦊','🐉','👻','🌙',
  '🎭','🤖','💎','🦋','🌿','🎪','🦁','🐺','🦅','🌋',
  '🎸','🏴\u200d☠️','🦄','🐸','🎲','🧊','🌀','👁️','🦂','🐍',
];

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileChanged;
  const ProfileScreen({super.key, this.onProfileChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _controller;
  String _storageUsed = 'calculating...';
  bool _editingName = false;

  // IP reveal state
  bool _ipRevealed = false;
  Timer? _hideTimer;
  final _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
        text: context.read<UserProvider>().name);
    _calculateStorage();
  }

  @override
  void dispose() {
    _controller.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<void> _calculateStorage() async {
    try {
      final folder = await StorageService.getAppFolder();
      int total = 0;
      await for (final entity in folder.list(recursive: true)) {
        if (entity is File) total += await entity.length();
      }
      if (mounted) {
        setState(() {
          if (total < 1024) {
            _storageUsed = '${total}B';
          } else if (total < 1024 * 1024) {
            _storageUsed = '${(total / 1024).toStringAsFixed(1)}KB';
          } else if (total < 1024 * 1024 * 1024) {
            _storageUsed = '${(total / (1024 * 1024)).toStringAsFixed(1)}MB';
          } else {
            _storageUsed = '${(total / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _storageUsed = 'unavailable');
    }
  }

  Future<void> _saveName() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('name cannot be empty', style: GoogleFonts.spaceGrotesk()),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await context.read<UserProvider>().saveName(name);
    widget.onProfileChanged?.call();
    setState(() => _editingName = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('name updated', style: GoogleFonts.spaceGrotesk()),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Mask middle octets: 192.168.1.5 → 192.***.***. 5
  String _maskIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return ip;
    return '${parts[0]}.***.***.${parts[3]}';
  }

  Future<void> _handleIpTap(String ip) async {
    if (_ipRevealed) {
      // Already revealed — copy to clipboard
      await Clipboard.setData(ClipboardData(text: ip));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('IP copied', style: GoogleFonts.spaceGrotesk()),
            backgroundColor: const Color(0xFF1A1A1A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    bool canCheck = false;
    try {
      canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {}

    bool authenticated = false;
    if (canCheck) {
      try {
        authenticated = await _auth.authenticate(
          localizedReason: 'reveal your local IP address',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );
      } catch (e) {
        // Auth failed or not configured — reveal directly
        authenticated = true;
      }
    } else {
      authenticated = true;
    }

    if (authenticated && mounted) {
      setState(() => _ipRevealed = true);
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _ipRevealed = false);
      });
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('pick your vibe',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: kAvatarEmojis.length,
                itemBuilder: (_, i) {
                  final emoji = kAvatarEmojis[i];
                  final selected = context.read<UserProvider>().avatar == emoji;
                  return GestureDetector(
                    onTap: () async {
                      await context.read<UserProvider>().saveAvatar(emoji);
                      widget.onProfileChanged?.call();
                      if (mounted) Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFB8FF57).withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? const Color(0xFFB8FF57) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _infoTile(String label, String value, {IconData? icon, VoidCallback? onTap, bool highlight = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlight ? const Color(0xFFB8FF57).withOpacity(0.4) : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: highlight ? const Color(0xFFB8FF57) : Colors.white38),
              const SizedBox(width: 10),
            ],
            Text(label,
                style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.white38)),
            const Spacer(),
            Text(value,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: highlight ? const Color(0xFFB8FF57) : Colors.white70,
                    fontWeight: FontWeight.w600)),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                highlight ? Icons.copy_rounded : Icons.lock_outline_rounded,
                size: 13,
                color: Colors.white24,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _platformLabel(BuildContext context) {
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.android) return 'Android';
    if (platform == TargetPlatform.iOS) return 'iOS/iPadOS';
    if (platform == TargetPlatform.windows) return 'Windows';
    if (platform == TargetPlatform.macOS) return 'macOS';
    if (platform == TargetPlatform.linux) return 'Linux';
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final ip = user.localIp;
    final displayIp = _ipRevealed ? ip : _maskIp(ip);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('profile',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // avatar
            Center(
              child: GestureDetector(
                onTap: _showAvatarPicker,
                child: Stack(
                  children: [
                    Container(
                      width: 86, height: 86,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB8FF57).withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFB8FF57).withOpacity(0.3), width: 1.5),
                      ),
                      child: Center(
                        child: user.avatar.isNotEmpty
                            ? Text(user.avatar, style: const TextStyle(fontSize: 40))
                            : Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFB8FF57)),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB8FF57),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0F0F0F), width: 2),
                        ),
                        child: const Icon(Icons.edit_rounded, size: 12, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // name edit
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  const SizedBox(width: 30),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.08),
                                Colors.white.withOpacity(0.03),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: _editingName
                              ? TextField(
                                  controller: _controller,
                                  autofocus: true,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 22,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                  cursorColor: const Color(0xFFB8FF57),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintText: 'enter name',
                                    hintStyle: GoogleFonts.spaceGrotesk(
                                        color: Colors.white38, fontSize: 16),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onSubmitted: (_) => _saveName(),
                                )
                              : Text(
                                  user.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 22,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          if (_editingName) {
                            _saveName();
                          } else {
                            setState(() => _editingName = true);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _editingName ? Icons.check_rounded : Icons.edit_rounded,
                            size: 14,
                            color: _editingName ? const Color(0xFFB8FF57) : Colors.white38,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // IP tile
            if (ip.isNotEmpty)
              _infoTile(
                'local IP',
                displayIp,
                icon: _ipRevealed ? Icons.wifi_rounded : Icons.wifi_lock_rounded,
                onTap: () => _handleIpTap(ip),
                highlight: _ipRevealed,
              ),


            const Spacer(),
            _infoTile('storage used', _storageUsed, icon: Icons.folder_outlined),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'v1.5.0 • ${_platformLabel(context)}',
                style: GoogleFonts.spaceGrotesk(fontSize: 11, color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
