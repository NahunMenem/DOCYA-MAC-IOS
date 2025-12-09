import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class DocYaBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const DocYaBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF14B8A6);
    const inactiveColor = Colors.white70;
    const bgColor = Color(0xFF0F2027);

    final items = [
      {'icon': PhosphorIconsFill.house, 'label': 'Inicio'},
      {'icon': PhosphorIconsFill.note, 'label': 'Recetas'},
      {'icon': PhosphorIconsFill.stethoscope, 'label': 'Consultas'},
      {'icon': PhosphorIconsFill.user, 'label': 'Perfil'},
    ];

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.9),
        border: const Border(
          top: BorderSide(color: Colors.white24, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final bool isActive = selectedIndex == index;

          return GestureDetector(
            onTap: () => onItemTapped(index),
            behavior: HitTestBehavior.translucent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: isActive ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          colors: isActive
                              ? [activeColor, Colors.tealAccent.shade100]
                              : [inactiveColor, inactiveColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcIn,
                      child: Icon(
                        item['icon'] as IconData,
                        size: isActive ? 30 : 25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['label'] as String,
                    style: GoogleFonts.manrope(
                      color: isActive ? activeColor : inactiveColor,
                      fontSize: 12.5,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
