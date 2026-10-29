import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

class TrendCard extends StatelessWidget {
  final int activeThisWeek;
  final int? totalActive;

  const TrendCard({
    super.key,
    required this.activeThisWeek,
    this.totalActive,
  });

  List<double> _generateWeeklyPoints() {
    // 4 points for the last 30 days ending at activeThisWeek
    final current = activeThisWeek.toDouble();
    if (totalActive != null && totalActive! > 0) {
      final base = (totalActive! * 0.7).clamp(0.0, current);
      final p1 = (base * 0.85).roundToDouble();
      final p2 = (base * 0.95).roundToDouble();
      final p3 = ((base + current) / 2).roundToDouble();
      return [p1, p2, p3, current];
    } else {
      final p1 = (current * 0.6).roundToDouble();
      final p2 = (current * 0.75).roundToDouble();
      final p3 = (current * 0.9).roundToDouble();
      return [p1, p2, p3, current];
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _generateWeeklyPoints();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly active students',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Last 30 days trend',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$activeThisWeek active this week',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 110,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineChartPainter(points: points),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAxisLabel('Week 1'),
              _buildAxisLabel('Week 2'),
              _buildAxisLabel('Week 3'),
              _buildAxisLabel('This Week', isCurrent: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAxisLabel(String text, {bool isCurrent = false}) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
        color: isCurrent ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> points;

  _LineChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double maxVal = points.reduce((a, b) => a > b ? a : b);
    final double minVal = points.reduce((a, b) => a < b ? a : b);
    final double range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);
    final double ceiling = maxVal + (range * 0.25);
    final double floor = (minVal - (range * 0.15)).clamp(0.0, double.infinity);
    final double effectiveRange = (ceiling - floor) == 0 ? 1.0 : (ceiling - floor);

    final double topPadding = 12.0;
    final double bottomPadding = 12.0;
    final double chartHeight = size.height - topPadding - bottomPadding;

    // Horizontal grid lines
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 2; i++) {
      final y = topPadding + (chartHeight / 2) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final int n = points.length;
    final double stepX = size.width / (n - 1);

    final List<Offset> offsets = [];
    for (int i = 0; i < n; i++) {
      final x = i * stepX;
      final normalizedY = (points[i] - floor) / effectiveRange;
      final y = topPadding + chartHeight - (normalizedY * chartHeight);
      offsets.add(Offset(x, y));
    }

    // Line Path & Fill Path
    final linePath = Path();
    linePath.moveTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(linePath);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    // Fill gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.20),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight + bottomPadding))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Line stroke
    final strokePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, strokePaint);

    // Point dots
    final dotOuterPaint = Paint()
      ..color = AppColors.cardBg
      ..style = PaintingStyle.fill;
    final dotStrokePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final dotInnerPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    for (int i = 0; i < offsets.length; i++) {
      final offset = offsets[i];
      // Outer ring for contrast
      canvas.drawCircle(offset, 4.5, dotOuterPaint);
      canvas.drawCircle(offset, 4.5, dotStrokePaint);
      // Inner dot
      canvas.drawCircle(offset, 2.5, dotInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

