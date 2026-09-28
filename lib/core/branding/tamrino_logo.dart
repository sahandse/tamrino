import 'package:flutter/material.dart';

class TamrinoLogo extends StatelessWidget {
  const TamrinoLogo({super.key, this.size = 44, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _TamrinoMarkPainter()),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        Text(
          'تمرینو',
          style: TextStyle(
            fontSize: size * .48,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
      ],
    );
  }
}

class _TamrinoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final purple = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF9A36FF), Color(0xFF6518F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    final dark = Paint()..color = const Color(0xFF171821);

    final centerY = size.height * .54;
    final plateW = size.width * .13;
    final plateH = size.height * .42;
    final smallPlateH = size.height * .30;

    RRect rr(double l, double t, double r, double b, double radius) =>
        RRect.fromRectAndRadius(Rect.fromLTRB(l, t, r, b), Radius.circular(radius));

    // Dumbbell bar.
    canvas.drawRRect(
      rr(size.width * .10, centerY - size.height * .035,
          size.width * .90, centerY + size.height * .035, size.width * .04),
      dark,
    );

    // Plates.
    canvas.drawRRect(
      rr(size.width * .08, centerY - smallPlateH / 2,
          size.width * .08 + plateW * .72, centerY + smallPlateH / 2, size.width * .05),
      purple,
    );
    canvas.drawRRect(
      rr(size.width * .14, centerY - plateH / 2,
          size.width * .14 + plateW, centerY + plateH / 2, size.width * .055),
      purple,
    );
    canvas.drawRRect(
      rr(size.width * .86 - plateW, centerY - plateH / 2,
          size.width * .86, centerY + plateH / 2, size.width * .055),
      purple,
    );
    canvas.drawRRect(
      rr(size.width * .92 - plateW * .72, centerY - smallPlateH / 2,
          size.width * .92, centerY + smallPlateH / 2, size.width * .05),
      purple,
    );

    // Stylised Persian ت body.
    final path = Path()
      ..moveTo(size.width * .33, size.height * .34)
      ..quadraticBezierTo(size.width * .41, size.height * .27, size.width * .52, size.height * .30)
      ..lineTo(size.width * .76, size.height * .30)
      ..quadraticBezierTo(size.width * .84, size.height * .30, size.width * .86, size.height * .24)
      ..lineTo(size.width * .86, size.height * .38)
      ..quadraticBezierTo(size.width * .83, size.height * .44, size.width * .74, size.height * .44)
      ..lineTo(size.width * .56, size.height * .44)
      ..quadraticBezierTo(size.width * .45, size.height * .45, size.width * .43, size.height * .57)
      ..quadraticBezierTo(size.width * .42, size.height * .68, size.width * .53, size.height * .70)
      ..quadraticBezierTo(size.width * .63, size.height * .71, size.width * .68, size.height * .61)
      ..lineTo(size.width * .76, size.height * .61)
      ..quadraticBezierTo(size.width * .68, size.height * .82, size.width * .49, size.height * .82)
      ..quadraticBezierTo(size.width * .28, size.height * .82, size.width * .28, size.height * .59)
      ..quadraticBezierTo(size.width * .28, size.height * .43, size.width * .33, size.height * .34)
      ..close();
    canvas.drawPath(path, dark);

    // Two dots of ت.
    final d = size.width * .11;
    final dot1 = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width * .48, size.height * .17), width: d, height: d),
        Radius.circular(d * .22),
      ));
    final dot2 = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width * .63, size.height * .17), width: d, height: d),
        Radius.circular(d * .22),
      ));
    canvas.save();
    canvas.translate(size.width * .48, size.height * .17);
    canvas.rotate(.78);
    canvas.translate(-size.width * .48, -size.height * .17);
    canvas.drawPath(dot1, purple);
    canvas.restore();
    canvas.save();
    canvas.translate(size.width * .63, size.height * .17);
    canvas.rotate(.78);
    canvas.translate(-size.width * .63, -size.height * .17);
    canvas.drawPath(dot2, purple);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
