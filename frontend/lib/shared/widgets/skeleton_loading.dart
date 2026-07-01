import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// A premium, custom pulsing skeleton animation widget (pure vanilla Flutter)
class SkeletonPulse extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonPulse({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkBorder : AppColors.borderLight;
    final highlightColor = isDark ? AppColors.darkSurface : Colors.white;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                baseColor.withOpacity(0.5),
                highlightColor,
              ),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

/// A pre-made list skeleton loading loader
class SkeletonListLoader extends StatelessWidget {
  final int itemCount;

  const SkeletonListLoader({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const SkeletonPulse(width: 48, height: 48, borderRadius: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonPulse(width: 150, height: 16),
                    const SizedBox(height: 8),
                    SkeletonPulse(
                      width: MediaQuery.of(context).size.width * 0.4,
                      height: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A pre-made table/grid loading skeleton loader
class SkeletonTableLoader extends StatelessWidget {
  final int rows;

  const SkeletonTableLoader({super.key, this.rows = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(rows, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SkeletonPulse(width: 100, height: 16),
              const SkeletonPulse(width: 80, height: 16),
              const SkeletonPulse(width: 120, height: 16),
              const SkeletonPulse(width: 60, height: 16),
            ],
          ),
        );
      }),
    );
  }
}
