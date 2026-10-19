import 'package:flutter/material.dart';
import 'package:mymoney/core/di/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Item navbar: tampilan & warna sama seperti NavigationBar bawaan Material 3
// ---------------------------------------------------------------------------
class DashboardNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final Color unselectedColor;
  final VoidCallback onTap;

  const DashboardNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Icon(
              selected ? activeIcon : icon,
              color: selected ? AppColors.accentBlue : unselectedColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? AppColors.accentBlue : unselectedColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Garis diagonal biru terang di kartu saldo
// ---------------------------------------------------------------------------
class CardStripePainter extends CustomPainter {

  final cardBlue = AppColors.accentBlue;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Garis lebar di tengah (lebih terang)
    final band1 = Path()
      ..moveTo(w * 0.38, 0)
      ..lineTo(w * 0.80, 0)
      ..lineTo(w * 0.40, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(band1, Paint()..color = cardBlue.withOpacity(0.28));

    // Garis kedua di kanan
    final band2 = Path()
      ..moveTo(w * 0.80, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.50)
      ..lineTo(w * 0.62, h)
      ..lineTo(w * 0.40, h)
      ..close();
    canvas.drawPath(band2, Paint()..color = cardBlue.withOpacity(0.12));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
