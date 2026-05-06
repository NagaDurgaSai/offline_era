import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/device.dart';

class DeviceTile extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onTap;
  final int unreadCount;

  const DeviceTile({
    super.key,
    required this.device,
    required this.onTap,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFB8FF57).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  device.name[0].toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB8FF57)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(device.ip,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 12, color: Colors.white38)),
                ],
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFB8FF57),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black),
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
