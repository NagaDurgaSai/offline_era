import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late AnimationController _anim;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
    _loadDefault();
  }

  Future<void> _loadDefault() async {
    final user = context.read<UserProvider>();
    final def = await user.getDefaultName();
    if (mounted) _controller.text = def;
  }

  void _continue() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await context.read<UserProvider>().saveName(name);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: FadeTransition(
        opacity: _fadeIn,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                Text(
                  'offline\nera.',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB8FF57),
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'no cloud. no accounts. just your network.',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    color: Colors.white38,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(flex: 2),
                Text(
                  'what should we call you?',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: const Color(0xFFB8FF57),
                  decoration: InputDecoration(
                    hintText: 'your name or device name',
                    hintStyle: GoogleFonts.spaceGrotesk(
                      color: Colors.white24,
                      fontSize: 18,
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24, width: 1),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Color(0xFFB8FF57), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _continue(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _continue,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB8FF57),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          "let's go →",
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
