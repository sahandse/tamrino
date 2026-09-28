import 'package:flutter/material.dart';

class TamrinoLogo extends StatelessWidget {
  const TamrinoLogo({super.key, this.size = 44, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: const _GymEmblemPainter()),
    );
  }
}

class _GymEmblemPainter extends CustomPainter {
  const _GymEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final scale = size.shortestSide;

    final background = Paint()..color = const Color(0xFF0B0D0F);
    final green = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7CFF4F), Color(0xFF00C853)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * .075
      ..strokeCap = StrokeCap.round;
    final white = Paint()..color = const Color(0xFFF8FAFC);
    final dark = Paint()..color = const Color(0xFF0B0D0F);

    canvas.drawCircle(center, scale * .48, background);

    final ringRect = Rect.fromCircle(center: center, radius: scale * .39);
    canvas.drawArc(ringRect, -2.78, 2.25, false, green);
    canvas.drawArc(ringRect, .53, 2.08, false, green);

    // Head.
    canvas.drawCircle(
      Offset(center.dx, size.height * .27),
      scale * .075,
      white,
    );

    // Athletic torso silhouette.
    final torso = Path()
      ..moveTo(size.width * .50, size.height * .34)
      ..cubicTo(size.width * .42, size.height * .33, size.width * .34, size.height * .39, size.width * .31, size.height * .49)
      ..lineTo(size.width * .37, size.height * .61)
      ..cubicTo(size.width * .41, size.height * .57, size.width * .44, size.height * .53, size.width * .46, size.height * .47)
      ..lineTo(size.width * .46, size.height * .69)
      ..lineTo(size.width * .54, size.height * .69)
      ..lineTo(size.width * .54, size.height * .47)
      ..cubicTo(size.width * .56, size.height * .53, size.width * .59, size.height * .57, size.width * .63, size.height * .61)
      ..lineTo(size.width * .69, size.height * .49)
      ..cubicTo(size.width * .66, size.height * .39, size.width * .58, size.height * .33, size.width * .50, size.height * .34)
      ..close();
    canvas.drawPath(torso, white);

    // Chest/ab negative-space lines.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, size.height * .43),
          width: scale * .035,
          height: scale * .18,
        ),
        Radius.circular(scale * .02),
      ),
      dark,
    );

    // Barbell bar.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          size.width * .17,
          size.height * .69,
          size.width * .83,
          size.height * .735,
        ),
        Radius.circular(scale * .025),
      ),
      white,
    );

    void plate(double left, double right, double top, double bottom) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            size.width * left,
            size.height * top,
            size.width * right,
            size.height * bottom,
          ),
          Radius.circular(scale * .025),
        ),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF7CFF4F), Color(0xFF00C853)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect),
      );
    }

    plate(.09, .14, .61, .82);
    plate(.145, .20, .57, .86);
    plate(.80, .855, .57, .86);
    plate(.86, .91, .61, .82);

    // Hands gripping the bar.
    canvas.drawCircle(Offset(size.width * .36, size.height * .71), scale * .04, white);
    canvas.drawCircle(Offset(size.width * .64, size.height * .71), scale * .04, white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
