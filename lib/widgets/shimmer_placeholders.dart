import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer line for list tiles.
class ShimmerLine extends StatelessWidget {
  const ShimmerLine({super.key, this.width, this.height = 14});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlight = Theme.of(context).brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey[100]!;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Grid of placeholder cards while restaurants load.
class RestaurantGridShimmer extends StatelessWidget {
  const RestaurantGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 1.1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        final base = Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey[300]!;
        final highlight = Theme.of(context).brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey[100]!;
        return Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              Container(height: 12, width: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            ],
          ),
        );
      },
    );
  }
}

/// List skeleton for menu items.
class MenuListShimmer extends StatelessWidget {
  const MenuListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 8,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerLine(height: 18),
                    SizedBox(height: 10),
                    ShimmerLine(width: 64, height: 14),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(width: 72, child: ShimmerLine(height: 36)),
            ],
          ),
        );
      },
    );
  }
}
