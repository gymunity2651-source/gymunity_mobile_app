import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/profile_avatar_provider.dart';

class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({
    super.key,
    required this.size,
    this.avatarPath,
    this.fullName,
    this.backgroundColor = AppColors.orange,
    this.foregroundColor = AppColors.white,
    this.icon = Icons.person_outline_rounded,
  });

  final double size;
  final String? avatarPath;
  final String? fullName;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trimmedPath = avatarPath?.trim();
    if (trimmedPath == null || trimmedPath.isEmpty) {
      return _fallback();
    }

    final imageUrlAsync = ref.watch(profileAvatarUrlProvider(trimmedPath));
    return imageUrlAsync.when(
      loading: _fallback,
      error: (_, _) => _fallback(),
      data: (imageUrl) {
        if (imageUrl == null || imageUrl.isEmpty) {
          return _fallback();
        }

        return ClipOval(
          child: Image.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          ),
        );
      },
    );
  }

  Widget _fallback() {
    final initial = fullName?.trim().isNotEmpty == true
        ? fullName!.trim().characters.first.toUpperCase()
        : null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: initial != null
          ? Text(
              initial,
              style: GoogleFonts.inter(
                fontSize: size * 0.34,
                fontWeight: FontWeight.w700,
                color: foregroundColor,
              ),
            )
          : Icon(icon, color: foregroundColor, size: size * 0.48),
    );
  }
}
