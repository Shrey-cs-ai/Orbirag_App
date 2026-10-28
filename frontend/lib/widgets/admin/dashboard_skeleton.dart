import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class DashboardSkeleton extends StatefulWidget {
  const DashboardSkeleton({super.key});

  @override
  State<DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.35, end: 0.8).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _buildPlaceholder({
    required double height,
    double? width,
    double borderRadius = 8,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Opacity(
          opacity: _pulseAnim.value,
          child: Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardSkeleton({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Header Skeleton
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPlaceholder(height: 24, width: 200, borderRadius: 6),
                _buildPlaceholder(height: 24, width: 90, borderRadius: 12),
              ],
            ),
            const SizedBox(height: 8),
            _buildPlaceholder(height: 14, width: 240, borderRadius: 4),
          ],
        ),
        const SizedBox(height: 16),

        // License Usage Card Skeleton
        _buildCardSkeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPlaceholder(height: 16, width: 100),
                  _buildPlaceholder(height: 20, width: 70, borderRadius: 6),
                ],
              ),
              const SizedBox(height: 16),
              _buildPlaceholder(height: 36, width: 140),
              const SizedBox(height: 16),
              _buildPlaceholder(height: 10, width: double.infinity, borderRadius: 5),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stat Cards Skeleton Row
        Row(
          children: [
            Expanded(
              child: _buildCardSkeleton(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlaceholder(height: 28, width: 28, borderRadius: 8),
                    const SizedBox(height: 12),
                    _buildPlaceholder(height: 14, width: 80),
                    const SizedBox(height: 6),
                    _buildPlaceholder(height: 22, width: 50),
                    const SizedBox(height: 6),
                    _buildPlaceholder(height: 10, width: double.infinity),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCardSkeleton(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlaceholder(height: 28, width: 28, borderRadius: 8),
                    const SizedBox(height: 12),
                    _buildPlaceholder(height: 14, width: 70),
                    const SizedBox(height: 6),
                    _buildPlaceholder(height: 22, width: 80),
                    const SizedBox(height: 6),
                    _buildPlaceholder(height: 10, width: double.infinity),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Research Activity Card Skeleton
        _buildCardSkeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPlaceholder(height: 18, width: 130),
                  _buildPlaceholder(height: 20, width: 90, borderRadius: 6),
                ],
              ),
              const SizedBox(height: 16),
              _buildPlaceholder(height: 16, width: double.infinity),
              const SizedBox(height: 12),
              _buildPlaceholder(height: 16, width: double.infinity),
              const SizedBox(height: 12),
              _buildPlaceholder(height: 16, width: double.infinity),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Trend Card Skeleton
        _buildCardSkeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPlaceholder(height: 18, width: 160),
              const SizedBox(height: 16),
              _buildPlaceholder(height: 90, width: double.infinity, borderRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}

