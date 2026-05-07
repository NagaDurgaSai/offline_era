import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/device.dart';

class DeviceTile extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onTap;
  final int unreadCount;
  final bool isOnline;
  final String? lastMessage;
  final String? lastMessageTime;

  const DeviceTile({
    super.key,
    required this.device,
    required this.onTap,
    this.unreadCount = 0,
    this.isOnline = false,
    this.lastMessage,
    this.lastMessageTime,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unreadCount > 0
                ? const Color(0xFFB8FF57).withOpacity(0.4)
                : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8FF57).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: device.avatar.isNotEmpty
                        ? Text(device.avatar, style: const TextStyle(fontSize: 20))
                        : Text(
                            device.name[0].toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB8FF57)),
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? const Color(0xFF4ADE80)
                          : Colors.white24,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF1A1A1A), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    lastMessage ?? device.ip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: unreadCount > 0
                            ? Colors.white54
                            : Colors.white24),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (lastMessageTime != null)
                  Text(lastMessageTime!,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, color: Colors.white24)),
                const SizedBox(height: 4),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8FF57),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white24, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
