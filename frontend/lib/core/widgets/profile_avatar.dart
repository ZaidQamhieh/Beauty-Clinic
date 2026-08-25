import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.color,
    this.imageUrl,
    this.radius = 38,
  });

  final Color color;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final fallback = Icon(Icons.person, size: radius * 1.1, color: color);

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: .18),
      child: url == null || url.isEmpty
          ? fallback
          : ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => SizedBox(
                  width: radius * 2,
                  height: radius * 2,
                  child: Center(child: fallback),
                ),
              ),
            ),
    );
  }
}
