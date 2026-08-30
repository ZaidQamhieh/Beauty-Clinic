import 'package:flutter/material.dart';

import '../../auth/role.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.color,
    this.role,
    this.gender,
    this.imageUrl,
    this.radius = 38,
  });

  final Color color;
  final Role? role;
  final String? gender;
  final String? imageUrl;
  final double radius;

  static IconData fallbackIconFor(Role? role, String? gender) {
    final normalizedGender = (gender ?? '').trim().toUpperCase();
    final baseIcon = switch (normalizedGender) {
      'MALE' => Icons.face_6_rounded,
      'FEMALE' => Icons.face_3_rounded,
      _ => Icons.person_rounded,
    };

    switch (role) {
      case Role.doctor:
        return baseIcon;
      case Role.receptionist:
        return Icons.person_rounded;
      case Role.admin:
        return Icons.person_rounded;
      case Role.patient:
      default:
        return baseIcon;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedGender = gender?.trim().toUpperCase();
    final url = imageUrl?.trim();
    final hasValidUrl = url != null && url.isNotEmpty;
    final genderIcon = switch (normalizedGender) {
      'MALE' => Icons.face_6_rounded,
      'FEMALE' => Icons.face_3_rounded,
      _ => Icons.person_rounded,
    };

    final avatarContent = hasValidUrl
        ? Image.network(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            errorBuilder: (_, _, _) =>
                Icon(genderIcon, size: radius * 1.2, color: color),
          )
        : Icon(genderIcon, size: radius * 1.2, color: color);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: ClipOval(child: Center(child: avatarContent)),
        ),
        if (role == Role.doctor)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(radius * 0.12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.medical_services_rounded,
                size: radius * 0.35,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}
