import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// A shimmering placeholder box for loading content.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 6});

  const Skeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = size / 2;

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final sweep = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + sweep * 3, 0),
              end: Alignment(sweep * 3, 0),
              colors: const [
                AppColors.bgAlt,
                AppColors.border,
                AppColors.bgAlt,
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

// Avatar plus two lines, list-row shaped.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Skeleton.circle(size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: MediaQuery.of(context).size.width * 0.35),
                const SizedBox(height: 8),
                Skeleton(
                  width: MediaQuery.of(context).size.width * 0.2,
                  height: 11,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// A scrollable stack of list-row skeletons.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6, this.padding});

  final int itemCount;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding ?? const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonListTile(),
    );
  }
}

// A card tile for grid-style loading.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Skeleton.circle(size: 44),
          const SizedBox(height: 14),
          const Skeleton(width: 120),
          const SizedBox(height: 8),
          const Skeleton(width: 80, height: 11),
        ],
      ),
    );
  }
}

// A responsive grid of card skeletons.
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({
    super.key,
    this.itemCount = 8,
    this.maxCrossAxisExtent = 220,
    this.padding,
  });

  final int itemCount;
  final double maxCrossAxisExtent;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding ?? const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.95,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonCard(),
    );
  }
}

// Header block plus a few loading lines.
class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({super.key, this.lineCount = 4});

  final int lineCount;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Skeleton.circle(size: 56),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: width * 0.3, height: 18),
                  const SizedBox(height: 8),
                  Skeleton(width: width * 0.18, height: 12),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < lineCount; i++) ...[
            Skeleton(width: double.infinity, height: 14),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
