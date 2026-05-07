import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  final Function(String)? onNameChanged;
  const ProfileScreen({super.key, this.onNameChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _controller;
  String _storageUsed = 'calculating...';

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
    super.dispose();
  }

  Future<void> _calculateStorage() async {
    try {
      final folder = await StorageService.getAppFolder();
      int total = 0;
      await for (final entity in folder.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
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

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await context.read<UserProvider>().saveName(name);
    widget.onNameChanged?.call(name);
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

  Widget _infoTile(String label, String value, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.white38),
            const SizedBox(width: 10),
          ],
          Text(label,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, color: Colors.white38)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
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
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFB8FF57).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB8FF57)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text('display name',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: Colors.white38,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
              cursorColor: const Color(0xFFB8FF57),
              decoration: InputDecoration(
                hintText: 'your name',
                hintStyle: GoogleFonts.spaceGrotesk(color: Colors.white24),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFB8FF57), width: 2),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8FF57),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('save',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text('info',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: Colors.white38,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            _infoTile('storage used', _storageUsed,
                icon: Icons.folder_outlined),
            _infoTile('version', '1.2.0',
                icon: Icons.info_outline_rounded),
            _infoTile('platform',
                Platform.isMacOS
                    ? 'macOS'
                    : Platform.isAndroid
                        ? 'Android'
                        : Platform.isWindows
                            ? 'Windows'
                            : 'unknown',
                icon: Icons.devices_rounded),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
